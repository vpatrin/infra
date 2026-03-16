# infra

Platform infrastructure for `victorpatrin.dev` — service definitions, reverse proxy, backups, and static assets.

## What's in here

- **services/** — per-service config and data
  - `caddy/` — Caddyfile (reverse proxy routing + TLS)
  - `homepage/` — static site for `victorpatrin.dev`
  - `postgres/` — backup scripts + systemd units
- **docker-compose.yml** — all service definitions
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
