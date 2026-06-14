#!/usr/bin/env bash
# Task 3.3 (optional) — create the proxied wildcard + apex CNAMEs via the
# Cloudflare API instead of the dashboard. The dashboard/CLI reject '*', but the
# API accepts it. Idempotent (updates existing records).
#
# Requires a token with Zone.DNS:Edit on the zone:
#   export CLOUDFLARE_API_TOKEN=...
#   ./03b-dns-api.sh <TUNNEL_UUID>
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

UUID="${1:?usage: 03b-dns-api.sh <TUNNEL_UUID>}"
: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN (Zone.DNS:Edit)}"

api="https://api.cloudflare.com/client/v4"
target="$UUID.cfargotunnel.com"
auth=(-H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json")

zone_id="$(curl -fsS "$api/zones?name=$DOMAIN" "${auth[@]}" \
	| python3 -c "import sys,json;print(json.load(sys.stdin)['result'][0]['id'])")"

upsert() {
	local name="$1"
	local rid body
	rid="$(curl -fsS "$api/zones/$zone_id/dns_records?type=CNAME&name=$name" "${auth[@]}" \
		| python3 -c "import sys,json;r=json.load(sys.stdin)['result'];print(r[0]['id'] if r else '')")"
	body="$(python3 -c "import json;print(json.dumps({'type':'CNAME','name':'$name','content':'$target','proxied':True,'ttl':1}))")"
	if [ -n "$rid" ]; then
		curl -fsS -X PUT "$api/zones/$zone_id/dns_records/$rid" "${auth[@]}" -d "$body" >/dev/null
		echo "   updated $name -> $target (proxied)"
	else
		curl -fsS -X POST "$api/zones/$zone_id/dns_records" "${auth[@]}" -d "$body" >/dev/null
		echo "   created $name -> $target (proxied)"
	fi
}

upsert "*.$DOMAIN"
upsert "$DOMAIN"
echo "DNS records set."
