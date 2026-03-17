# ADR 0001: Hetzner CX22 Single VPS

**Date:** 2026-03-16
**Status:** Accepted

---

## Context

The platform needs a server to run all services: reverse proxy, database, analytics, monitoring, and the coupette application. The choice of hosting provider and instance size shapes every downstream decision — memory budgets, deployment strategy, and migration path.

## Decision Drivers

- Cost — solo project, no revenue, needs to stay cheap
- Control — full root access for Docker, systemd timers, firewall rules
- Location — EU data center preferred (target audience, GDPR simplicity)
- Simplicity — one server to manage, not a fleet

## Options Considered

### PaaS (Railway, Render, Fly.io)

Zero server management, git-push deploys, managed databases. But costs scale per-service ($5-7/service/month — 5 services = $25-35/mo before database). No root access means no systemd timers, no custom backup scripts, no `docker exec` for debugging. Vendor lock-in on networking and storage. Good for prototyping, expensive for a multi-service platform.

### AWS/GCP free tier

12-month free tier, massive ecosystem. But the free tier is restrictive (t2.micro = 1GB RAM — not enough for pgvector + 5 services). After the free tier, costs are opaque and hard to predict. The operational surface area (VPC, security groups, IAM, EBS) is designed for teams, not solo developers. Previous GCP/K8s experience means this isn't a learning opportunity — it's just overhead.

### Hetzner Cloud

EU-based, transparent pricing. CX22 (4GB RAM, 2 vCPU, 40GB SSD) at ~$5/mo. Full root, Debian, no surprises. Hetzner's API supports Terraform for future IaC adoption. No managed services to depend on — you get a VM and that's it.

## Decision

**Run everything on a single Hetzner CX22 (4GB RAM, 2 vCPU, 40GB SSD, Debian 13).**

The 4GB budget breaks down as: Postgres 1GB, Caddy 256MB, umami 256MB, uptime-kuma 256MB, coupette services ~1GB, OS + swap ~1GB. This is tight but workable — enforced via `mem_limit` on every container, with 2GB swap as a safety net.

One server means one thing to SSH into, one thing to back up, one firewall to configure. The entire platform runs on `docker compose up -d` after a `git pull`. No service mesh, no inter-node networking, no distributed state.

## Consequences

- Total hosting cost is ~$5/mo. No per-service billing surprises.
- Full control: systemd timers for backups and scraper schedules, ufw for firewall, direct `docker logs` for debugging.
- The 4GB constraint forces discipline — no Loki/Grafana observability stack (Phase 9 deferred to post-K3s/multi-node), no local LLM inference, memory limits on every container.
- Single point of failure — if the VPS goes down, everything is down. Mitigated by automated backups and the ability to rebuild from Terraform + Ansible (Terraform and Ansible phases).
- Vertical scaling is easy (resize to CX32 = 8GB for ~$9/mo) if memory becomes the bottleneck before K3s migration.
- EU data center simplifies GDPR — no cross-border data transfer concerns.
