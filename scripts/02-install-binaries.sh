#!/usr/bin/env bash
# Task 2.3 + 2.4 — install + version-pin cloudflared and caddy (arm64). Idempotent.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

echo "==> cloudflared"
if ! command -v cloudflared >/dev/null 2>&1; then
	tmp="$(mktemp --suffix=.deb)"
	curl -fL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb -o "$tmp"
	sudo dpkg -i "$tmp"
	rm -f "$tmp"
fi

echo "==> caddy"
if ! command -v caddy >/dev/null 2>&1; then
	sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
		| sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
		| sudo tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
	sudo apt-get update && sudo apt-get install -y caddy
fi

# Ensure caddy lives where the systemd unit's ExecStart expects it.
if [ ! -x "$CADDY_BIN" ] && command -v caddy >/dev/null 2>&1; then
	sudo ln -sf "$(command -v caddy)" "$CADDY_BIN"
fi

echo "==> Record versions"
mkdir -p "$REPO_DIR/docs"
{ cloudflared --version; caddy version; } | tee "$REPO_DIR/docs/versions.txt"

echo "Binaries installed."
