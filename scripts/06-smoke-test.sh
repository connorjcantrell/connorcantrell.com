#!/usr/bin/env bash
# Task 4.4 + 6.1 (local portion) — verify the origin before the external check.
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

echo "==> Services active?"
systemctl is-active cloudflared caddy

echo "==> Apex (local origin) — expect HTML:"
# Retry on connection-refused: install-services restarts Caddy just before this
# runs, so the first request can land in the sub-second window before it rebinds.
curl -fsS --retry 10 --retry-connrefused --retry-delay 1 -H "Host: $DOMAIN" http://localhost/ | head -n 5

echo "==> Unknown host — expect 404:"
curl -s -o /dev/null -w '   HTTP %{http_code}\n' -H "Host: nope.$DOMAIN" http://localhost/

echo
echo "Local checks done. Now verify the FULL path from an external network"
echo "(e.g. phone on cellular):  https://$DOMAIN  -> valid TLS + the apex page."
