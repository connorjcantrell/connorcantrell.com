## Why

connorcantrell.com has no running infrastructure yet. The goal is to self-host a growing set of independent projects (each on its own subdomain) from an Orange Pi 5 at home, without exposing the box directly to the internet or hand-rolling TLS. We need a foundation that turns "I built a new project" into "add two lines and reload" — before building any individual project on top of it.

The approach is the result of dedicated research (web + Hacker News practitioner consensus, every load-bearing claim adversarially verified): a **Cloudflare Tunnel** for edge connectivity, a single local **Caddy** reverse proxy that owns all subdomain routing and serves the apex page, and **systemd** for supervision. A hand-written Node.js gateway was explicitly considered and rejected — it re-implements a solved problem, adds an attack surface (header handling, Slowloris, crash recovery) you would own, and its only theoretical edge (WebSocket proxying) is irrelevant because the apps stream over SSE/HTTP, not WebSockets.

## What Changes

- Stand up a **Cloudflare Tunnel** (`cloudflared`) on the Orange Pi 5 so the box reaches the internet through Cloudflare's edge — TLS, DNS, and DDoS protection at the edge, **zero inbound ports opened**. A single wildcard ingress (`*.connorcantrell.com → localhost:80`) plus a proxied wildcard DNS record covers all current and future subdomains without per-project tunnel edits.
- Add a single local **Caddy** reverse proxy listening on plain HTTP (TLS already terminated at the edge) that routes inbound requests by subdomain (Host header) to independent local upstream services. The **Caddyfile is the declarative service registry**: adding a project is one `reverse_proxy` block plus a zero-downtime `caddy reload`.
- Serve a minimal **static landing page** at the apex `connorcantrell.com` via Caddy's `file_server` — the one job cloudflared cannot do itself, and the proof that the full edge→tunnel→Caddy→content path works.
- Add **systemd supervision** for `cloudflared`, `Caddy`, and app backends so everything starts on boot and restarts on failure, with a restart policy that survives systemd's default start-limit. Plus a deploy/runbook doc for operating the box.
- Add **host reliability hardening**: migrate off microSD to the Orange Pi 5's M.2 NVMe slot (strongly recommended), or apply SD-write-reduction fallback (`log2ram`, volatile `journald`) — the verified #1 real-world SBC failure mode is power-loss SD corruption.

Non-goals (explicitly out of scope, deferred to later changes): the building knowledge-graph chat app, the iRacing league site (results/standings/newsletter), any per-project application logic, and any database. **Upstreams are language-agnostic** — the foundation proxies to a port, so the future Python graph app and a Node iRacing site plug in identically. This change only delivers the platform those projects plug into.

## Capabilities

### New Capabilities
- `edge-tunnel`: Cloudflare Tunnel connectivity from the Orange Pi 5 to Cloudflare's edge, including a `*.connorcantrell.com` wildcard ingress and proxied wildcard DNS, with no inbound ports exposed.
- `subdomain-routing`: A single Caddy reverse proxy that routes inbound requests by subdomain to registered local upstreams over plain HTTP, with the Caddyfile as the declarative registry / documented extension point, and defined unknown-host and upstream-down behavior.
- `landing-site`: A minimal static landing page served at the apex `connorcantrell.com` by Caddy's `file_server`, proving the full edge→tunnel→Caddy→content path.
- `service-supervision`: systemd units and an operator runbook that keep `cloudflared`, Caddy, and app backends running across reboots and failures, with a restart policy that survives the default start-limit.
- `host-reliability`: Storage and power hardening that prevents microSD corruption from power loss — NVMe migration on the Orange Pi 5's M.2 slot (recommended) or SD-write-reduction fallback.

### Modified Capabilities
<!-- None — this is a greenfield foundation; no existing specs. -->

## Impact

- **Repo**: Built fresh — a Caddyfile (the service registry), a static apex site, `cloudflared` tunnel config, systemd unit files, and deploy/ops docs. No application framework or Node runtime is required by the foundation itself.
- **Dependencies**: `cloudflared` and `caddy` binaries (ARM64) on the Orange Pi 5. No Node.js/Python required for the platform; individual projects bring their own runtimes.
- **External systems**: A Cloudflare account managing the `connorcantrell.com` zone (DNS + Tunnel). Outbound HTTPS from the box to Cloudflare's edge. Trade-offs accepted: Cloudflare is a shared single point of failure across subdomains, terminates TLS at the edge, and restricts large-media serving on the free tier (use R2 if ever needed).
- **Host**: Orange Pi 5 (RK3588S, 4GB) running Linux with systemd; services run under a dedicated non-root service user. Storage migrated to NVMe (recommended) or SD-hardened.
- **Foundation for**: future per-subdomain projects (graph chat app, iRacing league) plug in via one Caddyfile block + reload — no tunnel or DNS change.
