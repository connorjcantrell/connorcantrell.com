#!/usr/bin/env bash
# One-shot bring-up: runs the steps in order. Step 03 is interactive (browser
# login) and will pause for DNS unless CLOUDFLARE_API_TOKEN is set. Every step
# is idempotent, so this is safe to re-run after a failure.
set -euo pipefail
d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$d/01-host-prep.sh"
"$d/02-install-binaries.sh"
"$d/03-tunnel-create.sh"
"$d/04-deploy-config.sh"
"$d/05-install-services.sh"
"$d/06-smoke-test.sh"

echo
echo "Bring-up complete. Reboot once to confirm everything returns unattended:"
echo "   sudo reboot   # then re-check https://connorcantrell.com"
