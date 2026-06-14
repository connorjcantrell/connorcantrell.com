#!/usr/bin/env bash
# Task 4.1–4.3 deploy — Caddyfile + apex page into place, then validate. Idempotent.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

echo "==> Caddyfile -> /etc/caddy/Caddyfile"
sudo mkdir -p /etc/caddy "$APEX_ROOT"
sudo cp "$REPO_DIR/caddy/Caddyfile" /etc/caddy/Caddyfile

echo "==> Apex page -> $APEX_ROOT"
sudo cp -r "$REPO_DIR"/www/apex/. "$APEX_ROOT"/
sudo chown -R "$SERVICE_USER:$SERVICE_USER" "$APEX_ROOT"

echo "==> Validate"
sudo "$CADDY_BIN" validate --config /etc/caddy/Caddyfile

echo "Config deployed + validated."
