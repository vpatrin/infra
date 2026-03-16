# Roadmap

Phased plan for platform infrastructure. Each phase is independently deployable.

Infrastructure-level concerns only — app-level roadmaps live in their respective repos.

---

## Phase 0 — Foundation ✅

Caddy reverse proxy, static homepage, basic Makefile.

## Phase 1 — Consolidation ✅

Absorb shared-postgres, umami, uptime-kuma into single repo. Restructure into `services/` layout. Single root `docker-compose.yml`. CI + Dependabot. Container security hardening (cap_drop, read-only, healthchecks, mem_limit).

*(#22–#30)*

## Phase 2 — Documentation & Contracts

Make the platform legible. Zero blast radius — no running services touched.

- [ ] `ROADMAP.md` — this file
- [ ] `SERVICE_CATALOG.md` — service inventory + platform contract for app repos
- [ ] `SECURITY.md` — platform security posture
- [ ] `INFRASTRUCTURE.md` updates — restore procedure, systemd timer inventory, extension requirements
- [ ] `decisions/` — ADR directory with consolidation decision record

*(#31)*

## Phase 3 — Monitoring & Alerts

First real alerting. Know when things break instead of discovering it weeks later.

- [ ] Uptime Kuma push monitors for systemd timers (backup, scraper, availability)
- [ ] Document push monitor pattern for app repos to adopt
- [ ] Cron failure → alert path

## Phase 4 — Terraform

Codify what's currently manual VPS provisioning. Bounded scope — run once, rarely touch again.

- [ ] Hetzner VPS + SSH key
- [ ] Hetzner firewall rules
- [ ] DNS records (Porkbun)
- [ ] CI gate — `terraform validate` on PR

## Phase 5 — Ansible

Automate server configuration and deployment. Iterative — this is where ongoing operational value lives.

- [ ] Bootstrap playbook — fresh Debian → production-ready (Docker, ufw, swap, fail2ban)
- [ ] Deploy playbook — `git pull` + `make restart` via playbook
- [ ] CI gate — `ansible-lint` on PR

## Phase 6 — Secrets Management

Replace `.env` files with encrypted secrets. Prerequisite for automated deployment.

- [ ] sops + age setup — encrypted secrets committed, decrypted at deploy time
- [ ] Migrate postgres + umami credentials
- [ ] Document secrets workflow for app repos
- [ ] Delete `.env.example` files (secrets self-documenting via sops)

## Phase 7 — Automated Deployment

App repos trigger deploys via infra. No more SSH + git pull.

- [ ] Repository dispatch → Ansible deploy workflow
- [ ] Health check gate after deploy
- [ ] Rollback automation (re-deploy previous tag)
- [ ] Environment-scoped GitHub secrets

## Phase 8 — Kubernetes

Docker Compose → K3s + Flux GitOps. Only when scaling demands it or for portfolio signal — not before.

- [ ] K3s install via Ansible role
- [ ] Flux bootstrap — watches `k8s/` path
- [ ] Migrate services to K8s manifests (stateless first, then stateful)
- [ ] App repo integration — Flux image automation

## Phase 9 — Observability

Log aggregation and dashboards. Deferred until multi-node (Phase 8) — on a single VPS, `docker logs` and `journalctl` are sufficient. Adding Loki + Grafana to a 4GB VPS with pgvector is a bad memory trade-off.

- [ ] Loki + Promtail — log aggregation, queryable via `logcli`
- [ ] Grafana — dashboards (only if CLI log search isn't enough)
- [ ] Caddy structured access logs
- [ ] Per-service log viewer + error rate dashboards

## Ideas (unscoped)

- [ ] Staging environment — same VPS, separate ports + DB, promotion pattern
- [ ] Multi-node — second VPS, load balancing (only if traffic demands)
- [ ] HashiCorp Vault — centralized secrets with RBAC (overkill until team grows)
- [ ] Disaster recovery — automated VPS rebuild from Terraform + Ansible + latest backup
- [ ] Postgres tuning — `shared_buffers`, `effective_cache_size`, `work_mem` for pgvector workload on 4GB VPS
