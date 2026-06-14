## 1. Repo scaffolding

- [x] 1.1 Create the foundation repo layout: `caddy/Caddyfile`, `cloudflared/config.yml` (template, no secrets), `systemd/` unit files, `www/apex/` static site, `docs/runbook.md`
- [x] 1.2 Add a `.gitignore` that excludes tunnel credentials (`*.json` cred files), `.env`, and any secrets; commit only templates/placeholders
- [x] 1.3 Write a top-level `README.md` describing the architecture (edge→tunnel→Caddy→app) and pointing to `docs/runbook.md`

## 2. Host preparation (Orange Pi 5)

- [ ] 2.1 Create a dedicated non-root service user/group for the foundation services
- [ ] 2.2 Apply microSD hardening: install/enable `log2ram` (or tmpfs for `/var/log`) and set `journald` `Storage=volatile` (or capped `RuntimeMaxUse`)
- [ ] 2.3 Install the `cloudflared` ARM64 binary and the `caddy` ARM64 binary; pin/record versions
- [ ] 2.4 Verify both binaries run (`cloudflared --version`, `caddy version`) on the box

## 3. Cloudflare Tunnel (edge-tunnel)

- [ ] 3.1 Authenticate `cloudflared` to the Cloudflare account and create a named tunnel for the host
- [x] 3.2 Write `cloudflared/config.yml` with a wildcard ingress (`*.connorcantrell.com → http://localhost:80`), an apex rule, and the required `http_status:404` catch-all; reference the credentials file by path
- [ ] 3.3 Create the proxied wildcard CNAME (`* → <UUID>.cfargotunnel.com`) and apex record in the Cloudflare dashboard (the CLI/form reject `*`)
- [ ] 3.4 Confirm no inbound router ports are opened; verify the tunnel connects outbound and shows healthy in the dashboard

## 4. Caddy routing + apex (subdomain-routing, landing-site)

- [x] 4.1 Author the static apex page in `www/apex/` (`index.html` + minimal CSS) deployed to `/var/www/apex`
- [x] 4.2 Write the Caddyfile: global `trusted_proxies` for the tunnel/Cloudflare so `Cf-Connecting-Ip` is honored; auto-HTTPS off (listen on `:80` HTTP)
- [x] 4.3 Add the apex site block (`file_server` from the apex root) and one example `reverse_proxy` block for a test upstream
- [ ] 4.4 Confirm unknown-host returns 404 and an upstream-down subdomain returns 502 without affecting the apex
- [ ] 4.5 Confirm `caddy reload` applies changes with zero downtime to in-flight requests

## 5. Process supervision (service-supervision)

- [ ] 5.1 Install the `cloudflared` systemd service (`cloudflared service install`) and enable it at boot
- [x] 5.2 Write and install a Caddy systemd unit running as the service user, with `Restart=always`, sensible `RestartSec`, and `StartLimitIntervalSec=0` (or systemd ≥254 backoff) to avoid start-limit lockout _(unit authored at `systemd/caddy.service`; host install in runbook §1.7)_
- [x] 5.3 Add a reusable app-backend unit template (`docs/` or `systemd/app@.service`) for future per-subdomain services
- [ ] 5.4 Enable all units at boot; verify `systemctl is-enabled` for each

## 6. End-to-end verification

- [ ] 6.1 Browse `https://connorcantrell.com` from an external network: valid edge TLS, apex page served (full path proof)
- [ ] 6.2 Start a throwaway local service, add a Caddyfile block + reload, and confirm `test.connorcantrell.com` proxies to it with no DNS/tunnel change
- [ ] 6.3 Kill the Caddy process and confirm systemd restarts it and routing resumes
- [ ] 6.4 Reboot the box and confirm cloudflared + Caddy come back and the apex is reachable unattended
- [ ] 6.5 (Optional) Simulate an unclean power loss and confirm automatic recovery

## 7. Documentation (runbook)

- [x] 7.1 Write `docs/runbook.md`: deploy from scratch, add a new subdomain/service (Caddyfile block + reload + app unit), and roll back (stop services; remove tunnel + wildcard CNAME)
- [x] 7.2 Document accepted trade-offs (Cloudflare SPOF, edge TLS termination/privacy for future LLM app, ~100 MB media cap) and the NVMe escape-hatch migration steps for storage issues
- [x] 7.3 Document the enumerated-subdomain fallback (per-name ingress + CNAME) to use if the wildcard ECH/Chrome gotcha appears
