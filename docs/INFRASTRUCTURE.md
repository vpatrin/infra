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
  ├── coupette.club             → static SPA + reverse proxy to coupette-backend:8001
  ├── analytics.victorpatrin.dev → reverse proxy to umami:3000
  └── status.victorpatrin.dev   → reverse proxy to uptime-kuma:3001

Observability (internal only):
  Alloy → collects logs + metrics → Loki (logs) + Prometheus (metrics) → Grafana (dashboards)

All services communicate over a shared Docker network ("internal").
Only Caddy binds to host ports 80/443 in the base compose.
Grafana binds to localhost:3002 in prod (for SSH tunnel access).
```

See [SERVICE_CATALOG.md](SERVICE_CATALOG.md) for the full service inventory and port mapping.

For full VPS setup instructions, see [guides/VPS_SETUP.md](guides/VPS_SETUP.md).

## Security

See [SECURITY.md](SECURITY.md) for the full platform security posture (firewall, TLS, headers, container hardening, SSH, secrets management).

## Backups

Weekly automated backups via systemd timer ([#6](https://github.com/vpatrin/infra/issues/6)).

### What's stateful

| Data | Location | Risk |
|------|----------|------|
| PostgreSQL (2 databases) | Docker volume `shared-postgres_pgdata` | **High** — user data, product catalog, analytics |
| Uptime Kuma | Docker volume `uptime-kuma_uptime-kuma-data` | Medium — monitoring config + history, reconfigurable |
| Caddy TLS certs | Docker volume `caddy_data` | Low — auto-renewed by ACME |
| Caddy config | Docker volume `caddy_config` | Low — regenerated from Caddyfile |

### What's stateless

Everything else. All service containers can be rebuilt from their repos. Static sites are in git.

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

See [SERVICE_CATALOG.md](SERVICE_CATALOG.md#required-extensions) for the full extensions table. If rebuilding postgres from scratch, `vector` is created automatically by the init script. `pg_trgm` is created by coupette's migrations — run `alembic upgrade head` after restore.

## Systemd Timers

See [SERVICE_CATALOG.md](SERVICE_CATALOG.md#timer-scheduling) for the full timer inventory and scheduling diagram.

```bash
# Check all timers
systemctl list-timers --all | grep -E "pg-backup|coupette"

# Check a specific timer
systemctl status pg-backup.timer
journalctl -u pg-backup.service --since "1 week ago"
```

## Logging

Docker container logs are stored at `/var/lib/docker/containers/<id>/<id>-json.log`. Each service has log rotation configured in its `docker-compose.yml` (10MB max per file, 3 files retained = 30MB cap per service).

- **View logs**: `make logs` or `docker logs caddy`
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

This is a single-VPS setup. Scaling considerations if needed:

- **Vertical**: upgrade the Hetzner plan (more CPU/RAM/disk).
- **Horizontal**: not designed for it — would require splitting services across servers, adding a load balancer, and externalizing PostgreSQL. Not planned.
- **Current headroom**: the VPS runs ~10 containers (4 core + 4 observability + coupette). Memory budget is tight at 3.5GB reserved of 4GB — monitor after observability stack is live.
