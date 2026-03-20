#!/bin/bash
set -euo pipefail

COMPOSE_DIR="/home/tim/caddy"
LOG_FILE="$COMPOSE_DIR/update.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

cd "$COMPOSE_DIR"

# ── current running version ───────────────────────────────────────────────────
CURRENT=$(docker compose exec -T caddy caddy version 2>/dev/null \
  | awk '{print $1}' | sed 's/^v//')

# ── latest release from GitHub ────────────────────────────────────────────────
LATEST=$(curl -sf "https://api.github.com/repos/caddyserver/caddy/releases/latest" \
  | grep '"tag_name"' | head -1 | sed 's/.*"v\([^"]*\)".*/\1/')

if [ -z "$LATEST" ]; then
  log "ERROR: could not fetch latest version from GitHub"
  exit 1
fi

log "Current: v${CURRENT:-unknown}  Latest: v${LATEST}"

if [ "${CURRENT:-}" = "$LATEST" ]; then
  log "Already up to date."
  exit 0
fi

log "New version available — rebuilding image..."

# ── save current image ID for rollback ───────────────────────────────────────
OLD_IMAGE=$(docker compose images -q caddy 2>/dev/null | head -1 || true)

# ── rebuild (--pull updates base images, --no-cache re-clones CF plugin) ─────
if ! docker compose build --pull --no-cache >> "$LOG_FILE" 2>&1; then
  log "ERROR: build failed — keeping current container running"
  exit 1
fi

log "Build complete. Restarting..."

# ── restart ───────────────────────────────────────────────────────────────────
if ! docker compose up -d >> "$LOG_FILE" 2>&1; then
  log "ERROR: restart failed — attempting rollback..."
  if [ -n "$OLD_IMAGE" ]; then
    docker tag "$OLD_IMAGE" caddy-caddy:latest 2>/dev/null || true
    docker compose up -d >> "$LOG_FILE" 2>&1 || true
  fi
  exit 1
fi

sleep 5
NEW=$(docker compose exec -T caddy caddy version 2>/dev/null \
  | awk '{print $1}' | sed 's/^v//')
log "Update complete: v${CURRENT:-unknown} → v${NEW}"
