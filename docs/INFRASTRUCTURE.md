# Infrastructure Overview

Single Hetzner VPS running all services behind a Caddy reverse proxy. Designed for simplicity — one server, one entry point, minimal moving parts.

## VPS

- **Provider**: Hetzner CX22
- **OS**: Debian 13
- **Host**: `web-01`
- **User**: `victor` (root SSH disabled)
- **Swap**: 2GB at `/swapfile`, swappiness=10
- **DNS**: `victorpatrin.dev` + wildcard `*.victorpatrin.dev` → VPS IP (Porkbun)

## Architecture

```text
Internet
  │
  ▼
Caddy (ports 80/443)
  ├── victorpatrin.dev          → static files (/srv/homepage)
  ├── wine.victorpatrin.dev     → static SPA + reverse proxy to saq-backend:8001
  ├── s.victorpatrin.dev        → reverse proxy to url-shortener-api:8000
  ├── analytics.victorpatrin.dev → reverse proxy to umami:3000
  └── status.victorpatrin.dev   → reverse proxy to uptime-kuma:3001

All services communicate over a shared Docker network ("internal").
Only Caddy binds to host ports 80/443.
PostgreSQL binds to localhost:5432 for dev tooling (DBeaver, Alembic).
```

See [PORT_ALLOCATION.md](PORT_ALLOCATION.md) for the full service/port/container mapping.

## Security

### Firewall

- Hetzner network firewall (cloud-level, before traffic hits the VPS)
- `ufw` on the VPS — ports 22, 80, 443 only

### Network isolation

- Caddy is the only internet-facing container — all other services are on the `internal` Docker network only.
- PostgreSQL is bound to `localhost:5432`, not `0.0.0.0`.

### TLS

- Caddy handles automatic HTTPS via Let's Encrypt (ACME). Certificates are auto-renewed.
- HSTS is enabled automatically by Caddy on all HTTPS sites.

### Response headers

Applied to all sites via a shared Caddyfile snippet ([#12](https://github.com/vpatrin/infra/pull/12)):

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | `nosniff` | Prevent MIME-sniffing |
| `X-Frame-Options` | `DENY` | Prevent clickjacking via iframes |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage to third parties |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disable unused browser APIs |
| `Server` | (removed) | Prevent server fingerprinting |

### SSH

- Key-only authentication (`PasswordAuthentication no`, `PermitRootLogin no`)
- Fail2ban for brute-force protection (planned)

### Access control

- GitHub branch protection on all repos (squash/rebase only, no direct push to main).
- All services with web UIs (Umami, Uptime Kuma) have built-in authentication.

## Backups

**Status: not yet automated** (tracked in [#6](https://github.com/vpatrin/infra/issues/6)).

### What's stateful

| Data | Location | Risk |
|------|----------|------|
| PostgreSQL (3 databases) | Docker volume `shared-postgres_pgdata` | **High** — user data, product catalog, analytics |
| Caddy TLS certs | Docker volume `caddy_data` | Low — auto-renewed by ACME |
| Caddy config | Docker volume `caddy_config` | Low — regenerated from Caddyfile |

### What's stateless

Everything else. All service containers can be rebuilt from their repos. Static sites are in git.

### Planned strategy

- Daily `pg_dump` of all databases (compressed), retained for 30 days.
- systemd timer at 3:00 AM.
- ~150MB disk budget (50MB DB × ~5MB compressed × 30 days).

## Monitoring

| Tool | URL | Purpose |
|------|-----|---------|
| Uptime Kuma | `status.victorpatrin.dev` | Uptime monitoring, alerts on downtime |
| Umami | `analytics.victorpatrin.dev` | Privacy-friendly web analytics |

## Deployment

Manual git-based deployment (intentional for solo dev — CI/CD overhead not justified yet).

```bash
ssh web-01
cd ~/infra
git pull
docker compose up -d --build   # full redeploy
make reload                    # Caddyfile-only, no downtime
```

Each project repo has its own deploy process. See [saq-sommelier PRODUCTION.md](https://github.com/vpatrin/saq-sommelier/blob/main/docs/PRODUCTION.md) for app-level deployment.

## Scalability

This is a single-VPS setup. Scaling considerations if needed:

- **Vertical**: upgrade the Hetzner plan (more CPU/RAM/disk).
- **Horizontal**: not designed for it — would require splitting services across servers, adding a load balancer, and externalizing PostgreSQL. Not planned.
- **Current headroom**: the VPS runs ~6 containers with low resource usage. Plenty of room for additional services.
