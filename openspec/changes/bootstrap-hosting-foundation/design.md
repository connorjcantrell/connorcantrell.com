## Context

connorcantrell.com is a fresh start with no running infrastructure. The target host is an **Orange Pi 5 (RK3588S, 4GB RAM)** at home, currently booting from **microSD**. The `connorcantrell.com` zone is on Cloudflare. The objective is a *foundation* — not an application — that lets independent, polyglot projects each live on their own subdomain (`iracing.connorcantrell.com`, `graph.connorcantrell.com`, …) and be added cheaply. Two known future tenants set the requirements: a Python (FastAPI) knowledge-graph chat app that streams from the Anthropic API, and a Node iRacing league site. Neither is in scope here.

This design is the product of dedicated research (official docs + Hacker News practitioner consensus, with every load-bearing claim adversarially verified). The headline finding: routing N subdomains to N ports is *possible* with cloudflared alone, so the decision is about **operational ergonomics, not capability**.

## Goals / Non-Goals

**Goals:**
- Reach the internet with **zero inbound ports** and edge-terminated TLS.
- Route any `*.connorcantrell.com` subdomain to a local service, language-agnostic, by editing one config block.
- Serve a static apex landing page proving the full path end-to-end.
- Survive reboots and process crashes unattended.
- Keep the platform itself dependency-light (no app framework, no Node/Python runtime required by the foundation).

**Non-Goals:**
- Any per-project application logic (graph app, iRacing site), database, or newsletter system.
- A hand-written Node.js gateway (considered and rejected — see Decisions).
- Public-internet exposure without Cloudflare; multi-host/HA; container orchestration.
- Migrating off microSD now (deferred to an escape hatch unless reliability issues appear).

## Decisions

### D1 — Cloudflare Tunnel for ingress
`cloudflared` connects outbound to Cloudflare's edge; no router port-forwarding, no dynamic-DNS, no origin certificate management. TLS, DNS, and a baseline WAF/DDoS live at the edge. **Alternative rejected:** port-forward + DDNS + Let's Encrypt — exposes the home IP and an open port, and re-implements what the edge gives for free. cloudflared installs its own systemd unit (`Type=notify`, `Restart=on-failure`, `RestartSec=5`), so tunnel resilience is solved out of the box.

### D2 — One local Caddy reverse proxy behind the tunnel (the core decision)
A single Caddy instance owns all host-based routing and serves the apex. Rationale, from the research:
- **cloudflared can route subdomains but cannot serve static files.** The apex landing page is the concrete reason a local proxy exists at all.
- **Caddy is a single ~30 MB ARM64 binary, declarative, hot-reloadable, zero code to maintain.** Adding a project is ~2 lines + `caddy reload` (zero-downtime).
- **Alternatives considered:**
  - *cloudflared-only* — viable and lowest-footprint, but can't serve the apex and scatters routing into tunnel config. Kept as a fallback, not the foundation.
  - *Traefik* — heaviest on ARM (~180 MB), its auto-TLS is redundant behind the tunnel, and its Docker-label discovery only pays off with heavy container churn we don't have.
  - *Hand-written Node.js gateway (Fastify/Express/Hono)* — **rejected.** Re-implements a solved problem; makes us own header correctness, crash recovery, CVEs, and historical Slowloris exposure (Node request timeouts only became default in v18). HN consensus: "production Node sits behind nginx/Caddy." Its one theoretical edge — WebSocket proxying — is moot: our apps stream over **SSE/HTTP chunked** (how the Anthropic API streams), which every proxy handles.

### D3 — Wildcard ingress + wildcard DNS (vs enumerated per-subdomain)
One tunnel ingress rule `*.connorcantrell.com → http://localhost:80` plus a single **proxied wildcard CNAME** (`* → <UUID>.cfargotunnel.com`). New subdomains then need **no DNS or tunnel change** — only a Caddyfile block. **Verified caveats:** the dashboard form and `cloudflared tunnel route dns` reject `*` (set the wildcard via config/API + create the CNAME manually); a proxied wildcard can publish ECH records that occasionally break Chrome (`ERR_ECH_FALLBACK_CERTIFICATE_INVALID`). **Fallback:** enumerate per-subdomain ingress rules + per-name CNAMEs (auto-created by the CLI), accepting a two-system edit per project.

### D4 — Plain HTTP internally; correct client IP
Cloudflare terminates TLS at the edge, so Caddy listens on `:80` plaintext and its automatic HTTPS stays **off** (dormant — it becomes the migration escape hatch if we ever drop the tunnel). Because traffic arrives via the tunnel, the real visitor IP is in `Cf-Connecting-Ip`; configure Caddy `trusted_proxies` so logs and any future rate-limiting see the right address.

### D5 — systemd, one unit per service (vs Docker Compose / pm2)
On a 4GB board, systemd-native is the leanest, language-agnostic supervisor with journald logging — no Docker daemon overhead or SD write amplification. cloudflared and Caddy each get a unit; each future app gets a ~10-line unit. **Critical gotcha (verified):** systemd stops restarting after 5 failures/10s by default — set `StartLimitIntervalSec=0` with `Restart=always`/`RestartSec`, or use exponential backoff on systemd ≥254. **Alternative:** a single Docker Compose stack with `restart: unless-stopped` (uniform lifecycle) — viable later, but heavier here; never double-supervise.

### D6 — Static apex via Caddy `file_server`
The apex is plain HTML/CSS served directly by Caddy from `/var/www/apex`. No SSG/Node build in the foundation; the page can be replaced by a richer app later by pointing one Caddyfile block at a port.

### D7 — Storage: stay on microSD with hardening (user decision)
microSD power-loss corruption is the verified #1 SBC failure mode, and the Orange Pi 5 has an M.2 NVMe slot that would eliminate it. The user has chosen to **stay on microSD for now**. Mitigations applied: `log2ram` (or tmpfs) for `/var/log`, `journald` `Storage=volatile`, minimize writes, and clean-shutdown discipline. **Escape hatch:** migrate the rootfs to an NVMe SSD if corruption/instability appears — orthogonal to the routing design and reversible.

### D8 — Push cross-cutting concerns to the edge where they fit
Cloudflare's free tier provides a baseline WAF, one rate-limiting rule, and Access (zero-trust auth) for *private* apps. The foundation leaves hooks for these rather than building them locally. Note: Access can't gate *public* apps without forcing every visitor to log in, and per-token LLM cost control must live in the app — both are future concerns, not foundation work.

## Risks / Trade-offs

- **Cloudflare is a shared single point of failure** across all subdomains (multiple multi-hour global outages in 2025–2026). → Inherent to the tunnel; accepted. Caddy holds the real routing config locally, so the escape hatch (D4) is a DNS change away.
- **Edge sees decrypted traffic** (TLS terminates at Cloudflare) — a privacy note for the future LLM chat app. → Accepted as a trade for free edge TLS/DDoS; document it for that project.
- **Edge latency** (~10–200 ms via PoP) on an interactive chat app. → Accepted; revisit only if the graph app feels slow.
- **Free-tier media cap** (~100 MB request body; no large-media serving). → Our HTML/JSON/SSE projects are fine; a future media project must use R2/direct-to-storage.
- **microSD corruption risk retained** (D7). → Mitigated by log-to-RAM + clean shutdowns; NVMe escape hatch documented.
- **Caddy as a local single point of failure** for all subdomains. → systemd `Restart=always` + hot-reload (no restart for config changes) keeps blast radius small.
- **Wildcard ECH/Chrome gotcha** (D3). → Fallback to enumerated per-subdomain records if it ever triggers.

## Migration Plan

Deployment order (each step independently verifiable):
1. Harden the host (service user, `log2ram`/volatile journald), install `cloudflared` and `caddy` (ARM64).
2. Create the tunnel; write `cloudflared` config with the wildcard ingress; create the proxied wildcard CNAME + apex record.
3. Write the Caddyfile (apex `file_server` + one example `reverse_proxy`); publish the static apex page.
4. Install systemd units (cloudflared via `cloudflared service install`; Caddy; restart policy with the StartLimit fix); enable at boot.
5. Smoke-test: `https://connorcantrell.com` serves the apex; an example subdomain proxies to a local test port; reboot and confirm everything returns.

**Rollback:** `systemctl stop` Caddy/cloudflared and the site is offline with no public exposure left behind (no open ports). Removing the tunnel + wildcard CNAME fully reverts DNS. Config is text files in the repo, so any step is re-runnable.

## Open Questions

- **Wildcard vs enumerated subdomains** (D3): default to wildcard for lowest friction, or pre-empt the ECH/CNAME gotchas with per-name records? (Recommend wildcard; switch if Chrome issues appear.)
- **Apex content**: keep a hand-written static page indefinitely, or replace it later with a generated site / project index?
- **When to trigger the NVMe escape hatch** (D7): purely reactive (on first corruption), or proactively before the graph app goes live?
