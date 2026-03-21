# infra

Platform infrastructure for `victorpatrin.dev` — all service definitions, reverse proxy, database, backups, and static assets. Single VPS, single compose file.

## Services

| Service     | Image                                            | Port            | Domain                       |
| ----------- | ------------------------------------------------ | --------------- | ---------------------------- |
| Caddy       | `caddy:2.11.2`                                   | 80, 443         | all (reverse proxy)          |
| PostgreSQL  | `pgvector/pgvector:0.8.2-pg16`                   | 5432 (internal) | —                            |
| Umami       | `ghcr.io/umami-software/umami:postgresql-latest` | 3000            | `analytics.victorpatrin.dev` |
| Uptime Kuma | `louislam/uptime-kuma:2.2.1`                     | 3001            | `status.victorpatrin.dev`    |
| Loki        | `grafana/loki:3.5.12`                            | 3100            | —                            |
| Prometheus  | `prom/prometheus:v3.10.0`                        | 9090            | —                            |
| Alloy       | `grafana/alloy:v1.14.1`                          | 12345           | —                            |
| Grafana     | `grafana/grafana:12.4.1`                         | 3000            | —                            |

App repos (own code, CI, releases) on the same VPS:

- [coupette](https://github.com/vpatrin/coupette) — wine recommendations (`coupette.club`)

## Structure

```text
infra/
├── docker-compose.yml             # All service definitions
├── docker-compose.dev.yml         # Dev overrides (port bindings)
├── docker-compose.prod.yml        # Prod overrides (env_file, mem_limit, restart)
├── Makefile                       # Dev and ops commands
├── scripts/                       # Operational scripts (deploy, backup, alerts)
├── systemd/                       # systemd unit files (timers + services)
├── services/
│   ├── caddy/Caddyfile            # Reverse proxy routing + TLS
│   ├── homepage/                  # Static site for victorpatrin.dev
│   ├── postgres/
│   │   └── init-scripts/          # DB + user creation on first start
│   ├── umami/
│   ├── alloy/                     # Log + metrics collector config
│   ├── grafana/                   # Dashboards + provisioning
│   ├── loki/                      # Log aggregation config
│   └── prometheus/                # Metrics scrape config
├── docs/
│   ├── ROADMAP.md                 # Phased infrastructure plan
│   ├── INFRASTRUCTURE.md          # VPS architecture, security, backups
│   ├── SERVICE_CATALOG.md         # Service inventory + platform contract
│   ├── SECURITY.md                # Platform security posture
│   ├── OBSERVABILITY.md           # Grafana, Loki, Prometheus, Alloy
│   ├── decisions/                 # Architecture decision records
│   └── guides/                    # Reusable how-to guides
└── .github/
    ├── workflows/
    │   ├── ci.yml                 # PR checks: compose, shellcheck, gitleaks
    │   ├── deploy.yml             # Production deploy (workflow dispatch)
    │   └── dependabot-auto-merge.yml
    └── dependabot.yml             # Weekly Docker + Actions updates
```

## Deployment

Production deploys are triggered via GitHub Actions (`deploy.yml`). For manual operations:

```bash
make reload-caddy  # No-downtime Caddyfile reload
make deploy        # Trigger production deploy via GitHub Actions
```

## Docs

- [ROADMAP.md](docs/ROADMAP.md) — phased plan from current state through K3s migration
- [INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) — VPS, security, backups, monitoring, scaling
- [SERVICE_CATALOG.md](docs/SERVICE_CATALOG.md) — service inventory + platform contract
- [SECURITY.md](docs/SECURITY.md) — platform security posture
- [OBSERVABILITY.md](docs/OBSERVABILITY.md) — Grafana, Loki, Prometheus, Alloy
- [decisions/](docs/decisions/) — architecture decision records
- [guides/](docs/guides/) — reusable how-to guides
