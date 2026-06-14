## ADDED Requirements

### Requirement: Static apex landing page

Caddy SHALL serve a static landing page at the apex `connorcantrell.com` from a local directory using its file server, with no application runtime required.

#### Scenario: Apex serves the landing page

- **WHEN** a visitor requests `https://connorcantrell.com/`
- **THEN** Caddy returns the static landing page (HTTP 200, HTML) from the configured site root

### Requirement: End-to-end path proof

The landing page SHALL be reachable over the full edge→tunnel→Caddy→file path over HTTPS, demonstrating the foundation works end to end.

#### Scenario: Full path works over HTTPS

- **WHEN** the landing page is requested from an external network over `https://connorcantrell.com`
- **THEN** the response is served with valid edge TLS, having traversed the tunnel and Caddy to the static file
