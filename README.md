# infra

Production infrastructure for `victorpatrin.dev` — single VPS, single compose file, full observability. Everything from reverse proxy to dashboards, documented with ADRs.

**Stack:** Caddy · PostgreSQL + pgvector · Grafana · Loki · Prometheus · Alloy · Umami · Uptime Kuma

```text
Internet
  │
  ▼
Caddy (80/443, auto-TLS)
  ├── victorpatrin.dev            → static site
  ├── coupette.club               → SPA + API (coupette-backend:8001)
  ├── analytics.victorpatrin.dev  → umami:3000
  └── status.victorpatrin.dev     → uptime-kuma:3001

Observability (internal only):
  Alloy → Loki (logs) + Prometheus (metrics) → Grafana
```

App repos on the same VPS:

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
│   ├── ARCHITECTURE.md            # VPS, network, services, backups, deployment
│   ├── OBSERVABILITY.md           # Grafana, Loki, Prometheus, Alloy
│   ├── APP_CONTRACT.md            # Platform contract for app repos
│   ├── SECURITY.md                # Platform security posture + hardening log
│   ├── ROADMAP.md                 # Phased infrastructure plan
│   ├── decisions/                 # Architecture decision records
│   └── guides/                    # Reusable how-to guides
└── .github/
    ├── workflows/
    │   ├── ci.yml                 # PR checks: compose, shellcheck, gitleaks
    │   ├── deploy.yml             # Production deploy (workflow dispatch)
    │   └── dependabot-auto-merge.yml
    └── dependabot.yml             # Weekly Docker + Actions updates
```

## Docs

**State** — how things are right now (updated in place):

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — VPS, network, services, backups, deployment
- [OBSERVABILITY.md](docs/OBSERVABILITY.md) — Grafana, Loki, Prometheus, Alloy
- [APP_CONTRACT.md](docs/APP_CONTRACT.md) — platform contract for app repos
- [SECURITY.md](docs/SECURITY.md) — platform security posture + hardening log

**Journey** — what happened and what's next:

- [ROADMAP.md](docs/ROADMAP.md) — phased plan from current state through K3s migration

**Decisions** — why we chose X over Y:

- [decisions/](docs/decisions/) — architecture decision records

**Reference** — operational how-tos:

- [guides/](docs/guides/) — step-by-step setup and configuration guides
