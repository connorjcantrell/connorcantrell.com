## ADDED Requirements

### Requirement: Host-based routing to local upstreams

A single Caddy instance SHALL route inbound requests by Host header to the configured local upstream service over plain HTTP. Upstreams MAY be implemented in any language.

#### Scenario: Known subdomain is proxied to its upstream

- **WHEN** Caddy receives a request for `graph.connorcantrell.com` and an upstream is configured at `localhost:8002`
- **THEN** Caddy reverse-proxies the request to `localhost:8002` and returns its response

### Requirement: Declarative service registry

The Caddyfile SHALL be the single declarative registry of subdomain-to-upstream mappings. Adding a new project SHALL require only adding one `reverse_proxy` block and reloading Caddy, with no DNS or tunnel change.

#### Scenario: Adding a new project

- **WHEN** an operator adds a `reverse_proxy` block for `new.connorcantrell.com → localhost:PORT` and runs `caddy reload`
- **THEN** the new subdomain begins serving from that upstream without editing the tunnel or DNS

#### Scenario: Reload is zero-downtime

- **WHEN** `caddy reload` is run while other subdomains are serving traffic
- **THEN** in-flight requests to existing subdomains complete and no existing subdomain returns a connection error

### Requirement: Unknown host handling

When a request arrives for a host that has no configured route, Caddy SHALL return a defined response (HTTP 404) and SHALL NOT forward it to an unrelated upstream.

#### Scenario: Request for an unconfigured subdomain

- **WHEN** a request arrives for `unknown.connorcantrell.com` with no matching route
- **THEN** Caddy returns HTTP 404 and does not proxy to any other service's upstream

### Requirement: Upstream-down isolation

When a configured upstream is unreachable, Caddy SHALL return an error response for that subdomain only and SHALL continue serving all other subdomains.

#### Scenario: One upstream is down

- **WHEN** the upstream for `iracing.connorcantrell.com` is stopped
- **THEN** requests to `iracing.connorcantrell.com` return HTTP 502 while `connorcantrell.com` and other subdomains continue to respond normally

### Requirement: Correct client IP propagation

Caddy SHALL be configured to trust the tunnel and read the real visitor address from Cloudflare (`Cf-Connecting-Ip`) so that logs and any future rate-limiting reflect the actual client, not a local proxy address.

#### Scenario: Real client IP is recorded

- **WHEN** an external visitor makes a request through the tunnel
- **THEN** Caddy's access log records the visitor's real IP rather than a loopback or Cloudflare infrastructure address

### Requirement: Streaming passthrough

Caddy SHALL pass server-sent events and chunked/streaming HTTP responses through to the client without buffering the full body, so future streaming apps (e.g. an LLM chat endpoint) work unmodified.

#### Scenario: SSE response streams incrementally

- **WHEN** an upstream returns a `text/event-stream` response that emits events over time
- **THEN** Caddy forwards each chunk to the client as it arrives rather than withholding the response until completion
