# ADR 0006: Consolidate Infrastructure Repos

**Date:** 2026-03-16
**Status:** Accepted

---

## Executive Summary

We currently maintain **7 Git repositories** to run 5 services on a single VPS. Four of those repos contain nothing but a `docker-compose.yml`, a `Makefile`, and a `README`. As we adopt IaC (Terraform, Ansible) and eventually migrate to K3s with GitOps, this fragmentation becomes a liability — every new capability touches multiple repos for a single logical change, and the repo sprawl undermines the infrastructure narrative we want to present.

This proposal consolidates the estate into **4 app repos + 1 platform repo** organized by change cadence and ownership boundary, with a clear migration path toward Kubernetes and GitOps.

---

## Problem Statement

### Current state

```
vpatrin/
├── infra/              # Caddy reverse proxy + homepage (1 container)
├── shared-postgres/    # PostgreSQL compose + init scripts
├── umami/              # docker-compose.yml + README (3 files)
├── uptime-kuma/        # docker-compose.yml + README (3 files)
├── url-shortener/      # Custom Python app
├── ssh-resume/         # Custom Go app
└── coupette/           # Main product — FastAPI + bot + scraper + React
```

**7 repos. 1 developer. 1 server.**

### What's wrong

| Problem | Impact |
|---|---|
| **Repo sprawl** | 4 repos (shared-postgres, umami, uptime-kuma, infra) exist solely to hold a compose file and a README. They carry the overhead of a real repo (PRs, CI config, branch protection) without the complexity to justify it. |
| **Cross-repo changes** | Adding a new service today requires touching 3 repos minimum: the service repo (compose), infra (Caddyfile routing), and shared-postgres (if it needs a DB). That's 3 PRs for one logical operation. |
| **No home for IaC** | Terraform (provisioning) and Ansible (configuration) have no natural place. Creating yet another repo deepens the sprawl. The current `infra/` is too narrow (just Caddy) to absorb them without restructuring. |
| **GitOps incompatibility** | Flux/ArgoCD watches a Git path for Kubernetes manifests. Scattering service definitions across 7 repos means either 7 Flux sources (operational nightmare) or manually consolidating manifests at deploy time (defeats the purpose of GitOps). |
| **Weak portfolio signal** | A reviewer scanning the GitHub profile sees 4 near-empty repos. This reads as fragmentation, not engineering rigor. A single, well-structured infrastructure repo demonstrates systems thinking. |

---

## Proposed State

### Repository layout

```
vpatrin/
├── coupette/           # Product — FastAPI + bot + scraper + React frontend
├── url-shortener/      # Custom Python app — own Dockerfile, CI, releases
├── ssh-resume/         # Custom Go app — own Dockerfile, CI, releases
├── site/               # Personal site — blog, resume, projects (Zola, planned)
└── infra/              # Platform — services, IaC, K8s manifests
```

**5 repos total** (4 app repos + 1 platform repo). Down from 7.

### Decision rule

> **Does it have custom application code, its own test suite, and its own release cycle?**
> - Yes → own repo.
> - No → it belongs in `infra/`.

Umami, Uptime Kuma, and shared PostgreSQL fail this test — they're third-party images with declarative config. They belong alongside the reverse proxy, DNS records, and monitoring stack as **platform infrastructure**.

### `infra/` repo structure

```
infra/
├── services/                       # What runs on the server
│   ├── caddy/
│   │   └── Caddyfile
│   ├── postgres/
│   │   ├── init-scripts/
│   │   └── backups/                # pg-backup.sh, systemd timer
│   ├── umami/
│   ├── uptime-kuma/
│   ├── homepage/                   # Static site (victorpatrin.dev)
│   ├── grafana/                    # Observability phase
│   ├── loki/
│   └── promtail/
│
├── terraform/                      # How the server is provisioned
│   ├── main.tf                     # Hetzner server, SSH key, firewall
│   ├── dns.tf                      # DNS records (all domains)
│   ├── outputs.tf                  # Server IP → feeds Ansible inventory
│   └── variables.tf
│
├── ansible/                        # How the server is configured
│   ├── inventory/
│   │   └── hosts.yml
│   ├── roles/
│   │   ├── base/                   # apt, swap, sysctl, fail2ban, ufw
│   │   ├── docker/                 # Docker + compose install
│   │   ├── k3s/                    # K3s install + node join (Kubernetes phase)
│   │   └── app/                    # Generic deploy role (parameterized)
│   └── playbooks/
│       ├── bootstrap.yml           # Fresh Debian → production-ready
│       └── deploy.yml              # Deploy a specific service
│
├── k8s/                            # Kubernetes phase — K3s manifests (Flux watches this path)
│   ├── base/                       # Namespaces, ingress, shared config
│   └── apps/
│       ├── coupette/
│       ├── umami/
│       ├── uptime-kuma/
│       └── url-shortener/
│
├── scripts/                        # Setup automation, repo-level utilities
├── docker-compose.yml              # Single root compose — all services defined here (pre-K3s)
├── Makefile
└── README.md
```

### Compose strategy

A single root `docker-compose.yml` defines all services. No per-service compose files — that's unnecessary indirection for this scale. Service-specific config (Caddyfile, init scripts, backup scripts) lives in `services/<name>/`, but the service *definition* lives in the root compose.

This means the `services/` directories hold **config and data**, not compose definitions:

```text
services/caddy/Caddyfile           # Config mounted into the caddy service
services/postgres/init-scripts/    # Mounted into the postgres service
services/postgres/backups/         # Backup scripts + systemd units
services/homepage/index.html       # Static files served by Caddy
```

### Environment variables

Each service keeps its own `.env` file in `services/<name>/.env`, all gitignored. This preserves the current per-repo isolation — umami doesn't see postgres credentials and vice versa. The root compose references each service's env file explicitly:

```yaml
services:
  umami:
    env_file: ./services/umami/.env
  postgres:
    env_file: ./services/postgres/.env
```

Each `services/<name>/` directory includes a `.env.example` committed with placeholder values for documentation. On the VPS, `.env` files are managed manually (or by Ansible in the Ansible phase).

### Contract with app repos

App repos (coupette, url-shortener) don't manage their own infrastructure but depend on it. These assumptions must hold for app repos to deploy correctly:

- An `internal` Docker network exists (external, shared across compose stacks). App repos attach to it for Caddy routing.
- A `shared-postgres` container is running and reachable on the `internal` network. App repos connect to it by container name.
- Caddy routes are defined in `infra/services/caddy/Caddyfile`. Adding a new app route requires a PR to `infra/`.

If any of these change, app deploy scripts must be updated in the same logical change.

### Terraform state

Terraform state will be stored locally during initial adoption (single developer, single server). If the IaC layer grows or a second environment is added, migrate to an S3-compatible backend (Hetzner Object Storage or Terraform Cloud free tier). This decision should be made before the Ansible phase begins.

### Why not split `infra/` and `deploy/`?

We considered a dedicated `deploy/` repo for Terraform + Ansible + K8s manifests. The argument for splitting:

- Separation of concerns: "what runs" vs. "how it's deployed"
- Different CI pipelines (Docker lint vs. `terraform plan`)

The argument against (which wins at our scale):

- **Single logical change.** Adding a new service touches the compose definition, the DNS record (Terraform), the deploy role (Ansible), and the K8s manifest — all in one PR. Splitting them means 2+ PRs for one operation.
- **One developer.** The "separate repos for separate teams" heuristic doesn't apply.
- **Flux path scoping.** Flux can watch `infra/k8s/` specifically (`--path=./k8s`). Co-locating K8s manifests with Ansible/Terraform doesn't create GitOps noise — Flux ignores everything outside its watched path.

If the team grows or the IaC layer becomes substantial enough to warrant its own review process, the `terraform/`, `ansible/`, and `k8s/` directories can be extracted into a `deploy/` repo. The directory structure is designed to make that split trivial.

---

## Migration Plan

### What moves where

| Current repo | Action | Destination |
|---|---|---|
| `infra/` | Expand in place | `infra/` (stays) |
| `shared-postgres/` | Move compose + init-scripts | `infra/services/postgres/` |
| `umami/` | Move compose | `infra/services/umami/` |
| `uptime-kuma/` | Move compose | `infra/services/uptime-kuma/` |
| `coupette/` | No change | `coupette/` (stays) |
| `url-shortener/` | No change | `url-shortener/` (stays) |
| `ssh-resume/` | No change | `ssh-resume/` (stays) |

### Migration sequence

1. **Restructure `infra/`** — create `services/` directory, move Caddy config and homepage into the new structure. Update volume mount paths in root compose. Existing functionality unchanged.
2. **Absorb shared-postgres** — move init-scripts and backup scripts into `services/postgres/`. Add postgres service definition to root `docker-compose.yml`. Move `.env` into `services/postgres/.env`. Run `docker compose config` to validate the merged compose file.
3. **Absorb umami** — add umami service definition to root compose. Move `.env` into `services/umami/.env`. Validate with `docker compose config`.
4. **Absorb uptime-kuma** — add uptime-kuma service definition to root compose. Validate with `docker compose config`.
5. **Update Coupette's deploy script** — `deploy/deploy.sh` references `shared-postgres` for backups and assumes postgres is managed externally. Update the backup path, container name reference, and any assumptions about postgres "already running" to reflect the new `infra/` layout.
6. **Archive old repos** — mark `shared-postgres`, `umami`, `uptime-kuma` as archived on GitHub. Don't delete — preserves commit history. Update each archived repo's README with: (1) where the content moved (path in `infra/`), (2) the date of the migration, and (3) the last commit hash that was migrated.
7. **Add IaC directories** — create `terraform/` and `ansible/` stubs. Populate as the Terraform and Ansible phases begin.

Each step is independently deployable. No big-bang migration.

### Deploy safety: volume names

Docker Compose prefixes volume names with the project name (directory name by default). When moving a service to a new compose file, the volume name changes and **data appears lost**.

For each absorbed service:

1. Check the current volume name on the VPS: `docker volume ls | grep <service>`
2. In the new root compose, declare volumes as `external: true` with the exact existing name
3. Verify data is accessible after `docker compose up -d`

Example for postgres (current volume is `shared-postgres_pgdata`):

```yaml
volumes:
  shared-postgres_pgdata:
    external: true
```

This avoids data loss and avoids copying volumes. Once confirmed working, the old compose project can be removed with `docker compose down` (without `-v`).

---

## CI/CD Architecture

### Pre-K3s (Terraform + Ansible + Automated Deployment)

```
App repo (coupette)                     infra/
┌──────────────────────┐               ┌──────────────────────┐
│ push tag v1.5.0      │               │                      │
│  → CI: test + lint   │               │                      │
│  → build image       │──push GHCR──→ │                      │
│  → dispatch event    │──trigger────→ │  deploy workflow      │
│                      │               │   → ansible deploy    │
│                      │               │   → health check      │
└──────────────────────┘               └──────────────────────┘
```

- App repos own **build** (test, lint, Docker image).
- `infra/` owns **deploy** (Ansible playbook, triggered by repository dispatch).
- Deploys only on tagged releases, never on push to main.

### Post-K3s (Kubernetes)

```
App repo (coupette)                     infra/
┌──────────────────────┐               ┌──────────────────────┐
│ push tag v1.5.0      │               │                      │
│  → CI: test + lint   │               │ k8s/apps/coupette/   │
│  → build image       │──push GHCR──→ │  → update image tag  │
│                      │               │  → Flux detects change│
│                      │               │  → auto-sync to K3s  │
└──────────────────────┘               └──────────────────────┘
```

- Same image build pipeline.
- Flux watches `infra/k8s/` and reconciles automatically.
- Ansible still handles non-K8s infra (Caddy if kept outside cluster, backup scripts).

### `infra/` CI pipelines (target state)

These pipelines are introduced incrementally as each IaC layer is adopted — not all at once.

| Trigger | Pipeline | What it does | Introduced in |
| --- | --- | --- | --- |
| PR touching `services/` | Docker CI | Hadolint, compose config validation | Consolidation phase |
| PR touching `terraform/` | Terraform CI | `terraform fmt -check`, `terraform validate`, `terraform plan` (comment on PR) | Terraform phase |
| PR touching `ansible/` | Ansible CI | `ansible-lint`, syntax check | Ansible phase |
| PR touching `k8s/` | K8s CI | `kubeval` / `kubeconform` manifest validation | Kubernetes phase |
| Merge to main | Deploy | Ansible playbook or Flux sync (depending on phase) | Automated Deployment phase |

---

## Risk Assessment

| Risk | Mitigation |
|---|---|
| **Large blast radius** — one bad merge to `infra/` could break everything | CI gates per directory (Terraform changes don't skip Docker lint). Branch protection on main. Ansible `--check` dry-run before apply. |
| **Monorepo complexity** — `infra/` grows unwieldy over time | Clear directory boundaries. If any subdirectory exceeds ~20 files or develops its own release cycle, extract it. The structure is designed for clean extraction. |
| **Secrets management** — more config in one repo means more exposure surface | No secrets in the repo, ever. `ansible-vault` for sensitive vars. `.env` files on the server, never committed. Terraform uses env vars or `terraform.tfvars` (gitignored). CI secrets via GitHub repository secrets. |
| **Git history loss** — absorbing repos loses their commit history | Archive old repos (read-only), don't delete. Add a note in each archived repo's README pointing to the new location. The absorbed repos have minimal history (3-file repos with ~10 commits) — archiving is sufficient. |
| **Blast radius scales with collaborators** — if the team grows, one repo with all infra is risky | Directory structure supports `CODEOWNERS` scoping (e.g., `terraform/` changes require IaC review, `k8s/` requires platform review). Not needed now, but the layout is ready for it. |

---

## Portfolio Narrative

The reorganization supports a clear infrastructure story:

> "I run a multi-service platform on Hetzner, provisioned with Terraform, configured with Ansible, and deployed via GitOps (Flux on K3s). The entire infrastructure — from DNS records to Kubernetes manifests — lives in a single `infra` repo. Application repos own their code and CI; the platform repo owns deployment. I started with Docker Compose and migrated to K3s — the commit history shows the progression."

A reviewer scanning the GitHub profile sees:
- `coupette` — full-stack product (FastAPI + React + Telegram bot)
- `infra` — complete infrastructure lifecycle (Compose → IaC → K3s)
- `url-shortener`, `ssh-resume` — small focused apps
- `site` — personal site (blog, resume, projects) on the infra they just read about

Five repos, each with a clear purpose. No noise.

---

## Decision

**Consolidate from 7 repos to 5 by absorbing infrastructure-only repos into an expanded `infra/`.** Preserve the repo for all current and future platform concerns: service definitions, IaC, and Kubernetes manifests.

Proceed with migration sequence starting with `infra/` restructure, absorbing one service at a time. Each step is independently deployable and reversible (archived repos can be un-archived).
