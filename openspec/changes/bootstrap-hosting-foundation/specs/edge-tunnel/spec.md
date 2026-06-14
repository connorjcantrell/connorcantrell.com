## ADDED Requirements

### Requirement: Outbound-only edge connectivity

The host SHALL reach the public internet exclusively through an outbound Cloudflare Tunnel (`cloudflared`). No inbound ports SHALL be opened on the home network or router for this service.

#### Scenario: Tunnel is established outbound

- **WHEN** `cloudflared` starts on the Orange Pi 5
- **THEN** it establishes an outbound connection to Cloudflare's edge and registers the tunnel without any router port-forward

#### Scenario: No inbound ports exposed

- **WHEN** the public IP of the home network is port-scanned
- **THEN** no inbound port is open for the site, and all traffic arrives only via the tunnel

### Requirement: Wildcard subdomain ingress

The tunnel SHALL route every `*.connorcantrell.com` host and the apex to the local Caddy proxy via a single wildcard ingress rule plus a proxied wildcard DNS record, so that new subdomains require no tunnel or DNS change.

#### Scenario: Existing subdomain is reachable

- **WHEN** a request arrives for `iracing.connorcantrell.com`
- **THEN** the tunnel forwards it to `http://localhost:80` where Caddy handles routing

#### Scenario: New subdomain needs no DNS or tunnel edit

- **WHEN** a new subdomain `foo.connorcantrell.com` is requested for the first time
- **THEN** it resolves through the existing wildcard CNAME and reaches Caddy with no new DNS record and no tunnel reconfiguration

### Requirement: Edge TLS termination

Cloudflare SHALL terminate TLS at the edge and the tunnel SHALL deliver plain HTTP to the local origin.

#### Scenario: HTTPS served at the edge

- **WHEN** a visitor requests `https://connorcantrell.com`
- **THEN** Cloudflare serves a valid TLS certificate at the edge and the origin (Caddy) receives the request over plain HTTP
