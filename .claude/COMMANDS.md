# Slash Commands — Your Virtual Team

Custom slash commands that act as specialized teammates. Each one has a clear role, specific behaviors, and concrete constraints — that's what drives output quality, not buzzwords.

---

## Adapting to a new developer

The commands and `CLAUDE.md` reference the current developer's context (senior backend/DevOps engineer, solo VPS operator). If you're joining the project or forking it, update `CLAUDE.md` → **Developer Context** and **Working Style** sections to reflect your own profile.

Key questions to answer in your `CLAUDE.md`:

- **What's your background?** (e.g., "5 years of AWS, new to Hetzner/bare-metal")
- **What's new to you?** (e.g., "first time with Caddy" or "experienced K8s, new to Ansible")
- **What should be explained vs skipped?** (e.g., "explain Caddy directives, skip Docker basics")
- **How do you prefer to work?** (e.g., "show the plan first" vs "just do it", verbose vs terse)

---

## The Team

### Analysis commands

| Command | Role | Takes args? | `--full`? | When to use |
|---|---|---|---|---|
| `/plan` | Senior PM | Yes | No | Before starting a phase or epic |
| `/review` | Tech Lead / CTO | Optional | Yes | Before creating a PR |
| `/qa` | QA Engineer | Optional | Yes | Before merge — validate configs and find gaps |
| `/security` | Infra Security Engineer | Optional | Yes | Before merge — security audit |
| `/devops` | DevOps / Platform Engineer | Yes | Yes | Infrastructure design, IaC review, operational questions |
| `/roadmap-status` | Program Manager | No | No | Check project health and decide what's next |
| `/health` | CTO | Optional | Yes | Periodic infrastructure health dashboard |
| `/prompt` | Senior Prompt Engineer | Optional | Yes | Audit or draft slash commands |

### Built-in commands (Claude Code)

These are built-in Claude Code skills, not custom `.md` files. Listed here for reference so the full toolkit is in one place.

| Command | What it does | When to use |
|---|---|---|
| `/simplify` | Reviews changed code for reuse, quality, and efficiency — then fixes | After `/review`, as a cleanup pass |

### Action commands

| Command | Role | Takes args? | When to use |
|---|---|---|---|
| `/pr` | — (execution) | No | Create a PR (after `/review` passes) |

---

## Full repo mode

Commands marked with `--full` support a repo-wide audit mode:

```
/review --full      # Code quality audit across the entire repo
/qa --full          # Config validation health check across all services
/security --full    # Security posture review of the entire infrastructure
/devops --full      # Infrastructure architecture review
/health --full      # Deep audit — all areas combined
/prompt --full      # Audit all slash commands for prompt quality
```

Default (no flag) reviews only the current branch diff vs main.

---

## Usage

### `/plan <phase or feature description>`

**Role:** Senior PM who sequences work, identifies risks, and makes shipping decisions.

```
/plan absorb shared-postgres into infra
/plan set up Terraform for Hetzner provisioning
```

**Output:** Scope assessment, dependency graph, issue breakdown with acceptance criteria, shipping strategy, open questions. Creates GitHub issues after approval.

---

### `/review`

**Role:** Tech Lead reviewing your branch before it ships. Honest, opinionated, educational.

```
/review
/review --full
/review Caddyfile routing logic
```

**Output:** Code review with findings categorized as 🔴 Must fix, 🟡 Should fix, 🟢 Nit. Includes infra smell check (over-engineered configs, dead directives, unnecessary indirection). Clear verdict: ready to push or not.

---

### `/qa [scope]`

**Role:** QA Engineer who validates configs and finds what breaks — not confirms it works.

```
/qa
/qa --full
```

**Output:** Validation matrix (Caddyfile, compose, shell scripts, systemd units), service health scenarios, verdict (ship it / needs fixes).

---

### `/security [scope]`

**Role:** Infra Security Engineer who audits against the actual attack surface.

```
/security
/security --full
/security container isolation
```

**Output:** Findings with exploit scenarios and fixes, categorized 🔴 Critical / 🟠 High / 🟡 Medium / 🟢 Low. Verdict (clear / fix before merge / needs design review).

---

### `/devops <topic or question>`

**Role:** DevOps / Platform Engineer who designs infrastructure and reviews IaC.

```
/devops should I use external volumes for postgres?
/devops review the systemd backup timer
/devops --full
```

**Output:** Architecture assessment, trade-off analysis, concrete recommendations with rationale. For `--full` mode: full infrastructure architecture review.

---

### `/health`

**Role:** CTO running a periodic infrastructure health check.

```
/health              # surface scan — quick vital signs (default)
/health --full       # deep audit — thorough review of all areas
```

**Output:** Health scorecard (A-F grades for QA, security, ops), cross-cutting findings, prioritized action list with effort estimates, recommended next tasks.

**When to use:** Surface weekly or before a new phase. Full monthly or when you want a consolidated deep dive.

---

### `/roadmap-status`

**Role:** Program Manager keeping the project on track.

```
/roadmap-status
```

**Output:** Phase-by-phase assessment against the RFC, inconsistencies between RFC and issues, recommended next 3-5 tasks, stale branch cleanup.

---

### `/prompt [command name or description]`

**Role:** Senior Prompt Engineer who audits and drafts slash commands.

```
/prompt --full                              # audit all commands
/prompt review                              # deep audit of /review
/prompt command for Ansible playbook review # draft a new command
/prompt system prompt for deploy notifs     # craft a prompt (general)
/prompt query for gitops best practices     # prompt engineering advice
```

**Output:** For audits: scorecard per command with specific improvements. For drafting: full `.md` file following established patterns. For general queries: opinionated prompt engineering advice with concrete examples.

---

### `/pr`

**Role:** None (execution). Creates a PR after `/review` has passed.

```
/pr
```

**Output:** PR created on GitHub with conventional commit title, template body. Returns PR URL.

**Prerequisite:** `/review` must pass first. Branch must be pushed to remote.

---

## Typical Workflows

**Starting a new phase:**

```
/plan absorb shared-postgres   → sequenced issues with dependencies
  ... implement ...
/review                        → code quality + config validation
/simplify                      → cleanup pass
/qa                            → config health + service scenarios
/security                      → security audit on final shape
/pr                            → ship it
```

**Periodic health check:**

```
/health                        → consolidated dashboard
```

Or individual deep dives:

```
/qa --full                     → config validation across all services
/security --full               → security posture review
/devops --full                 → infrastructure architecture review
```

**Infrastructure design question:**

```
/devops should I use K3s or stay with compose?
/devops review my Terraform module structure
```

**Shipping progress check:**

```
/roadmap-status                → what's done, what's next, what's stale
```
