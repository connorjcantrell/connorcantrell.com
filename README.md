# connorcantrell.com

A self-hosting **foundation** that runs many independent projects, each on its own
subdomain, from an **Orange Pi 5** at home — with **zero inbound ports** and TLS
handled at the edge.

```
                 Cloudflare edge  (TLS · DNS · WAF · DDoS)
                          │
            outbound-only │  one tunnel, wildcard ingress
                          │  *.connorcantrell.com → localhost:80
                   ┌──────┴───────┐
                   │  cloudflared  │   (systemd, auto-restart)
                   └──────┬───────┘
                          │  plain HTTP
                   ┌──────┴───────┐
                   │     Caddy     │   :80  routes by Host header
                   └──┬────────┬──┘
        file_server   │        │   reverse_proxy
        ┌─────────────┘        └──────────────┐
  connorcantrell.com                 *.connorcantrell.com
  (static apex page)             iracing → :8001 (Node)
                                 graph   → :8002 (Python)   …any language
```

## Why this shape

Routing N subdomains to N ports is possible with `cloudflared` alone, so the
choice was about **ergonomics, not capability**. Caddy earns its place because
cloudflared can't serve static files (the apex page) and because a declarative,
hot-reloadable Caddyfile makes **adding a project two lines + a reload** — no DNS
or tunnel change. A hand-written Node gateway was considered and rejected (it
re-implements a solved problem; its only edge, WebSocket proxying, is moot since
apps stream over SSE/HTTP). Full rationale: `openspec/changes/bootstrap-hosting-foundation/design.md`.

## Layout

| Path | What |
|------|------|
| `caddy/Caddyfile` | The router + service registry. Deploys to `/etc/caddy/Caddyfile`. |
| `cloudflared/config.yml` | Tunnel ingress template. Deploys to `/etc/cloudflared/config.yml`. |
| `systemd/caddy.service` | Caddy unit (non-root, restart-always, no start-limit lockout). |
| `systemd/app@.service` | Reusable per-project backend unit (`app@iracing`, …). |
| `systemd/journald-volatile.conf` | microSD hardening (journal in RAM). |
| `www/apex/` | Static apex landing page. Deploys to `/var/www/apex`. |
| `docs/runbook.md` | **Deploy from scratch, add a project, roll back, trade-offs.** |

## Operating it

Everything operational — first-time bring-up, adding a subdomain, rollback, and
the accepted trade-offs / escape hatches — lives in **[`docs/runbook.md`](docs/runbook.md)**.
