## ADDED Requirements

### Requirement: Reduced storage writes on microSD

While the host runs from microSD, the foundation SHALL keep high-frequency writes (logs) off the SD card by directing them to RAM/volatile storage, to mitigate flash wear and power-loss corruption.

#### Scenario: Logs are kept in volatile storage

- **WHEN** the system is running normally on microSD
- **THEN** service and journal logs are written to RAM/volatile storage rather than continuously to the SD card

### Requirement: Automatic recovery after unclean power loss

The host SHALL return to full service automatically after an unclean power loss or hard reboot, without manual repair under normal conditions.

#### Scenario: Recovery after power cut

- **WHEN** power is cut and restored
- **THEN** the host boots, systemd brings up `cloudflared` and Caddy, and the apex page is reachable again without manual steps

### Requirement: Documented storage escape hatch

The repository SHALL document the migration path to the Orange Pi 5's M.2 NVMe slot as the remediation to apply if microSD instability or corruption appears.

#### Scenario: Escape hatch is available

- **WHEN** an operator observes SD corruption or instability
- **THEN** the documentation provides the steps to migrate the root filesystem to NVMe as the remediation
