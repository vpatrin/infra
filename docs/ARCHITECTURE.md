# Architecture

Single Hetzner VPS running all services behind a Caddy reverse proxy. One server, one entry point, minimal moving parts.

## VPS

- **Provider**: Hetzner CX22
- **OS**: Debian 13
- **Host**: `web-01`
- **Users**: `admin` (SSH, sudo) + `deploy` (CD, scoped sudo) — root SSH disabled
- **Swap**: 2GB at `/swapfile`, swappiness=10
- **DNS**: `victorpatrin.dev` + `coupette.club` → VPS IP (Hetzner DNS, managed by Terraform). `ccil.club` → VPS IP (Porkbun DNS). Porkbun remains the domain registrar for all domains.

## Topology

```text
Internet
  │
  ▼
Caddy (ports 80/443)
  ├── victorpatrin.dev          → static files (/srv/homepage)
  ├── coupette.club             → static SPA + reverse proxy to coupette-backend:8001
  ├── ccil.club                  → reverse proxy to ccil:3000
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
| CCIL | ccil | 3000 | — | `ccil.club`, `ccil.victorpatrin.dev` | ccil |
| Coupette backend | coupette-backend | 8001 | — | `coupette.club/api` | coupette |
| Coupette bot | coupette-bot | — | — | — | coupette |
| Coupette scraper | coupette-scraper | — | — | — (systemd timer) | coupette |
| Coupette frontend | — | — | — | `coupette.club` (static, served by Caddy) | coupette |

Dev bindings are defined in per-stack `docker-compose.dev.yml` files (loaded via `make up`). Only Caddy has host port bindings in the base compose. Production adds a localhost binding for SSH tunnel access to Grafana (`stacks/observability/docker-compose.prod.yml`).

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

Daily automated backups to AWS S3 via systemd timer. No local retention — S3 is the primary store.

### What's stateful

See [SECURITY.md](SECURITY.md#volume-security) for the full volume inventory and risk assessment. Only PostgreSQL is high-risk — everything else is recoverable (auto-renewed certs, rebuildable metrics/logs, reconfigurable monitoring).

### Strategy

- Daily `pg_dump` per database (compressed) → AWS S3 (`s3://victorpatrin-backups/postgres/`)
- 30-day retention via S3 lifecycle rule
- systemd timer: daily at 02:30 UTC
- Fails loudly on upload failure (exit non-zero → Uptime Kuma alert)

### S3 structure

```text
s3://victorpatrin-backups/postgres/
  saq_sommelier/YYYYMMDD.sql.gz
  umami/YYYYMMDD.sql.gz
```

### Setup on VPS

Handled automatically by `deploy_infra.sh` — it syncs all units from `systemd/` to `/etc/systemd/system/`.

AWS credentials for the `infra-backup` IAM user are in `secrets/aws-infra-backup.env` (decrypted from `.env.enc` by `deploy_infra.sh`). Contains `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`, and `S3_BUCKET`.

### Manual backup

```bash
./scripts/postgres_backup.sh                  # all databases
./scripts/postgres_backup.sh saq_sommelier    # single database
```

### Restore

Download the dump from S3, then restore:

```bash
# List available backups
aws s3 ls s3://victorpatrin-backups/postgres/saq_sommelier/

# Download a specific dump
aws s3 cp s3://victorpatrin-backups/postgres/saq_sommelier/YYYYMMDD.sql.gz /tmp/

# Restore into an existing database
gunzip -c /tmp/YYYYMMDD.sql.gz | \
  docker exec -i shared-postgres psql -U postgres -d saq_sommelier

# Full rebuild (drop + recreate + restore)
docker exec shared-postgres psql -U postgres -c "DROP DATABASE saq_sommelier;"
docker exec shared-postgres psql -U postgres -c "CREATE DATABASE saq_sommelier OWNER saq_sommelier;"
gunzip -c /tmp/YYYYMMDD.sql.gz | \
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

Docker container logs are stored at `/var/lib/docker/containers/<id>/<id>-json.log`. Each service has log rotation configured in its stack's `docker-compose.yml` (10MB max per file, 3 files retained = 30MB cap per service).

Alloy auto-discovers all containers and ships their logs to Loki for centralized querying (7d retention). See [OBSERVABILITY.md](OBSERVABILITY.md) for LogQL examples and adding app logs.

- **Centralized**: Grafana → Explore → Loki (`{container="caddy"} |= "error"`)
- **Direct**: `make logs` or `docker logs caddy`
- **Raw access**: useful if Docker daemon or container is down

## Monitoring

Uptime Kuma polls services via HTTP and alerts on downtime via Telegram (`@victor_uptime_bot`). Grafana dashboards accessible via `localhost:3002` (SSH tunnel) — see [OBSERVABILITY.md](OBSERVABILITY.md).

### Disk usage alert

Daily systemd timer checks disk usage on `/`. If usage exceeds 85%, sends a Telegram alert via `@victor_uptime_bot`. Not routed through Uptime Kuma — the timer always runs and the disk is always queryable, so push/pull monitoring doesn't apply.

Credentials (`BOT_TOKEN`, `CHAT_ID`) stored in `secrets/telegram-alerts-bot.env.enc` (sops-encrypted), decrypted to `secrets/telegram-alerts-bot.env` by `deploy_infra.sh`.

### Push monitors (systemd timers)

Scheduled jobs (backups, scrapers) report success to Uptime Kuma push monitors. If a heartbeat doesn't arrive within the grace period, Uptime Kuma sends a Telegram alert.

| Job          | Monitor Type | Heartbeat | Grace   |
|--------------|--------------|-----------|---------|
| `pg-backup`  | Push         | 1 day     | 6 hours |

Push URLs are stored in `secrets/<monitor>.env.enc` (sops-encrypted), decrypted to `secrets/<monitor>.env` by `deploy_infra.sh`. Systemd loads them via `EnvironmentFile`, and `ExecStartPost=-` calls `scripts/push-monitor.sh` on success. See `pg-backup.service` for the reference implementation.

#### Adding a push monitor

1. Create the push monitor in Uptime Kuma (set heartbeat interval and grace period)
2. Create `secrets/<monitor>.env` with the push URL, encrypt with sops:

   ```bash
   echo "PUSH_URL=<paste push URL>" > secrets/<monitor>.env
   sops --encrypt --input-type dotenv --output-type json secrets/<monitor>.env > secrets/<monitor>.env.enc
   rm secrets/<monitor>.env
   ```

3. Add the secret name to `ENCRYPTED_SECRETS` in `scripts/deploy_infra.sh`
4. Add `EnvironmentFile=/etc/infra/<monitor>.env` and `ExecStartPost=-/.../scripts/push-monitor.sh ${PUSH_URL}` to the systemd service unit
5. Deploy and test: `sudo systemctl start <job>.service`, verify heartbeat in Uptime Kuma

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
