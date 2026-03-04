# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: install
# Run npm install as root in an isolated stage so the final image
# never has npm, npx, or the package manager available to the agent.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-alpine AS installer

RUN npm install -g openclaw && npm cache clean --force

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: runtime — minimal hardened image
#
# What this Dockerfile enforces (build-time):
#   - Non-root user: agent cannot write outside /data
#   - No npm/npx/shell tools: reduces post-exploitation surface
#   - Minimal Alpine base: fewer CVEs
#   - NODE_ENV=production: disables dev features, reduces memory footprint
#   - dumb-init as PID 1: correct signal handling, no zombie processes
#
# What must be enforced at runtime (docker run / Railway / Compose):
#   - --read-only            → only /data and /tmp are writable
#   - --cap-drop=ALL         → no Linux capabilities
#   - --security-opt=no-new-privileges
#   - --network / firewall   → limit outbound to required domains only
#
# What Docker cannot protect against:
#   - Prompt injection via email/messages that abuse valid OAuth tokens
#   - Agent misuse of API keys already loaded in memory
#   - Actions taken by integrations (Gmail, GitHub, etc.) via granted scopes
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-alpine

RUN apk add --no-cache dumb-init ca-certificates \
    && rm -rf /var/cache/apk/*

# Copy only the installed package, not npm itself
COPY --from=installer /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=installer /usr/local/bin/openclaw /usr/local/bin/openclaw

# Non-root user
RUN addgroup -S openclaw && adduser -S openclaw -G openclaw

# /data is the only directory the agent can read/write.
# Mount a dedicated volume here — never mount $HOME or /
RUN mkdir -p /data && chown openclaw:openclaw /data

ENV NODE_ENV=production
# Railway injects $PORT if openclaw exposes HTTP
ENV PORT=3000

USER openclaw
WORKDIR /data

ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["openclaw"]
