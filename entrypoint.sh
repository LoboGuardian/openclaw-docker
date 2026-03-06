#!/bin/sh
# entrypoint.sh — Configure openclaw from environment variables, then start the gateway.
#
# Set these in Railway Variables (or .env locally):
#
#   Required to start without prompts:
#     OPENCLAW_GATEWAY_MODE=local        (or "remote" if connecting to another gateway)
#
#   AI provider (at least one):
#     ANTHROPIC_API_KEY=sk-ant-...
#     OPENAI_API_KEY=sk-...
#
#   Gateway auth (recommended for production):
#     OPENCLAW_GATEWAY_AUTH_PASSWORD=yourpassword
#
#   Channels (add only what you use):
#     OPENCLAW_TELEGRAM_TOKEN=...
#     OPENCLAW_DISCORD_TOKEN=...
#     OPENCLAW_WHATSAPP=true              (requires QR scan on first run)

set -e

cfg() {
  openclaw config set "$1" "$2" --non-interactive 2>/dev/null || true
}

echo "[entrypoint] Configuring openclaw from environment variables..."

# ── Gateway mode ──────────────────────────────────────────────────────────────
if [ -n "$OPENCLAW_GATEWAY_MODE" ]; then
  cfg gateway.mode "$OPENCLAW_GATEWAY_MODE"
else
  # Default to local so the gateway starts without interactive setup
  cfg gateway.mode local
fi

# ── Gateway auth ──────────────────────────────────────────────────────────────
if [ -n "$OPENCLAW_GATEWAY_AUTH_PASSWORD" ]; then
  cfg gateway.auth.password "$OPENCLAW_GATEWAY_AUTH_PASSWORD"
fi

# ── AI providers ──────────────────────────────────────────────────────────────
# openclaw reads ANTHROPIC_API_KEY and OPENAI_API_KEY directly from the
# environment — no config set needed for those.

# ── Channels ──────────────────────────────────────────────────────────────────
if [ -n "$OPENCLAW_TELEGRAM_TOKEN" ]; then
  cfg channels.telegram.token "$OPENCLAW_TELEGRAM_TOKEN"
fi

if [ -n "$OPENCLAW_DISCORD_TOKEN" ]; then
  cfg channels.discord.token "$OPENCLAW_DISCORD_TOKEN"
fi

echo "[entrypoint] Starting openclaw gateway..."
exec openclaw gateway "$@"
