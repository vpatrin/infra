# ADR 0001: Hetzner CX22 Single VPS

**Date:** 2026-03-16
**Status:** Accepted

## Context

The platform needs a server to run all services: reverse proxy, database, analytics, monitoring, and the coupette application. Cost must stay minimal (solo project, no revenue), with full root access for Docker, systemd timers, and firewall rules. EU data center preferred for GDPR simplicity.

## Options considered

1. **PaaS (Railway, Render, Fly.io)** — zero server management, but costs scale per-service ($25-35/mo for 5 services). No root access means no systemd timers, no custom backup scripts, no `docker exec`. Vendor lock-in.
2. **AWS/GCP free tier** — massive ecosystem, but free tier is restrictive (1GB RAM — not enough for pgvector + 5 services). Opaque costs after free tier. Operational surface area designed for teams, not solo devs.
3. **Hetzner Cloud** — EU-based, transparent pricing. CX22 (4GB RAM, 2 vCPU, 40GB SSD) at ~$5/mo. Full root, Debian, Terraform-compatible API.

## Decision

Run everything on a single Hetzner CX22 (4GB RAM, 2 vCPU, 40GB SSD, Debian 13). Memory budget: Postgres 1GB, Caddy 256MB, umami 256MB, uptime-kuma 256MB, coupette ~1GB, OS + swap ~1GB. Enforced via `mem_limit` on every container.

## Rationale

- ~$5/mo total hosting cost — no per-service billing surprises
- Full control: systemd timers for backups, ufw for firewall, direct `docker logs` for debugging
- One server = one thing to SSH into, back up, and firewall. Entire platform runs on `docker compose up -d`
- Vertical scaling is easy (CX32 = 8GB for ~$9/mo) if memory becomes the bottleneck before K3s migration

## Consequences

- Single point of failure — if the VPS goes down, everything is down. Mitigated by automated backups and Terraform + Ansible for rebuild.
- 4GB constraint forces discipline — memory limits on every container, no room for waste.
- EU data center simplifies GDPR — no cross-border data transfer concerns.
