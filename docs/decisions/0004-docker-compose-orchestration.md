# ADR 0004: Docker Compose as Orchestrator

**Date:** 2026-03-16
**Status:** Accepted

---

## Context

With all services consolidated into one repo ([ADR 0006](0006-consolidate-repos.md)) and running on a single VPS ([ADR 0001](0001-hetzner-single-vps.md)), we need a way to define, start, and manage the containers. The orchestration choice also determines the deployment workflow and the migration path to Kubernetes.

## Decision Drivers

- Single VPS, single developer — orchestration complexity must match scale
- 5 services today (Caddy, Postgres, umami, uptime-kuma, plus coupette in its own repo)
- Deployment is `ssh` + `git pull` + restart — no CI/CD pipeline yet
- Kubernetes (K3s) is on the roadmap but not justified today

## Options Considered

### Bare `docker run` commands

No abstraction layer — just shell scripts wrapping `docker run`. Maximum control, zero dependencies beyond Docker. But managing 5+ containers with networks, volumes, healthchecks, and restart policies via shell scripts is fragile and hard to diff in code review. No declarative state — "what should be running" lives in scripts, not config.

### Podman + Quadlet (systemd-native containers)

Rootless by default, systemd integration, no daemon. Quadlet generates systemd units from container definitions — native to the OS lifecycle. But the ecosystem is smaller, compose compatibility is partial, and the team's Docker muscle memory is strong. Migrating to K3s from Podman isn't harder, but it's less documented. Solving a problem (rootless) that `cap_drop: ALL` already addresses.

### Kubernetes (K3s) now

Full GitOps, Flux auto-sync, rolling updates, resource limits as first-class concepts. But K3s on a 4GB VPS consumes ~500MB for the control plane alone — that's 12% of total RAM before any workload runs. The operational surface (manifests, RBAC, ingress controllers, PVCs) is disproportionate to 5 containers on one node. Premature until traffic or team size demands it.

### Docker Compose

Declarative YAML, single `docker-compose.yml` defines the entire stack. `docker compose up -d` is the deploy command. Built into Docker Desktop and the Docker CLI. Supports healthchecks, restart policies, networks, volumes, memory limits — everything we need. The compose file is diffable, reviewable, and CI-validatable (`docker compose config --quiet`).

## Decision

**Use Docker Compose with a single root `docker-compose.yml` for all platform services.**

One compose file defines the full stack: Caddy, Postgres, umami, uptime-kuma. App repos (coupette) run their own compose file but attach to the shared `internal` network and depend on `shared-postgres` — both managed here.

Deployment is: `git pull && make restart` (which runs `docker compose up -d`). No orchestrator daemon, no control plane overhead, no abstraction beyond what Docker provides natively.

Background scheduling (backups, scraper) uses systemd timers rather than trying to shoehorn cron-like behavior into Compose. Compose manages long-running services; systemd manages periodic jobs.

## Consequences

- The entire platform state is declared in one file — `docker compose config` validates it, `docker compose ps` shows it, `docker compose logs` debugs it.
- Deployment is a two-command operation. No pipeline to maintain until the Automated Deployment phase.
- No rolling updates — `docker compose up -d` recreates changed containers. Acceptable for low-traffic services; Caddy's `make reload` handles zero-downtime config changes separately.
- The compose file structure (service names, network names, volume names) is designed to map cleanly to K8s manifests when the Kubernetes phase arrives. Each service becomes a Deployment + Service, the `internal` network becomes a namespace, volumes become PVCs.
- App repos must run their own `docker compose` but share the `internal` network (`external: true`) — this coupling is intentional and documented in the platform contract.
