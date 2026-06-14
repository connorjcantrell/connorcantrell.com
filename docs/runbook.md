# Runbook — connorcantrell.com hosting foundation

Operator guide for the Orange Pi 5. Assumes the `connorcantrell.com` zone is on
Cloudflare. Commands prefixed `sudo` mutate the host; the `cloudflared` login is
interactive (opens a browser). Run them on the Pi.

Conventions used below:
- Service user/group: **`foundation`**
- Caddy config: `/etc/caddy/Caddyfile` · apex root: `/var/www/apex`
- Tunnel config: `/etc/cloudflared/config.yml`

---

## 0. Prerequisite — put the zone on Cloudflare (one-time)

The tunnel and DNS steps need `connorcantrell.com` managed by Cloudflare. This is
a **nameserver delegation, not a registrar transfer** — the domain stays
registered (and paid) at Namecheap.

1. Cloudflare dashboard → **Add a site** → `connorcantrell.com` → **Free** plan.
2. Review the DNS records Cloudflare imported (especially **MX/email** — a
   missing MX after delegation breaks email).
3. Cloudflare shows two nameservers. At **Namecheap → Domain List → Manage →
   Nameservers → Custom DNS**, set those two and save.
4. Wait until Cloudflare shows the zone **Active** (minutes to a few hours).

Do **not** start §1 until the zone is Active — step 1.4 (`cloudflared tunnel
login`) needs the zone present in your Cloudflare account.

## 1. Deploy from scratch

> **Prefer to script it?** The steps below are also packaged as idempotent
> scripts in [`scripts/`](../scripts/). Run `./scripts/bringup.sh` for the whole
> sequence, or the numbered scripts individually. The manual commands here are
> the reference of record.

### 1.1 Host prep

```bash
# Dedicated non-root service user (no login shell, no home login)
sudo useradd --system --user-group --shell /usr/sbin/nologin foundation

# Caddy state dir
sudo mkdir -p /var/lib/caddy && sudo chown foundation:foundation /var/lib/caddy

# Apex web root
sudo mkdir -p /var/www/apex
```

### 1.2 microSD hardening (staying on SD for now)

```bash
# Journal in RAM
sudo mkdir -p /etc/systemd/journald.conf.d
sudo cp systemd/journald-volatile.conf /etc/systemd/journald.conf.d/volatile.conf
sudo systemctl restart systemd-journald

# Optional but recommended: keep /var/log off the card too
sudo apt-get update && sudo apt-get install -y log2ram   # or build from source on OPi
sudo systemctl enable --now log2ram
```

> If/when reliability bites, migrate to NVMe — see **§4 Escape hatch**.

### 1.3 Install binaries (ARM64)

```bash
# cloudflared (Cloudflare apt repo or direct .deb for arm64)
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb -o /tmp/cloudflared.deb
sudo dpkg -i /tmp/cloudflared.deb

# Caddy (official apt repo)
sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update && sudo apt-get install -y caddy
# Ensure the binary path matches the unit (ExecStart=/usr/local/bin/caddy):
which caddy   # if /usr/bin/caddy, either symlink to /usr/local/bin or edit the unit

# Pin/record versions for reproducibility
cloudflared --version | tee -a docs/versions.txt
caddy version       | tee -a docs/versions.txt
```

### 1.4 Create the tunnel (interactive)

```bash
cloudflared tunnel login                     # opens browser; pick the connorcantrell.com zone
cloudflared tunnel create connorcantrell     # prints the TUNNEL_UUID and writes <UUID>.json

# Move config + credentials into place for the system service
sudo mkdir -p /etc/cloudflared
sudo cp cloudflared/config.yml /etc/cloudflared/config.yml
sudo cp ~/.cloudflared/<UUID>.json /etc/cloudflared/<UUID>.json
sudo sed -i 's/<TUNNEL_UUID>/<UUID>/g' /etc/cloudflared/config.yml   # fill both placeholders
```

### 1.5 DNS — wildcard + apex (dashboard)

The CLI and dashboard "Add application" form **reject `*`**, so add these by hand
in **Cloudflare → DNS**, both **Proxied (orange cloud)**:

| Type  | Name | Target |
|-------|------|--------|
| CNAME | `*`  | `<UUID>.cfargotunnel.com` |
| CNAME | `@`  | `<UUID>.cfargotunnel.com` |

### 1.6 Caddy config + apex page

```bash
sudo cp caddy/Caddyfile /etc/caddy/Caddyfile
sudo cp -r www/apex/* /var/www/apex/
sudo chown -R foundation:foundation /var/www/apex
sudo caddy validate --config /etc/caddy/Caddyfile
```

### 1.7 Install + enable services

```bash
# cloudflared as a managed service (generates its own systemd unit)
sudo cloudflared service install
sudo systemctl enable --now cloudflared

# Caddy
sudo cp systemd/caddy.service /etc/systemd/system/caddy.service
sudo systemctl daemon-reload
sudo systemctl enable --now caddy

# Verify both are enabled at boot
systemctl is-enabled cloudflared caddy
```

### 1.8 Smoke test

```bash
# Local origin
curl -H 'Host: connorcantrell.com' http://localhost/        # apex HTML
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: nope.connorcantrell.com' http://localhost/   # -> 404

# Full path (from any external network / phone on cell data)
#   https://connorcantrell.com  -> valid TLS + apex page
```

---

## 2. Add a new project subdomain

No DNS or tunnel change — the wildcard already covers it.

```bash
# 1. Run the app on a free local port (manually, or as a managed service):
sudo mkdir -p /srv/apps/iracing && sudo chown foundation:foundation /srv/apps/iracing
# deploy app code into /srv/apps/iracing
sudo mkdir -p /etc/connorcantrell
printf 'START_CMD=node server.js\nPORT=8001\n' | sudo tee /etc/connorcantrell/iracing.env
sudo cp systemd/app@.service /etc/systemd/system/app@.service
sudo systemctl daemon-reload
sudo systemctl enable --now app@iracing

# 2. Add a route in /etc/caddy/Caddyfile:
#      http://iracing.connorcantrell.com {
#          reverse_proxy localhost:8001
#      }
#    (for streaming/SSE apps add `flush_interval -1` inside reverse_proxy)

# 3. Apply with zero downtime:
sudo systemctl reload caddy
```

Verify: `https://iracing.connorcantrell.com` serves the app; the apex and other
subdomains keep responding throughout the reload.

---

## 3. Roll back

```bash
# Stop serving (no inbound ports remain open — nothing is left exposed)
sudo systemctl stop caddy cloudflared

# Remove a single project: delete its Caddyfile block, then
sudo systemctl reload caddy
sudo systemctl disable --now app@iracing

# Fully tear down the tunnel
sudo systemctl disable --now cloudflared
cloudflared tunnel delete connorcantrell
# then delete the `*` and `@` CNAMEs in the Cloudflare dashboard
```

All config is text in this repo, so any step is re-runnable from §1.

---

## 4. Trade-offs & escape hatches

### Accepted trade-offs (inherent to the tunnel, not the proxy choice)
- **Single point of failure:** when Cloudflare's edge has an outage, *all*
  subdomains go down together. Caddy holds the real routing config locally, so
  leaving Cloudflare is a DNS change, not a rebuild (see escape hatch below).
- **TLS terminates at Cloudflare:** the edge sees decrypted traffic. Note this
  for the future LLM chat app (prompts pass through Cloudflare in cleartext to
  the origin hop). Acceptable for a hobby app; document it for users.
- **Free-tier media cap (~100 MB request body); no large-media/video serving.**
  HTML/JSON/SSE projects are fine. A future media project must use object
  storage (e.g. Cloudflare R2 / direct-to-storage uploads), not the tunnel.
- **Edge latency** (~10–200 ms via the nearest PoP) on interactive apps.

### Storage escape hatch — migrate to NVMe (Orange Pi 5 M.2 slot)
Trigger this if SD corruption or instability appears (or proactively before the
graph app goes live):
1. Fit an M.2 2280 NVMe SSD in the Orange Pi 5's slot.
2. Flash/clone the rootfs to NVMe (e.g. `orangepi-config` → install to NVMe, or
   `dd`/`rsync` the rootfs and update the bootloader/`extlinux`/`fstab`).
3. Boot from NVMe; revert the `journald` volatile drop-in if you no longer need
   it. Routing, tunnel, and Caddy config are unchanged — this is orthogonal.

### Leaving the tunnel (deep-lock-in escape)
If you ever drop Cloudflare Tunnel: point DNS straight at an origin (or a small
VPS/WireGuard relay) and let Caddy take over public TLS — flip the site
addresses in the Caddyfile from `http://` to `https://` and its (currently
dormant) automatic HTTPS activates. Routing config stays the same.

### Wildcard fallback — enumerated subdomains
If the proxied wildcard CNAME ever triggers Chrome's
`ERR_ECH_FALLBACK_CERTIFICATE_INVALID` (ECH on the wildcard), switch to
per-subdomain records:
1. In `/etc/cloudflared/config.yml`, replace the `*.connorcantrell.com` rule
   with one explicit `hostname:` rule per subdomain (each → `http://localhost:80`).
2. Create a per-name CNAME for each (the CLI can do these:
   `cloudflared tunnel route dns connorcantrell iracing.connorcantrell.com`).
3. `sudo systemctl restart cloudflared`.
This costs a two-system edit (tunnel + DNS) per new project instead of one.
