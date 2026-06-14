## ADDED Requirements

### Requirement: Boot persistence

`cloudflared`, Caddy, and each app backend SHALL run under systemd as enabled units so they start automatically on boot.

#### Scenario: Services return after reboot

- **WHEN** the Orange Pi 5 is rebooted
- **THEN** `cloudflared` and Caddy start automatically and the apex page is reachable without manual intervention

### Requirement: Crash recovery without start-limit lockout

Supervised services SHALL be restarted automatically on failure, and the restart policy SHALL NOT permanently stop a service after repeated rapid failures (e.g. `StartLimitIntervalSec=0` with `Restart=always`, or exponential backoff on systemd ≥254).

#### Scenario: A crashed service is restarted

- **WHEN** the Caddy process is killed
- **THEN** systemd restarts it within seconds and routing resumes

#### Scenario: Repeated rapid failures still recover

- **WHEN** a service crashes more than five times within ten seconds
- **THEN** systemd continues attempting restarts rather than entering a permanent failed state

### Requirement: Least-privilege service user

The foundation services SHALL run as a dedicated non-root service user, not as root.

#### Scenario: Service runs as non-root

- **WHEN** the Caddy service is running
- **THEN** its process owner is the dedicated service user, not root

### Requirement: Operator runbook

The repository SHALL include a runbook documenting how to deploy the foundation, add a new subdomain/service, and roll back.

#### Scenario: Adding a service is documented

- **WHEN** an operator needs to add a new project subdomain
- **THEN** the runbook provides the exact steps (Caddyfile block + reload + systemd unit) required, with no undocumented manual knowledge needed
