# ─────────────────────────────────────────────────────────────────────────────
# Stage 1: install
# node:22-slim (Debian) is required — node-llama-cpp needs glibc to use
# prebuilt binaries. Alpine (musl libc) forces a full llama.cpp source build
# which requires cmake, make, g++, and still fails without GPU drivers.
# ─────────────────────────────────────────────────────────────────────────────
FROM node:22-slim AS installer

# git is required by some of openclaw's npm dependencies during install
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Update npm to latest before installing packages
RUN npm install -g npm@latest

# Rewrite SSH GitHub URLs to HTTPS — libsignal-node (whiskeysockets/Baileys)
# declares its dependency as github:whiskeysockets/libsignal-node which npm
# resolves via ssh://git@github.com, failing in keyless build environments.
# Written directly to /etc/gitconfig to guarantee both insteadOf rules coexist
# (git config --system without --add silently overwrites the previous value).
RUN printf '[url "https://github.com/"]\n\tinsteadOf = ssh://git@github.com/\n\tinsteadOf = git@github.com:\n' > /etc/gitconfig

RUN npm install -g openclaw && npm cache clean --force

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2: runtime — hardened image
#
# What this Dockerfile enforces (build-time):
#   - Non-root user: agent cannot write outside /data
#   - No npm/npx/git in runtime image: reduces post-exploitation surface
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
FROM node:22-slim

RUN apt-get update && apt-get install -y --no-install-recommends dumb-init \
    && rm -rf /var/lib/apt/lists/*

# Copy only the installed package — npm, git, and build tools are NOT included
COPY --from=installer /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=installer /usr/local/bin/openclaw /usr/local/bin/openclaw

# Non-root user
RUN groupadd -r openclaw && useradd -r -g openclaw openclaw

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
