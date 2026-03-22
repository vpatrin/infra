# Architecture

Single Hetzner VPS running all services behind a Caddy reverse proxy. One server, one entry point, minimal moving parts.

## VPS

- **Provider**: Hetzner CX22
- **OS**: Debian 13
- **Host**: `web-01`
- **User**: `victor` (root SSH disabled)
- **Swap**: 2GB at `/swapfile`, swappiness=10
- **DNS**: `victorpatrin.dev` + wildcard `*.victorpatrin.dev` → VPS IP (Porkbun)

## Topology

```text
Internet
  │
  ▼
Caddy (ports 80/443)
  ├── victorpatrin.dev          → static files (/srv/homepage)
  ├── coupette.club             → static SPA + reverse proxy to coupette-backend:8001
  ├── analytics.victorpatrin.dev → reverse proxy to umami:3000
  └── status.victorpatrin.dev   → reverse proxy to uptime-kuma:3001

Observability (internal only):
  Alloy → collects logs + metrics → Loki (logs) + Prometheus (metrics) → Grafana (dashboards)

All services communicate over a shared Docker network ("internal").
Only Caddy binds to host ports 80/443 in the base compose.
Grafana binds to localhost:3002 in prod (for SSH tunnel access).
```

For full VPS setup instructions, see [guides/VPS_SETUP_GUIDE.md](guides/VPS_SETUP_GUIDE.md).

## Services

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

## Security

See [SECURITY.md](SECURITY.md) for the full platform security posture (firewall, TLS, headers, container hardening, SSH, secrets management).

## Observability

See [OBSERVABILITY.md](OBSERVABILITY.md) for the full observability stack (Grafana, Loki, Prometheus, Alloy — data flow, config, querying).

## Backups

Weekly automated backups via systemd timer.

### What's stateful

| Data | Location | Risk |
|------|----------|------|
| PostgreSQL (2 databases) | Docker volume `shared-postgres_pgdata` | **High** — user data, product catalog, analytics |
| Uptime Kuma | Docker volume `uptime-kuma_uptime-kuma-data` | Medium — monitoring config + history, reconfigurable |
| Grafana | Docker volume `grafana_data` | Low — dashboards should be provisioned as code |
| Prometheus | Docker volume `prometheus_data` | Low — metrics rebuilt from scrape targets (7d retention) |
| Loki | Docker volume `loki_data` | Low — logs rebuilt from Docker log tailing (7d retention) |
| Alloy | Docker volume `alloy_data` | Low — collector WAL, transient, rebuilt on restart |
| Caddy TLS certs | Docker volume `caddy_data` | Low — auto-renewed by ACME |
| Caddy config | Docker volume `caddy_config` | Low — regenerated from Caddyfile |

### What's stateless

Everything else. All service containers can be rebuilt from their repos. Static sites are in git. Observability data rebuilds from live sources.

### Strategy

- Weekly `pg_dump` per database (compressed), retained for 30 days
- systemd timer: Sunday 02:00 (day before Monday scraper)
- Pre-deploy dumps via `./scripts/postgres_backup.sh <db_name>` (called by deploy scripts)
- Storage: `/var/backups/postgres/` (~2MB per dump × 2 DBs × 4 weeks = ~16MB)

### Setup on VPS

Handled automatically by `deploy_infra.sh` — it syncs all units from `systemd/` to `/etc/systemd/system/`.

### Manual backup

```bash
./scripts/postgres_backup.sh                  # all databases
./scripts/postgres_backup.sh saq_sommelier    # single database
```

### Restore

Backups are gzipped SQL dumps in `/var/backups/postgres/`. To restore:

```bash
# List available backups
ls -lh /var/backups/postgres/

# Restore into an existing database (replays the dump — safe for additive restores)
gunzip -c /var/backups/postgres/saq_sommelier_YYYYMMDD.sql.gz | \
  docker exec -i shared-postgres psql -U postgres -d saq_sommelier

# Full rebuild (drop + recreate + restore)
docker exec shared-postgres psql -U postgres -c "DROP DATABASE saq_sommelier;"
docker exec shared-postgres psql -U postgres -c "CREATE DATABASE saq_sommelier OWNER saq_sommelier;"
gunzip -c /var/backups/postgres/saq_sommelier_YYYYMMDD.sql.gz | \
  docker exec -i shared-postgres psql -U postgres -d saq_sommelier

# Verify
docker exec shared-postgres psql -U postgres -d saq_sommelier -c "SELECT count(*) FROM product;"
```

After restoring an app database, re-run the app's migrations to ensure schema is current.

## PostgreSQL Extensions

See [APP_CONTRACT.md](APP_CONTRACT.md#required-extensions) for the full extensions table. If rebuilding postgres from scratch, `vector` is created automatically by the init script. `pg_trgm` is created by coupette's migrations — run `alembic upgrade head` after restore.

## Systemd Timers

See [APP_CONTRACT.md](APP_CONTRACT.md#timer-scheduling) for the full timer inventory and scheduling diagram.

```bash
# Check all timers
systemctl list-timers --all | grep -E "pg-backup|coupette"

# Check a specific timer
systemctl status pg-backup.timer
journalctl -u pg-backup.service --since "1 week ago"
```

## Logging

Docker container logs are stored at `/var/lib/docker/containers/<id>/<id>-json.log`. Each service has log rotation configured in its `docker-compose.yml` (10MB max per file, 3 files retained = 30MB cap per service).

Alloy auto-discovers all containers and ships their logs to Loki for centralized querying (7d retention). See [OBSERVABILITY.md](OBSERVABILITY.md) for LogQL examples and adding app logs.

- **Centralized**: Grafana → Explore → Loki (`{container="caddy"} |= "error"`)
- **Direct**: `make logs` or `docker logs caddy`
- **Raw access**: useful if Docker daemon or container is down

## Monitoring

| Tool | URL | Purpose |
|------|-----|---------|
| Grafana | `localhost:3002` (SSH tunnel) | Dashboards — logs, metrics, system overview |
| Prometheus | Internal only | Metrics storage (7d retention) |
| Loki | Internal only | Log aggregation (7d retention) |
| Alloy | Internal only | Log + metrics collector (Docker + node) |
| Uptime Kuma | `status.victorpatrin.dev` | Uptime monitoring, alerts on downtime |
| Umami | `analytics.victorpatrin.dev` | Privacy-friendly web analytics |

### HTTP monitors

Uptime Kuma polls services via HTTP and alerts on downtime via Telegram (`@victor_uptime_bot`).

### Disk usage alert

Daily systemd timer checks disk usage on `/`. If usage exceeds 85%, sends a Telegram alert via `@victor_uptime_bot`. Not routed through Uptime Kuma — the timer always runs and the disk is always queryable, so push/pull monitoring doesn't apply.

Credentials (`BOT_TOKEN`, `CHAT_ID`) stored in `/etc/push-monitor/disk-alert.env` (root-owned, `0600`).

### Push monitors (systemd timers)

Scheduled jobs (backups, scrapers) report success to Uptime Kuma push monitors. If a heartbeat doesn't arrive within the grace period, Uptime Kuma sends a Telegram alert.

| Job          | Monitor Type | Heartbeat | Grace |
|--------------|--------------|-----------|-------|
| `pg-backup`  | Push         | 7 days    | 1 day |

Push URLs are stored in `/etc/push-monitor/<job>.env` on the VPS (root-owned, `0600`). Systemd loads them via `EnvironmentFile` (mandatory — unit won't start without it), and `ExecStartPost=-` calls `scripts/push-monitor.sh` on success. See `pg-backup.service` for the reference implementation.

#### Adding a push monitor

1. Create the push monitor in Uptime Kuma (set heartbeat interval and grace period)
2. Store the push URL on the VPS:

   ```bash
   sudo mkdir -p /etc/push-monitor
   sudo tee /etc/push-monitor/<job>.env > /dev/null <<EOF
   PUSH_URL=<paste push URL from Uptime Kuma>
   EOF
   sudo chmod 600 /etc/push-monitor/<job>.env
   ```

3. Add `EnvironmentFile=/etc/push-monitor/<job>.env` and `ExecStartPost=-/.../scripts/push-monitor.sh ${PUSH_URL}` to the systemd service unit
4. Copy updated unit files and reload:

   ```bash
   sudo cp <service-file> <timer-file> /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl reenable <job>.timer
   ```
5. Test: `sudo systemctl start <job>.service` and verify heartbeat in Uptime Kuma

## Deployment

Infra deploys are triggered via GitHub Actions (manual workflow dispatch). The workflow runs `deploy_infra.sh` on the VPS as the `deploy` user, which: decrypts secrets (sops + age), pulls images, starts services, syncs systemd units, and runs health checks.

```bash
make deploy    # trigger via GitHub Actions (requires confirmation)
```

For Caddyfile-only changes (no container restart needed):

```bash
ssh web-01
cd ~/infra && git pull
make reload-caddy
```

Each project repo has its own deploy process. See [coupette PRODUCTION.md](https://github.com/vpatrin/coupette/blob/main/docs/PRODUCTION.md) for app-level deployment.

## Scalability

Single-VPS setup. Scaling options:

- **Vertical**: upgrade the Hetzner plan (more CPU/RAM/disk).
- **Horizontal**: not designed for it — would require splitting services across servers, adding a load balancer, and externalizing PostgreSQL. Not planned.
- **Current headroom**: ~10 containers (4 core + 4 observability + coupette). Memory budget is tight at 3.5GB reserved of 4GB.
