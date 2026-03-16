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
│   └── umami/
│       └── .env.example
├── docs/
│   ├── INFRASTRUCTURE.md          # VPS architecture, security, backups
│   ├── PORT_ALLOCATION.md         # Service-to-port mapping
│   ├── RFC-repo-reorg.md          # Repo consolidation decision record
│   └── GITHUB-SETUP.md            # GitHub repo hardening guide
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

- [INFRASTRUCTURE.md](docs/INFRASTRUCTURE.md) — VPS, security, backups, monitoring, scaling
- [PORT_ALLOCATION.md](docs/PORT_ALLOCATION.md) — service/port/container mapping
- [RFC-repo-reorg.md](docs/RFC-repo-reorg.md) — repo consolidation decision record
- [GITHUB-SETUP.md](docs/GITHUB-SETUP.md) — GitHub repo hardening guide (generic)
