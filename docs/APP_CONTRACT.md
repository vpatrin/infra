# App Contract

Platform guarantees and expectations for apps on this VPS. If any contract changes, app deploy scripts must be updated in the same logical change.

Currently applies to [coupette](https://github.com/vpatrin/coupette) — see its [PRODUCTION.md](https://github.com/vpatrin/coupette/blob/main/docs/PRODUCTION.md) for the full deploy process.

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
| Health check | `pg_isready` every 15s |

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

### Adding a new app route

Adding or modifying a route requires a PR to this repo. See [CADDY_GUIDE.md](guides/CADDY_GUIDE.md#adding-a-new-route) for the full procedure.

## Backup Script

Daily Postgres backups to AWS S3 via systemd timer. No local retention — S3 is the primary store.

| Property | Value |
|----------|-------|
| Path on VPS | `/home/deploy/infra/scripts/postgres_backup.sh` |
| Interface | `./scripts/postgres_backup.sh [db_name]` — dumps one DB, or all if no argument |
| Destination | `s3://victorpatrin-backups/postgres/` |
| Retention | 30 days (S3 lifecycle rule) |
| Schedule | Daily at 02:30 UTC |
| Container | Runs `pg_dump` inside `shared-postgres` via `docker exec` |

The script is no longer called by app deploy scripts — coupette handles its own pre-migration backups if needed.

## Observability

Prometheus scrapes app backends for application-level metrics. Apps must expose a `/metrics` endpoint on their internal port.

| App | Target | Metrics |
| --- | --- | --- |
| coupette-backend | `coupette-backend:8001/metrics` | `http_request_duration_seconds`, `http_requests_total`, `coupette_*` custom metrics |

If an app renames its container, changes its port, or changes metric names, the corresponding Prometheus scrape target and Grafana dashboard panels in this repo must be updated.

## Deploy Dependencies

Infra services must be healthy before app deploys can succeed:

1. `shared-postgres` must be healthy (app backends connect on startup)
2. `caddy` must be running (routes traffic to app containers)
3. `internal` network must exist (all containers attach to it)

If `make restart` is run on infra, app backends may lose postgres connectivity for ~10-30 seconds. App health checks should tolerate this.

## Working Directory

Coupette is deployed to `/opt/coupette` on the VPS. Systemd timer units use `WorkingDirectory=/opt/coupette`. The deploy script writes an `.image-tag` file there that timers read to pull the correct container image version.

## Timer Scheduling

Timers are sequenced to avoid conflicts and ensure pre-job backups:

```text
Daily (UTC):
  02:00  coupette-availability (stock refresh, ~5-18 min) [app-owned]
  02:30  pg-backup (daily dump of all databases → AWS S3)
  06:00  disk-alert (disk usage check, alerts if >85%)

Monday (UTC):
  03:00  coupette-scraper (scrape → enrich → embed, ~1-2 hours) [app-owned]
```

All timers use `Persistent=true` — if the VPS is down during the scheduled time, the job runs on next boot.

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

### Deploy process

See [ARCHITECTURE.md](ARCHITECTURE.md#deployment) for how infra deploys work. App repos trigger their own deploy workflows — infra guarantees the platform contract (network, postgres, Caddy routes) is intact before any app deploy runs.
