# Service Catalog

All services on the platform, how they connect, and what app repos depend on. If any contract changes, app deploy scripts must be updated in the same logical change.

---

## Docker Network

An external Docker network named `internal` exists on the VPS. All infra services and app services attach to it.

```yaml
# In app repo docker-compose.yml:
networks:
  internal:
    external: true
```

App containers reach infra services by container name (e.g. `shared-postgres`, `caddy`). Infra services reach app containers the same way (e.g. `coupette-backend`).

**Do not rename this network.** All running services depend on it.

## PostgreSQL

A PostgreSQL 16 container with pgvector runs as `shared-postgres` on the `internal` network.

| Property | Value |
|----------|-------|
| Container name | `shared-postgres` |
| Image | `pgvector/pgvector:0.8.2-pg16` |
| Internal port | 5432 |
| Host binding | `127.0.0.1:5433` (dev override only, for DBeaver/Alembic) |
| Health check | `pg_isready` every 5s |

### Databases

| Database | Owner | App |
|----------|-------|-----|
| `saq_sommelier` | `saq_sommelier` | coupette |
| `umami` | `umami` | umami |

Databases and users are created by [init-scripts/01-init-databases.sh](../services/postgres/init-scripts/01-init-databases.sh) on first container start only. Credentials come from `services/postgres/.env`.

### Required extensions

Extensions are created per-database. App repos may also create extensions in their migrations.

| Extension | Database | Purpose |
|-----------|----------|---------|
| `vector` (pgvector) | `saq_sommelier` | 1536-dim embeddings for wine search (text-embedding-3-large, Matryoshka) |
| `pg_trgm` | `saq_sommelier` | Trigram similarity for full-text search |

The `vector` extension is created by the init script. `pg_trgm` is created by coupette's Alembic migrations.

### Connection from app repos

```bash
# Production: connect via container name on internal network
DB_HOST=shared-postgres
DB_PORT=5432
```

## Caddy Routing

Caddy is the only internet-facing container. It routes traffic to app backends by container name on the `internal` network.

Adding or modifying a route requires a PR to this repo — app repos do not touch the [Caddyfile](../services/caddy/Caddyfile).

### Service inventory

| Service | Container | Port | Dev binding | Domain | Owner |
|---------|-----------|------|------------|--------|-------|
| Caddy | caddy | 80, 443 | `0.0.0.0:80`, `0.0.0.0:443` (base) | all (reverse proxy) | infra |
| PostgreSQL | shared-postgres | 5432 | `127.0.0.1:5433` | — | infra |
| Umami | umami | 3000 | `127.0.0.1:3000` | `analytics.victorpatrin.dev` | infra |
| Uptime Kuma | uptime-kuma | 3001 | `127.0.0.1:3001` | `status.victorpatrin.dev` | infra |
| Loki | loki | 3100 | — | — | infra |
| Prometheus | prometheus | 9090 | `127.0.0.1:9090` | — | infra |
| Alloy | alloy | 12345 | `127.0.0.1:12345` | — | infra |
| Grafana | grafana | 3000 | `127.0.0.1:3003` (dev) / `127.0.0.1:3002` (prod) | — | infra |
| Coupette backend | coupette-backend | 8001 | — | `coupette.club/api` | coupette |
| Coupette bot | coupette-bot | — | — | — | coupette |
| Coupette scraper | coupette-scraper | — | — | — (systemd timer) | coupette |
| Coupette frontend | — | — | — | `coupette.club` (static, served by Caddy) | coupette |

Dev bindings are defined in `docker-compose.dev.yml` (loaded via `make up`). Only Caddy has host port bindings in the base compose. Production adds localhost bindings for SSH tunnel access to the observability stack (`docker-compose.prod.yml`).

Only Caddy is internet-facing. Everything else is internal Docker network or localhost-only.

### Port convention

- **One public entry point:** Caddy on 80/443. Nothing else is internet-facing.
- **Custom APIs:** 8000, 8001, 8002… as projects are added.
- **Third-party services:** keep vendor default ports (Umami 3000, Uptime Kuma 3001).
- **Match internal and host ports:** when host-exposing for dev, use `8001:8001`.

### Adding a new app route

1. Open a PR to this repo adding a domain block to `services/caddy/Caddyfile`
2. Ensure the app container name is unique and joins the `internal` network
3. Allocate the next sequential port (APIs: 8000+, third-party: keep vendor default)
4. Update the service inventory table above
5. Deploy: `git pull && make reload` on VPS (no downtime)

## Backup Script

The backup script is called by app deploy scripts before running migrations.

| Property | Value |
|----------|-------|
| Path on VPS | `/home/deploy/infra/scripts/postgres_backup.sh` |
| Interface | `./scripts/postgres_backup.sh [db_name]` — dumps one DB, or all if no argument |
| Output | `/var/backups/postgres/<db_name>_YYYYMMDD.sql.gz` |
| Retention | 30 days |
| Container | Runs `pg_dump` inside `shared-postgres` via `docker exec` |

Example from coupette's deploy script:

```bash
/home/deploy/infra/scripts/postgres_backup.sh saq_sommelier
```

**Do not change the script path, arguments, or output format** without updating app deploy scripts that call it.

## App Deployment Assumptions

These assumptions apply to [coupette](https://github.com/vpatrin/coupette) — the main app on this platform. See its [PRODUCTION.md](https://github.com/vpatrin/coupette/blob/main/docs/PRODUCTION.md) for the full deploy process.

### Working directory

Coupette is deployed to `/opt/coupette` on the VPS. Systemd timer units use `WorkingDirectory=/opt/coupette`. The deploy script writes an `.image-tag` file there that timers read to pull the correct container image version.

### Deploy dependency order

Infra services must be healthy before app deploys can succeed:

1. `shared-postgres` must be healthy (app backends connect on startup)
2. `caddy` must be running (routes traffic to app containers)
3. `internal` network must exist (all containers attach to it)

If `make restart` is run on infra, app backends may lose postgres connectivity for ~10-30 seconds. App health checks should tolerate this.

### Timer scheduling

Timers are sequenced to avoid conflicts and ensure pre-job backups:

```text
Daily (UTC):
  02:00  coupette-availability (stock refresh, ~5-18 min) [app-owned]
  06:00  disk-alert (disk usage check, alerts if >85%)

Sunday (UTC):
  02:00  pg-backup (weekly dump of all databases)

Monday (UTC):
  03:00  coupette-scraper (scrape → enrich → embed, ~1-2 hours) [app-owned]
```

Backup runs Sunday, a full day before the Monday scraper — ensuring a clean pre-scrape dump. All timers use `Persistent=true` — if the VPS is down during the scheduled time, the job runs on next boot.

## Deployment

### Repo layout

| Path | Owner | Purpose |
| --- | --- | --- |
| `/home/deploy/infra/` | `deploy` | infra repo |
| `/home/deploy/projects/coupette/` | `deploy` | coupette repo |
| `/opt/coupette` | symlink | → `/home/deploy/projects/coupette` |
| `/srv/coupette/` | `deploy` | frontend static files (served by Caddy) |

### Deploy user

A dedicated `deploy` system user owns all repos and runs CI workloads. It has no sudo except for scoped systemd commands. Human admin work uses `victor`.

### SSH deploy key

A dedicated `github_actions_deploy` ed25519 key authenticates GitHub Actions to the VPS as the `deploy` user. It is stored as `SSH_DEPLOY_KEY` in GitHub Actions secrets on both repos. App repos must use this key — do not use personal SSH keys in CI.

### Infra deploy

Infra deploys are triggered manually via GitHub Actions (workflow dispatch). The workflow validates Caddyfile + compose, then runs `deploy_infra.sh` on the VPS as `deploy`.

### App deploy

App repos trigger their own deploy workflows. After a successful deploy, the app is responsible for running its own `deploy.sh` on the VPS. Infra guarantees the platform contract (network, postgres, Caddy routes) is intact before any app deploy runs.
