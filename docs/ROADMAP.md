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

- [x] `ROADMAP.md` — this file
- [x] `SERVICE_CATALOG.md` — service inventory + platform contract for app repos
- [x] `SECURITY.md` — platform security posture
- [x] `INFRASTRUCTURE.md` updates — restore procedure, systemd timer inventory, extension requirements
- [x] `decisions/` — ADR directory with consolidation decision record

*(#31)*

## Phase 3 — Monitoring & Alerts

First real alerting. Know when things break instead of discovering it weeks later.

- [ ] Uptime Kuma push monitors for systemd timers (backup, scraper, availability)
- [ ] Document push monitor pattern for app repos to adopt
- [ ] Cron failure → alert path

## Phase 4 — Continuous Deployment

No more manual deploys. Tag push deploys coupette. One-click deploys infra.

### Prerequisites (manual, one-time)

- [x] Generate SSH deploy key (`ed25519`) — add public key to `/home/deploy/.ssh/authorized_keys` on web-01
- [x] Add private key to GitHub Actions secrets in both repos (`SSH_DEPLOY_KEY`)

### Secrets

- [x] sops + age setup — encrypted secrets committed, decrypted at deploy time (#45)
- [x] Encrypt `services/postgres/.env.prod` + `services/umami/.env.prod` → `.env.prod.enc` (#45)
- [x] Document secrets workflow — `docs/guides/SECRETS.md` (#45)

### Infra

- [x] `deploy_infra.sh` — idempotent: `git pull` + `docker compose up -d` + Caddy reload + systemd unit sync (#44)
- [x] GitHub Actions workflow — manual dispatch → `deploy_infra.sh` on VPS (#44)
- [ ] CI gate — `ansible-lint` on PR (prep for Phase 5)

### Coupette

- [ ] Extend `deploy.sh` — add idempotent systemd unit sync (scraper, availability timers)
- [ ] GitHub Actions workflow — tag push → build images → push GHCR → scp frontend → `deploy.sh` on VPS
- [ ] Update `SERVICE_CATALOG.md` — document deploy key pattern for app repos

## Phase 5 — Disaster Recovery

web-01 dies → fully operational replacement in one session, no data loss.

### Backup strategy

- [ ] Daily Postgres dumps (all DBs) → Hetzner Object Storage — 3-tier retention (daily 7d / weekly 4w / monthly 3m)
- [ ] Backup script updated — offload to object storage, prune per retention policy
- [ ] Restore smoke test — verify current dumps restore into a throwaway container before trusting offsite

### Terraform

- [ ] Hetzner VPS (Debian 13) + SSH key registration
- [ ] Hetzner firewall rules (22, 80, 443)
- [ ] CI gate — `terraform validate` on PR
- [ ] Outputs VPS IP for Ansible inventory

### Ansible

- [ ] `requirements.yml` — `geerlingguy.security`, `geerlingguy.docker`
- [ ] `roles/base` — swap, timezone, locale, Docker log rotation, sops
- [ ] `roles/security` — SSH hardening, fail2ban, ufw (wraps `geerlingguy.security`)
- [ ] `roles/docker` — Docker + Compose plugin (wraps `geerlingguy.docker`)
- [ ] `roles/infra` — clone infra + coupette repos, `internal` network, compose up, `deploy_infra.sh`
- [ ] `roles/timers` — provision infra systemd units (pg-backup, disk-alert, push monitors)
- [ ] Ansible vault — all secrets (Postgres, Umami, Telegram token, push monitor URLs, Hetzner Object Storage credentials, SSH deploy key public key, coupette `.env`)
- [ ] CI gate — `ansible-lint` on PR

### DR runbook + validation

- [ ] `docs/DISASTER_RECOVERY.md` — DR spec, scenarios, runbook, app contract
- [ ] DR test — spin up real web-02, run full flow, verify traffic serves, tear down

## Phase 6 — Kubernetes

Docker Compose → K3s + Flux GitOps. Only when scaling demands it or for portfolio signal — not before.

- [ ] K3s install via Ansible role
- [ ] Flux bootstrap — watches `k8s/` path
- [ ] Migrate services to K8s manifests (stateless first, then stateful)
- [ ] App repo integration — Flux image automation

## Phase 7 — Automated Deployment

Helm-based CD. Tag push → GitOps deploy. Replaces GitHub Actions SSH deploy pattern from Phase 4.

- [ ] Helm charts for infra services + coupette
- [ ] Flux image automation — tag push triggers rollout
- [ ] Health check gate + rollback
- [ ] Retire `deploy_infra.sh` and `deploy.sh` SSH-based workflows

## Phase 8 — Observability

Log aggregation and dashboards. Deferred until multi-node (Phase 6) — on a single VPS, `docker logs` and `journalctl` are sufficient. Adding Loki + Grafana to a 4GB VPS with pgvector is a bad memory trade-off.

- [ ] Loki + Promtail — log aggregation, queryable via `logcli`
- [ ] Grafana — dashboards (only if CLI log search isn't enough)
- [ ] Caddy structured access logs
- [ ] Per-service log viewer + error rate dashboards

## Ideas (unscoped)

- [ ] Staging environment — same VPS, separate ports + DB, promotion pattern
- [ ] Multi-node — second VPS, load balancing (only if traffic demands)
- [ ] HashiCorp Vault — centralized secrets with RBAC (overkill until team grows)
- [ ] Postgres tuning — `shared_buffers`, `effective_cache_size`, `work_mem` for pgvector workload on 4GB VPS
