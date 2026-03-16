# infra

Platform infrastructure for `victorpatrin.dev` — service definitions, reverse proxy, backups, and static assets.

## What's in here

- **services/** — per-service config and data
  - `caddy/` — Caddyfile (reverse proxy routing + TLS)
  - `homepage/` — static site for `victorpatrin.dev`
  - `postgres/` — init scripts, backup scripts + systemd units
  - `umami/` — analytics (.env config)
  - `uptime-kuma/` — monitoring (zero-config, data in Docker volume)
- **docker-compose.yml** — all service definitions (Caddy, PostgreSQL, Umami, Uptime Kuma)
- **scripts/** — repo setup automation (`setup-repo.sh`)
- **docs/** — infrastructure overview, port allocation

## Routing

| Domain | Target |
|--------|--------|
| `victorpatrin.dev` | Static homepage |
| `s.victorpatrin.dev` | url-shortener API |
| `analytics.victorpatrin.dev` | Umami |
| `status.victorpatrin.dev` | Uptime Kuma |
| `coupette.club` | Coupette (API + SPA) |

## Deployment

```bash
ssh web-01
cd ~/infra
git pull
docker compose up -d --build
```

For Caddyfile-only changes (no downtime):

```bash
make reload
```
