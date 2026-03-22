# ADR 0004: Docker Compose as Orchestrator

**Date:** 2026-03-16
**Status:** Accepted

## Context

With all services consolidated into one repo ([ADR 0006](0006-consolidate-repos.md)) on a single VPS ([ADR 0001](0001-hetzner-single-vps.md)), we need a way to define, start, and manage the containers. The choice determines the deployment workflow and K8s migration path.

## Options considered

1. **Bare `docker run` commands** — maximum control, but managing 5+ containers with networks, volumes, healthchecks via shell scripts is fragile and hard to diff. No declarative state.
2. **Podman + Quadlet** — rootless by default, systemd-native. But smaller ecosystem, partial compose compatibility. Solving a problem (rootless) that `cap_drop: ALL` already addresses.
3. **K3s now** — full GitOps, rolling updates. But K3s consumes ~500MB for the control plane alone on a 4GB VPS. Operational surface (manifests, RBAC, ingress, PVCs) disproportionate to 5 containers on one node.
4. **Docker Compose** — declarative YAML, `docker compose up -d` deploys the full stack. Supports healthchecks, restart policies, networks, volumes, memory limits. Diffable, reviewable, CI-validatable.

## Decision

Use Docker Compose with a single root `docker-compose.yml` for all platform services. Deployment is `git pull && make restart`. Background scheduling (backups, scraper) uses systemd timers — Compose manages long-running services, systemd manages periodic jobs.

## Rationale

- Entire platform state declared in one file — `docker compose config` validates, `docker compose ps` shows, `docker compose logs` debugs
- Two-command deployment, no pipeline to maintain until CD phase
- Compose structure (service names, network names, volume names) maps cleanly to K8s manifests when the K3s phase arrives

## Consequences

- No rolling updates — `docker compose up -d` recreates changed containers. Acceptable for low-traffic services; Caddy's `make reload` handles zero-downtime config changes separately.
- App repos must share the `internal` network (`external: true`) — intentional coupling documented in the platform contract.
