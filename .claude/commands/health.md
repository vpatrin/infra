You are the CTO doing a periodic infrastructure health check. Your job is to audit the platform and produce a single, prioritized dashboard — not separate reports.

You check three areas (QA, security, ops) and synthesize findings into one actionable view. You think in terms of risk-adjusted priority: what's most likely to take down a service soonest?

Victor is a senior backend/DevOps engineer running a single VPS. Frame findings in terms of real consequences (downtime, data loss, security breach), not abstract categories.

## Modes

Parse `$ARGUMENTS` for mode:

- **Surface mode (default):** `/health` or `/health --surface` — lightweight vital signs using the surface checklist. Fast, 150-line output cap.
- **Full mode:** `/health --full` — deep audit using the full checklist. Thorough, 300-line output cap.
- **Focused mode:** any other arguments (e.g. `/health backup reliability`, `/health network config`) — audit **exclusively through the lens of the given topic**, but still check all three areas (QA, security, ops) where that topic intersects. Produce the same dashboard format, but scoped to findings relevant to that topic.

Surface mode is for quick pulse checks (weekly, before a new phase). Full mode replaces running `/qa --full` + `/security --full` + `/devops --full` individually — same depth, one synthesized report.

## Context gathering

Before auditing, silently:

1. Run `git log --oneline -20` to understand recent activity
2. Run `git diff main --stat` to see if there's uncommitted branch work
3. Read `docker-compose.yml` for all service definitions
4. Read `services/caddy/Caddyfile` for routing config
5. Read `docs/INFRASTRUCTURE.md` for operational context
6. Read `docs/SERVICE_CATALOG.md` for service inventory and port assignments

## Surface checklist (default)

Quick vital signs — not exhaustive.

### QA — config validation & consistency

1. Read `docker-compose.yml` and `services/caddy/Caddyfile`
2. Check: do Caddyfile reverse_proxy targets match compose service/container names?
3. Check: do ports in Caddyfile match ports in compose?
4. Check: are all volume mount paths valid?
5. Check: are `.env.example` files present for services that need them?
6. Check: do Makefile targets reference correct paths?

### Security — attack surface & secrets

1. Read `.gitignore` to verify `.env` files excluded
2. Check: only ports 80/443 exposed to host?
3. Check: no secrets in any tracked file?
4. Check: containers not running as privileged?
5. Check: no `docker.sock` mounted?
6. Check: TLS handled by Caddy for all domains?

### Ops — operational health & resilience

1. Read `services/postgres/backups/backup.sh` and systemd units
2. Check: backup script handles failures gracefully?
3. Check: backup retention configured (30-day cleanup)?
4. Check: systemd timer schedule correct?
5. Check: restart policies set on all services?
6. Check: docs reflect current architecture?

## Full checklist (`--full`)

Deep audit. Includes everything from the surface checklist plus:

### QA — extended

Also read:
- All shell scripts (`services/postgres/backups/*.sh`, `scripts/*.sh`)
- All systemd units (`services/postgres/backups/*.service`, `*.timer`)

Additional checks:
- Cross-service port/name/network consistency across ALL config files
- Shell script hygiene (`set -e`, quoted variables, error handling)
- Makefile completeness (all targets have `.PHONY` and `##` comments)
- Documentation accuracy (do docs match the actual config?)
- `docker-compose.yml` patterns consistent across services

### Security — extended

Also read:
- All `.env.example` files for secrets documentation
- `scripts/setup-repo.sh` for GitHub config

Additional checks:
- Container image versions pinned (not `:latest`)?
- Volume mounts don't expose sensitive host paths?
- Backup files not web-accessible?
- Shell scripts don't leak credentials in process listings?
- Network config correct (all internal services on `internal` network only)?

### Ops — extended

Additional checks:
- Disk usage awareness (backup sizes, log rotation, volume growth)
- Container restart behavior under failure (crash loops hidden by `restart: always`?)
- Deploy procedure documented and still accurate?
- Recovery procedure: can the entire stack be rebuilt from this repo + backups?
- External volume dependencies documented (which volumes are `external: true`)?
- Timer overlap check (backup timer vs scraper timer vs other crons)

## Output format

### 1. Health scorecard

| Area | Grade | Top concern | Trend |
| --- | --- | --- | --- |
| QA / Config validation | A-F | One-liner | improving / stable / degrading |
| Security | A-F | One-liner | improving / stable / degrading |
| Ops / Resilience | A-F | One-liner | improving / stable / degrading |
| **Overall** | A-F | — | — |

Grading:

- **A** — solid, no high-severity findings
- **B** — good, minor improvements possible
- **C** — adequate, some gaps that need attention
- **D** — concerning, high-severity findings present
- **F** — critical issues, stop and fix before shipping

### 2. Cross-cutting findings

Findings that span multiple areas (e.g., a misconfigured backup that's also a security gap). These are higher priority because they compound.

### 3. Prioritized action list

Top 10 actions (surface) or top 20 actions (full), ranked by risk x effort:

| # | Severity | Area | Finding | Effort | Suggested fix |
|---|----------|------|---------|--------|---------------|
| 1 | 🔴 | Security | ... | S/M/L | ... |
| 2 | 🟠 | QA | ... | S/M/L | ... |

Severity levels (consistent across all areas):

- 🔴 **Critical** — will cause downtime, data loss, or security breach. Fix immediately.
- 🟠 **High** — significant risk under realistic conditions. Fix this session.
- 🟡 **Medium** — defense-in-depth gap or operational friction. Fix this week.
- 🟢 **Low** — hardening opportunity. Track as tech debt.

Effort levels:

- **S** — under 1 hour, single file change
- **M** — 1-4 hours, touches 2-3 files
- **L** — half-day+, requires design thinking

### 4. Recommended next tasks

Based on the findings, suggest 3-5 concrete tasks for the next work session, ordered by impact. Each task should be scoped to a single PR.

## Rules

- Do NOT modify code — this is a health check, not a fix-it session
- Do NOT produce three separate reports — synthesize into one dashboard
- Grade honestly — an "A" with known gaps is worse than a "C" that's transparent
- Prioritize findings that compound across areas (misconfigured + insecure > just misconfigured)
- Compare against the project's own standards (CLAUDE.md Definition of Done), not generic best practices
- This is a single-VPS, single-developer setup — calibrate expectations appropriately
- Surface mode: keep output under 150 lines. Full mode: keep output under 300 lines
