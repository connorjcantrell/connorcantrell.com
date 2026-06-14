#!/usr/bin/env bash
# Task 2.1 + 2.2 — service user, dirs, microSD hardening. Uses sudo. Idempotent.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

echo "==> Service user: $SERVICE_USER"
if ! id -u "$SERVICE_USER" >/dev/null 2>&1; then
	sudo useradd --system --user-group --shell /usr/sbin/nologin "$SERVICE_USER"
fi

echo "==> Directories"
sudo mkdir -p /var/lib/caddy "$APEX_ROOT"
sudo chown "$SERVICE_USER:$SERVICE_USER" /var/lib/caddy

echo "==> journald -> volatile (logs in RAM)"
sudo mkdir -p /etc/systemd/journald.conf.d
sudo cp "$REPO_DIR/systemd/journald-volatile.conf" /etc/systemd/journald.conf.d/volatile.conf
sudo systemctl restart systemd-journald

echo "==> log2ram (optional; keeps /var/log off the SD card)"
if ! command -v log2ram >/dev/null 2>&1; then
	sudo apt-get update && sudo apt-get install -y log2ram \
		|| echo "   log2ram not available via apt — install manually if you want it (skipping)"
fi
sudo systemctl enable --now log2ram 2>/dev/null || true

echo "Host prep done."
