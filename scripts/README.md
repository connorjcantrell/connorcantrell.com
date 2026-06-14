# Bring-up scripts

Idempotent shell scripts that stand up the foundation on the Orange Pi 5. They
mirror `docs/runbook.md §1` and source shared config from `env.sh` (edit values
there). Run them from the repo on the Pi.

> Most steps use `sudo`. Step `03` is **interactive** (opens a browser for the
> Cloudflare login). All steps are safe to re-run.

## All at once

```bash
./scripts/bringup.sh
```

## Or step by step

| Script | Does | Notes |
|--------|------|-------|
| `01-host-prep.sh` | service user, dirs, journald-in-RAM, log2ram | sudo |
| `02-install-binaries.sh` | install + version-pin `cloudflared`, `caddy` (arm64) | sudo, network |
| `03-tunnel-create.sh` | login, create tunnel, place config/creds, set DNS | **interactive** |
| `03b-dns-api.sh <UUID>` | create `*` + `@` CNAMEs via Cloudflare API | optional; needs `CLOUDFLARE_API_TOKEN` |
| `04-deploy-config.sh` | deploy Caddyfile + apex page, validate | sudo |
| `05-install-services.sh` | install + enable `cloudflared` and `caddy` units | sudo |
| `06-smoke-test.sh` | local origin checks (apex 200, unknown-host 404) | — |

## Automating the DNS step

By default `03` prints the two CNAMEs and waits for you to add them in the
dashboard (the dashboard/CLI reject `*`, so they're manual there). To skip that,
create a Cloudflare API token with **Zone.DNS:Edit** on `connorcantrell.com` and:

```bash
export CLOUDFLARE_API_TOKEN=xxxxxxxx
./scripts/bringup.sh        # 03 will create the records via the API automatically
```

## After bring-up

```bash
sudo reboot                 # confirm services return unattended (task 6.4)
```

Adding a new project later is not in these scripts — it's two lines + a reload;
see `docs/runbook.md §2`.
