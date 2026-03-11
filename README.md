# infra

Server configuration for `victorpatrin.dev` — reverse proxy routing, TLS termination, and static assets.

## What's in here

- **Caddyfile** — reverse proxy routing + TLS termination for all subdomains
- **docker-compose.yml** — Caddy container
- **homepage/** — static site served on `victorpatrin.dev`
- **`/srv/coupette`** (host path) — static SPA for `coupette.club`
- **scripts/** — repo setup automation (`setup-repo.sh`)
- **docs/** — port allocation and network layout documentation
- **.github/** — PR template

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
