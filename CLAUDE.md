# Infra — Project Context

## Hard Rules

- **No secrets in the repo.** No API keys, tokens, passwords, or credentials — ever. `.env` files are gitignored. If a value is sensitive, it goes in `.env` on the VPS or in `ansible-vault`.
- **Backwards compatibility.** Every change must be compatible with running services. A bad merge here takes down everything.
- **Git discipline:**
  - NEVER commit — Victor handles all commits
  - NEVER push — Victor handles all pushes
  - NEVER merge — Victor handles all merges
  - NEVER mention Claude in PRs, issues, commits, or any git artifact — no attribution lines, nothing
- **No prod commands.** Do not run deployment, reload, restart, or any VPS-touching command without Victor's explicit instruction.
- **Measure twice, cut once.** This is infrastructure glue — changes are rare and high-impact. Show the plan, wait for confirmation.

## Project Goals

Platform infrastructure for `victorpatrin.dev` — all service definitions, reverse proxy, database, backups, and static assets.
Public repo — no secrets, no credentials.

## Stack

- Reverse proxy: Caddy 2 (Docker)
- Database: PostgreSQL 16 + pgvector (shared instance, 2 databases: saq_sommelier, umami)
- Analytics: Umami (self-hosted, privacy-friendly)
- Monitoring: Uptime Kuma (status page + alerting)
- VPS: Hetzner CX22 (4GB RAM, 40GB SSD, Debian 13)
- DNS: `victorpatrin.dev` + wildcard `*` → VPS IP (Porkbun)
- Network: `internal` Docker network (external, shared across all compose stacks)

## Architecture

```
Caddy (ports 80/443)
├── victorpatrin.dev           → static homepage (/srv/homepage)
├── analytics.victorpatrin.dev → umami:3000
├── status.victorpatrin.dev    → uptime-kuma:3001
└── coupette.club              → coupette-backend:8001 (/api/*) + static SPA (/srv/coupette)
```

App repos on the same VPS (own code, CI, releases — not managed here):

- `coupette` — wine recommendation app (backend, bot, scraper)

## Project Structure

```
infra/
├── CLAUDE.md
├── docker-compose.yml             # All service definitions
├── Makefile                       # Dev and ops commands
├── README.md
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
│   ├── PORT_ALLOCATION.md         # Port assignments across services
│   ├── INFRASTRUCTURE.md          # Server setup, backups, logging
│   └── RFC-repo-reorg.md          # Repo consolidation plan
├── .claude/
│   ├── COMMANDS.md                # Virtual team overview
│   └── commands/                  # Slash command definitions
└── (host: /srv/coupette)          # Static SPA served for coupette.club
```

## Definition of Done

Before any change ships:

- [ ] No secrets or credentials exposed in diff
- [ ] Caddyfile syntax valid (`docker exec caddy caddy validate --config /etc/caddy/Caddyfile`)
- [ ] `docker-compose.yml` syntax correct (`docker compose config --quiet`)
- [ ] Shell scripts have `set -e`, quoted variables, clear echo messages
- [ ] Makefile targets have `.PHONY` declarations and `##` help comments
- [ ] Existing services not affected (volume mounts, network names, container names unchanged unless intentional)
- [ ] Relevant docs updated if architecture changed
- [ ] No unused code, empty files, or unrelated changes

## Working Style

- When I ask technical questions, answer as a senior CTO — be honest, opinionated, and flag trade-offs
- Show the plan before executing
- One step at a time, wait for confirmation
- Prefer simple over clever — this is a solo-dev VPS, not a multi-team platform
- Never delete anything without explicit confirmation

## Deployment

I handle all deployments manually. Do not run any deployment commands on prod without my explicit instruction.

```bash
ssh web-01
cd ~/infra
git pull
make reload    # No-downtime Caddyfile reload
# OR
make restart   # Full container restart (if docker-compose.yml changed)
```

## Git

- One branch per change (type/short-description)
- Conventional commits, small and focused

### Workflow

Issue → Branch → PR → Squash Merge

Branch types: feat/, fix/, chore/, docs/
Commit types: feat, fix, chore, docs, refactor

## Pre-PR Checklist

Before creating a PR, always:

1. Review the diff as a senior engineer — run through the Definition of Done
2. Create the PR with conventional commit title

## Code Style

### Caddyfile
- Follow Caddy conventions, one directive per line
- Group by domain block, consistent indentation
- Comments for non-obvious routing decisions

### Shell scripts
- `set -e` at the top — fail fast
- Quote all variables: `"${VAR}"` not `$VAR`
- Clear `echo` messages for each step
- Use `#!/usr/bin/env bash` shebang
- No bashisms if `#!/bin/sh` — stick to POSIX

### docker-compose.yml
- Follow existing service patterns (image, ports, volumes, networks, restart policy)
- Service names match container names
- Volumes declared explicitly (named or bind mounts)
- Environment via `env_file`, never inline secrets

### Makefile
- `.PHONY` declarations for all targets
- `##` comments for the `help` target
- Targets are short — delegate to scripts for complex logic

### General
- Comments in English
- No file-level docstrings or boilerplate headers
- Only comment what isn't self-evident

## Contract with App Repos

App repos (e.g. coupette) depend on infrastructure this repo provides:

- An `internal` Docker network exists (external, shared across compose stacks). App repos attach to it for Caddy routing.
- A `shared-postgres` container is running and reachable on the `internal` network.
- Caddy routes are defined in `services/caddy/Caddyfile`. Adding a new app route requires a PR here.

If any of these change, app deploy scripts must be updated in the same logical change.

## Developer Context

Senior engineer (6 years — FastAPI, GCP, Kubernetes, Docker) rebuilding after a career break.
Treat this as pair programming, not task execution.
