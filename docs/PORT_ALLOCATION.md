# Port Allocation

Network layout for all services on the VPS. Caddy is the only public entry point — everything else lives on the internal Docker network.

## Services

| Service | Container name | Internal port | Subdomain | Project |
|---------|---------------|---------------|-----------|---------|
| Caddy | caddy | 80, 443 | *.victorpatrin.dev + coupette.club (routing) | infra |
| PostgreSQL | shared-postgres | 5432 | — | shared-postgres |
| Umami | umami | 3000 | `analytics.victorpatrin.dev` | umami |
| Uptime Kuma | uptime-kuma | 3001 | `status.victorpatrin.dev` | uptime-kuma |
| URL shortener API | url-shortener-api | 8000 | `s.victorpatrin.dev` | url-shortener |
| Redis | url-shortener-redis-1 | 6379 | — | url-shortener |
| Coupette backend | coupette-backend | 8001 | `coupette.club/api` | coupette |
| Coupette bot | coupette-bot-1 | — | — | coupette |
| Coupette scraper | coupette-scraper-1 | — | — (one-shot cron) | coupette |
| Coupette frontend (static) | — | — | `coupette.club` (served by Caddy) | coupette |

## Host-exposed ports

Only two reasons to bind a port to the host:

| Port | Service | Why |
|------|---------|-----|
| 80, 443 | Caddy | Public entry point (TLS + reverse proxy) |
| 5432 | PostgreSQL | localhost only — for DBeaver, Alembic, bare-metal dev |

Everything else is internal Docker network only. Caddy reaches services by container name.

## Convention

- **One public entry point**: Caddy on 80/443. Nothing else is internet-facing.
- **Internal network**: all services join the `internal` external Docker network for cross-compose communication.
- **Match internal and host ports**: when host-exposing for dev, use `8001:8001` — one number to remember.
- **Sequential allocation**: APIs use 8000, 8001, 8002… as projects are added.
- **Third-party defaults**: keep vendor ports (Umami 3000, Uptime Kuma 3001) — not worth overriding.
