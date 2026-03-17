# infra

Platform infrastructure for `victorpatrin.dev` — all service definitions, reverse proxy, database, backups, and static assets. Single VPS, single compose file.

## Services

| Service      | Image                        | Port             | Domain                       |
| ------------ | ---------------------------- | ---------------- | ---------------------------- |
| Caddy        | caddy:2.9                    | 80, 443          | all (reverse proxy)          |
| PostgreSQL   | pgvector/pgvector:pg16       | 5432 (localhost) | —                            |
| Umami        | ghcr.io/umami-software/umami | 3000             | `analytics.victorpatrin.dev` |
| Uptime Kuma  | louislam/uptime-kuma:1       | 3001             | `status.victorpatrin.dev`    |

App repos (own code, CI, releases) on the same VPS:

- [coupette](https://github.com/vpatrin/coupette) — wine recommendations (`coupette.club`)

## Structure

```text
infra/
├── docker-compose.yml             # All service definitions
├── Makefile                       # Dev and ops commands
├── services/
│   ├── caddy/Caddyfile            # Reverse proxy routing + TLS
│   ├── homepage/                  # Static site for victorpatrin.dev
│   ├── postgres/
│   │   ├── init-scripts/          # DB + user creation on first start
│   │   ├── backups/               # pg_dump scripts + systemd units
│   │   └── .env.example
│   ├── umami/
│   │   └── .env.example
│   └── uptime-kuma/               # Zero-config, data in Docker volume
├── docs/
│   ├── ROADMAP.md                 # Phased infrastructure plan
│   ├── INFRASTRUCTURE.md          # VPS architecture, security, backups
│   ├── SERVICE_CATALOG.md         # Service inventory + platform contract
│   ├── SECURITY.md                # Platform security posture
│   ├── decisions/                 # Architecture decision records
│   │   ├── 0001-hetzner-single-vps.md
│   │   ├── 0002-caddy-reverse-proxy.md
│   │   ├── 0003-shared-postgres.md
│   │   ├── 0004-docker-compose-orchestration.md
│   │   ├── 0005-systemd-timers.md
│   │   └── 0006-consolidate-repos.md
│   └── guides/                    # Reusable how-to guides
│       ├── COMPOSE_GUIDE.md
│       ├── DOCKERFILE_GUIDE.md
│       ├── GITHUB_SETUP.md
│       └── VPS_SETUP.md
└── .github/
    ├── workflows/ci.yml           # PR checks: compose, shellcheck, gitleaks
    └── dependabot.yml             # Weekly Docker + Actions updates
```

## Deployment

```bash
ssh web-01
cd ~/infra
git pull
docker compose up -d
```

For Caddyfile-only changes (no downtime):

```bash
make reload
```

## Docs

- [ROADMAP.md](docs/ROADMAP.md) — phased plan from current state through K3s migration
- [INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) — VPS, security, backups, monitoring, scaling
- [SERVICE_CATALOG.md](docs/SERVICE_CATALOG.md) — service inventory + platform contract
- [SECURITY.md](docs/SECURITY.md) — platform security posture
- [decisions/](docs/decisions/) — architecture decision records
- [guides/COMPOSE_GUIDE.md](docs/guides/COMPOSE_GUIDE.md) — Docker Compose patterns for apps on this platform
- [guides/DOCKERFILE_GUIDE.md](docs/guides/DOCKERFILE_GUIDE.md) — Dockerfile patterns (multi-stage builds, hardening)
- [guides/](docs/guides/) — reusable how-to guides (future blog material)
