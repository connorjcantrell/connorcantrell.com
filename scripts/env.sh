#!/usr/bin/env bash
# Shared config for the bring-up scripts. Sourced by the others — edit here.

DOMAIN="connorcantrell.com"
TUNNEL_NAME="connorcantrell"
SERVICE_USER="foundation"
APEX_ROOT="/var/www/apex"
CADDY_BIN="/usr/local/bin/caddy"

# Resolve the repo root from this file's location (robust to caller's CWD).
_ENV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$_ENV_DIR/.." && pwd)"
