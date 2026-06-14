#!/usr/bin/env bash
# Task 5.1 + 5.2 + 5.4 — install + enable cloudflared and caddy systemd services.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

echo "==> cloudflared managed service"
sudo cloudflared service install || true   # picks up /etc/cloudflared/config.yml
sudo systemctl enable --now cloudflared

echo "==> caddy service (replace any distro-packaged unit with ours)"
sudo systemctl disable --now caddy 2>/dev/null || true
sudo cp "$REPO_DIR/systemd/caddy.service" /etc/systemd/system/caddy.service
sudo cp "$REPO_DIR/systemd/app@.service" /etc/systemd/system/app@.service
sudo systemctl daemon-reload
sudo systemctl enable --now caddy

echo "==> Enabled at boot:"
systemctl is-enabled cloudflared caddy

echo "Services installed + enabled."
