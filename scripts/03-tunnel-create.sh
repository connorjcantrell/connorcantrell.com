#!/usr/bin/env bash
# Task 3.1 + 3.2 (+ 3.3) — login, create tunnel, place config/creds, set DNS.
# INTERACTIVE: the first login opens a browser. Idempotent thereafter.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/env.sh"

echo "==> Cloudflare login (browser) if needed"
if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
	cloudflared tunnel login
fi

echo "==> Create tunnel '$TUNNEL_NAME' if it does not exist"
if ! cloudflared tunnel list --output json \
	| python3 -c "import sys,json;n='$TUNNEL_NAME';sys.exit(0 if any(t['name']==n for t in (json.load(sys.stdin) or [])) else 1)"; then
	cloudflared tunnel create "$TUNNEL_NAME"
fi

UUID="$(cloudflared tunnel list --output json \
	| python3 -c "import sys,json;n='$TUNNEL_NAME';print(next(t['id'] for t in (json.load(sys.stdin) or []) if t['name']==n))")"
echo "    Tunnel UUID: $UUID"

echo "==> Place config + credentials under /etc/cloudflared"
sudo mkdir -p /etc/cloudflared
sudo cp "$REPO_DIR/cloudflared/config.yml" /etc/cloudflared/config.yml
sudo cp "$HOME/.cloudflared/$UUID.json" "/etc/cloudflared/$UUID.json"
sudo sed -i "s/<TUNNEL_UUID>/$UUID/g" /etc/cloudflared/config.yml

echo "==> DNS (proxied wildcard + apex CNAMEs)"
if [ -n "${CLOUDFLARE_API_TOKEN:-}" ]; then
	"$SCRIPT_DIR/03b-dns-api.sh" "$UUID"
else
	cat <<EOF

   No CLOUDFLARE_API_TOKEN set — add these by hand in Cloudflare -> DNS
   (both **Proxied** / orange cloud), then press Enter:

     CNAME   *   $UUID.cfargotunnel.com
     CNAME   @   $UUID.cfargotunnel.com

EOF
	read -r -p "   Press Enter once the * and @ CNAMEs exist... " _
fi

echo "Tunnel ready (UUID $UUID)."
