# ADR 0006: Consolidate Infrastructure Repos

**Date:** 2026-03-16
**Status:** Accepted

## Context

7 Git repositories to run 5 services on a single VPS. Four of those repos contain nothing but a `docker-compose.yml`, a `Makefile`, and a `README`. As we adopt IaC (Terraform, Ansible) and eventually K3s with GitOps, this fragmentation becomes a liability — every new capability touches multiple repos for a single logical change.

```
vpatrin/  (before)
├── infra/              # Caddy reverse proxy + homepage (1 container)
├── shared-postgres/    # docker-compose.yml + README
├── umami/              # docker-compose.yml + README
├── uptime-kuma/        # docker-compose.yml + README
├── url-shortener/      # Custom Python app
├── ssh-resume/         # Custom Go app
└── coupette/           # Main product — FastAPI + bot + scraper + React
```

Decision rule: **Does it have custom application code, its own test suite, and its own release cycle?** Yes → own repo. No → belongs in `infra/`.

## Options considered

1. **Keep 7 repos** — each service isolated. But cross-repo changes require 3+ PRs for one logical operation. No home for Terraform/Ansible. GitOps with Flux would need 7 sources. Repo sprawl signals fragmentation, not engineering rigor.
2. **Consolidate to 5 repos** — absorb infrastructure-only repos (shared-postgres, umami, uptime-kuma) into an expanded `infra/`. App repos (coupette, url-shortener, ssh-resume) keep their own repos. Single `docker-compose.yml` for all platform services. Natural home for Terraform, Ansible, and K8s manifests.

## Decision

Consolidate from 7 repos to 5 by absorbing infrastructure-only repos into `infra/`. Each absorbed service moves its compose definition into the root `docker-compose.yml` and its config into `services/<name>/`. One service absorbed at a time, each step independently deployable.

Volume safety: declare absorbed volumes as `external: true` with the exact existing name to avoid data loss on project name change.

## Rationale

- Single logical change = single PR. Adding a service touches compose, Caddyfile, and docs in one commit
- Natural home for IaC — `terraform/`, `ansible/`, `k8s/` directories without creating another repo
- GitOps-ready — Flux watches one repo path (`k8s/`), not 7 sources
- Clear ownership boundary: `infra/` owns the platform, app repos own their code

## Consequences

- Larger blast radius — one bad merge to `infra/` could break everything. Mitigated by CI gates per directory and branch protection.
- App repos depend on platform contract: `internal` network exists, `shared-postgres` is running, Caddy routes are defined here. See [APP_CONTRACT.md](../APP_CONTRACT.md).
- Archived repos (shared-postgres, umami, uptime-kuma) preserve commit history. Don't delete — mark read-only.
