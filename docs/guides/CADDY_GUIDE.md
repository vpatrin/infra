# Caddy Guide

Patterns and procedures for working with the Caddyfile in this repo. Caddy handles all TLS, routing, static file serving, and security headers.

Config: `services/caddy/Caddyfile`
ADR: [0002-caddy-reverse-proxy.md](../decisions/0002-caddy-reverse-proxy.md)

## Caddyfile structure

```text
{global options}        # admin API, metrics
(snippets)              # reusable blocks (security headers)
domain blocks           # one per site
catch-all               # reject unknown hosts
```

Each domain block follows this pattern:

```caddyfile
example.com {
    import security_headers              # shared snippet
    header Content-Security-Policy "…"   # per-site CSP
    encode zstd gzip                     # compression
    reverse_proxy backend:8001           # or file_server for static
}
```

## Adding a new route

1. Add a domain block to the Caddyfile
2. Import `security_headers` snippet
3. Add a per-site `Content-Security-Policy` header — don't use the default, think about what the site actually loads
4. Add `encode zstd gzip`
5. Route to the backend container by name on the `internal` network
6. Update the service inventory in [ARCHITECTURE.md](../ARCHITECTURE.md#services)
7. Test locally, then deploy: `git pull && make reload-caddy` (no downtime)

## Serving a static SPA

Static SPAs need `try_files` to handle client-side routing — without it, direct navigation to `/about` returns 404 because there's no `/about` file on disk.

```caddyfile
handle {
    root * /srv/my-app
    file_server
    try_files {path} /index.html
}
```

Mount the static files as a volume in `docker-compose.yml`:

```yaml
volumes:
  - /srv/my-app:/srv/my-app:ro
```

## Combining static SPA + API

Use `handle` blocks to split API and static traffic. Order matters — more specific paths first:

```caddyfile
my-app.com {
    import security_headers
    header Content-Security-Policy "…"
    encode zstd gzip
    handle /api/* {
        reverse_proxy my-backend:8001
    }
    handle {
        root * /srv/my-app
        file_server
        try_files {path} /index.html
    }
}
```

## www redirect

Redirect `www.` to the bare domain:

```caddyfile
www.example.com {
    redir https://example.com{uri} permanent
}
```

Place this above the main domain block.

## Security headers snippet

The `(security_headers)` snippet applies to all sites via `import`. It sets HSTS, X-Frame-Options, Referrer-Policy, Permissions-Policy, and strips the Server header.

CSP is **not** in the snippet — it's per-site because each site loads different resources. Define it as a `header` directive in each domain block.

See [SECURITY.md](../SECURITY.md#response-headers) for the full header table.

## Prometheus metrics

Caddy exposes metrics at `:2019/metrics` (admin API). The global options block enables this:

```caddyfile
{
    admin 0.0.0.0:2019
    servers {
        metrics
    }
}
```

Prometheus scrapes `caddy:2019` on the internal network. The admin API is not exposed to the host.

## Catch-all block

The `:80` catch-all at the bottom rejects requests to unknown hostnames or bare IP. HTTPS requests to unknown hosts fail at TLS handshake (no matching certificate) before reaching Caddy.

## Validation and reload

```bash
# Validate syntax (inside the container)
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

# Reload without downtime
make reload-caddy

# Full restart (only if container config changed)
make restart
```

`make reload-caddy` runs `caddy reload` inside the container — zero downtime, existing connections are not dropped.

## Common mistakes

- **Missing `encode zstd gzip`** — Caddy doesn't compress by default. Every site block needs it.
- **Wrong handle order** — `handle /api/*` must come before the catch-all `handle`. Caddy uses first-match, not longest-match.
- **CSP too loose** — don't copy-paste CSP from another site. Each site should only allow the origins it actually uses.
- **Forgetting the www redirect** — add a `www.` redirect block for every new domain.
