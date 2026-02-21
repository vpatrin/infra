# Infra - Project Context

## Project Goals

Central infrastructure for victorpatrin.dev — Caddy reverse proxy, homepage, and static assets.
Private repo. All routing, TLS, and service discovery lives here.

## Stack

- Reverse proxy: Caddy 2 (Docker)
- Homepage: Raw HTML + JS (no framework, no build step)
- Data layer: `content.js` (JS object) + `ICONS` object for inline SVGs
- Analytics: Umami (self-hosted)
- Infra: Hetzner CX22, Debian 13, Docker Compose

## Architecture

- Caddy is the single public entry point (ports 80/443)
- All services on `internal` Docker network, reached by container name
- Homepage served as static files from `/srv/homepage`
- Each subdomain routes to a different service (see Caddyfile)
- Port allocation documented in `docs/PORT_ALLOCATION.md`

## Project Structure

```
infra/
├── CLAUDE.md
├── Caddyfile              # Reverse proxy routing rules
├── docker-compose.yml     # Caddy container
├── Makefile               # Dev and ops commands
├── docs/
│   └── PORT_ALLOCATION.md
└── homepage/
    ├── index.html         # Single-page resume (embedded CSS + JS)
    └── content.js         # Data layer (ICONS + content objects)
```

## Infrastructure Context

- VPS: Hetzner CX22 (4GB RAM, 40GB SSD, Debian 13)
- Existing services sharing the VPS: Umami, Uptime Kuma, URL shortener, SAQ Sommelier
- Docker networks: `internal` (shared across all compose stacks)
- Caddy handles TLS automatically via Let's Encrypt

## Development Philosophy

- Keep it simple — raw HTML, no build tools, no frameworks
- One feature = one branch = one PR
- Small, focused changes
- Each commit should be deployable

## Working Style

- When I ask technical questions, answer as a senior CTO — be honest, opinionated, and flag trade-offs
- Show the plan before executing
- One step at a time, wait for confirmation
- Prefer simple over clever
- Never delete anything without explicit confirmation

## Git

- One branch per feature (type/short-description)
- Conventional commits, small and focused
- NEVER commit — Victor handles all commits
- NEVER push — Victor handles all pushes
- NEVER merge — Victor handles all merges

### Workflow Convention

Issue → Branch → PR → Squash Merge

1. Branch: `type/short-description` (feat/, fix/, chore/, docs/)
2. Victor commits and pushes
3. Claude creates PR with conventional commit title
4. Victor reviews and squash merges

Commit types: feat, fix, chore, docs, refactor

### GitHub Labels

Every issue should have at least one type label.

Service (where):
`homepage` · `caddy` · `devops`

Type (what):
`bug` · `feature` · `chore` · `refactor` · `docs` · `dependencies`

## Pre-PR Checklist

Before creating a PR, always:

1. Review the diff as a senior engineer
2. Check for broken links, missing data, CSS issues
3. Verify no secrets or sensitive paths are exposed
4. Create the PR with conventional commit title

## Code Style

- HTML/CSS/JS: consistent with existing homepage patterns
- Inline SVGs for icons (no external icon libraries)
- CSS variables for theming (--bg, --fg, --accent, --muted, --border)
- JetBrains Mono font, dark theme, orange accent (#ff5722)
- `content.js` as data layer — rendering logic in `index.html`

## Developer Context

Senior engineer (6 years — FastAPI, GCP, Kubernetes, Docker) rebuilding after a career break.
Treat this as pair programming, not task execution.
The homepage is a portfolio piece — it should be explainable and defensible in interviews.
