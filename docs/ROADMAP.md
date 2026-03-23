# Roadmap

Phased plan for platform infrastructure. Each phase is independently deployable.

Infrastructure-level concerns only — app-level roadmaps live in their respective repos.

---

## Phase 0 — Foundation (2026-02-21) ✅

Caddy reverse proxy, static homepage, basic Makefile.

## Phase 1 — Consolidation (2026-03-16) ✅

Absorb shared-postgres, umami, uptime-kuma into single repo. Restructure into `services/` layout. Single root `docker-compose.yml`. CI + Dependabot. Container security hardening (cap_drop, read-only, healthchecks, mem_limit).

*(#22–#30)*

## Phase 2 — Documentation & Contracts (2026-03-17) ✅

Make the platform legible. Zero blast radius — no running services touched.

- [x] `ROADMAP.md` — this file
- [x] `APP_CONTRACT.md` — service inventory + platform contract for app repos
- [x] `SECURITY.md` — platform security posture
- [x] `ARCHITECTURE.md` updates — restore procedure, systemd timer inventory, extension requirements
- [x] `decisions/` — ADR directory with consolidation decision record

*(#31)*

## Phase 3 — Monitoring & Alerts (2026-03-17) ✅

First real alerting. Know when things break instead of discovering it weeks later.

- [x] Uptime Kuma push monitors for systemd timers (backup, scraper, availability)
- [x] Document push monitor pattern for app repos to adopt
- [x] Cron failure → alert path

*(#33, #34, #35, #39)*

## Phase 4 — Continuous Deployment (2026-03-18) ✅

No more manual deploys. Tag push deploys coupette. One-click deploys infra.

- [x] SSH deploy key + GitHub Actions secrets (#44)
- [x] sops + age encrypted secrets (#45)
- [x] `deploy_infra.sh` — idempotent deploy script (#44)
- [x] GitHub Actions workflow — manual dispatch (#44)
- [x] `APP_CONTRACT.md` — deploy key pattern documented
- [x] Coupette CD — `deploy.sh` + tag-push workflow (coupette repo)

## Phase 8 — Observability (2026-03-19) ✅ *(done before Phase 5 — Compose-first observability before DR automation)*

Platform observability on Compose. Grafana + Loki + Prometheus + Alloy — learn the stack with fast feedback loops before K3s migration.

Coupette's RAG pipeline needs structured metrics and log aggregation. `docker logs` and `journalctl` don't answer "is retrieval quality degrading?" or "what's the daily LLM cost?" Compose-first, then migrate alongside everything else in the K3s phase.

### Phase 8a — Stack + Platform Dashboard (2026-03-19)

- [x] ADR: `decisions/0008-observability-stack.md`
- [x] Add Grafana, Loki, Prometheus, Alloy to `docker-compose.yml`
- [x] Alloy config: Docker log collection via socket + node metrics
- [x] Prometheus scrape config: Alloy, Prometheus self-metrics
- [x] Grafana provisioning: datasources (Loki + Prometheus), dashboard provider
- [x] Platform Overview dashboard (container status, CPU/memory/disk, log volume, error rates, systemd timer health)
- [x] Temporary localhost port bindings for Grafana (until WireGuard in Phase 9)
- [x] `docs/OBSERVABILITY.md` — stack overview, config walkthrough, querying with LogQL/PromQL, adding dashboards
- [x] Update APP_CONTRACT.md, ARCHITECTURE.md, SECURITY.md

### Phase 8b — Additional Exporters (2026-03-21) ✅

- [x] Caddy Prometheus metrics — `metrics` global option in Caddyfile, Prometheus scrape target (no extra container)
- [x] postgres_exporter — Alloy embedded `prometheus.exporter.postgres` (no extra container)
- [x] Postgres dashboard in Grafana
- [x] systemd journal logs — Alloy `loki.source.journal` for timer/service logs (pg-backup, disk-alert, coupette timers)

### Phase 8c — Application Dashboards

- [x] Coupette exposes Prometheus metrics at `/metrics`
- [ ] Recommendations & RAG Quality dashboard (latency, similarity distribution, token cost, zero-candidate rate)
- [ ] Scraper & Data Pipeline dashboard (run duration, products scraped, embedding rate)
- [ ] Alerting rules (low similarity, high error rate, scraper failure)

*Remaining items depend on coupette exposing structured metrics and custom counters (#63). Dashboards can't be built until the app emits the data.*

---

## Phase 5 — Disaster Recovery

**Context:** web-01 is a single point of failure. If it dies, recovery is manual — SSH in, re-provision, restore from backups. No runbook, no automation, no offsite backups.
**Action:** Daily Postgres dumps to AWS S3 (provider diversity). Terraform for VPS provisioning (state in Hetzner Object Storage). Ansible for full server configuration. DR runbook with tested recovery flow.

### Backup strategy

- [x] Daily Postgres dumps (all DBs) → AWS S3 — 30-day retention via S3 lifecycle rule
- [x] Backup script rewritten — S3 as primary (no local retention), fail loudly on upload failure
- [ ] Restore smoke test — verify current dumps restore into a throwaway container before trusting offsite

### Terraform

- [ ] Hetzner VPS (Debian 13) + SSH key registration
- [ ] Hetzner firewall rules (22, 80, 443)
- [ ] State backend in Hetzner Object Storage (bucket created manually)
- [ ] CI gate — `terraform validate` on PR
- [ ] Outputs VPS IP for Ansible inventory

### Ansible

- [ ] `requirements.yml` — `geerlingguy.security`, `geerlingguy.docker`
- [ ] `roles/base` — swap, timezone, locale, Docker log rotation, sops + age
- [ ] `roles/security` — SSH hardening, fail2ban, ufw (wraps `geerlingguy.security`)
- [ ] `roles/docker` — Docker + Compose plugin (wraps `geerlingguy.docker`)
- [ ] `roles/infra` — clone infra + coupette repos, `internal` network, sops-encrypted `.env.prod` files, compose up (all services incl. observability stack)
- [ ] `roles/timers` — provision systemd units (pg-backup, disk-alert)
- [ ] Ansible vault — sops age key, SSH deploy key, AWS S3 credentials, Hetzner Object Storage credentials, push monitor URLs
- [ ] CI gate — `ansible-lint` on PR

### DR runbook + validation

- [ ] `docs/DISASTER_RECOVERY.md` — DR spec, scenarios, runbook, app contract
- [ ] DR test — spin up real web-02, run full flow, verify traffic serves, tear down

## Phase 6 — Kubernetes

**Context:** Docker Compose works for a single VPS, but doesn't support rolling updates, auto-healing, or GitOps natively. K3s would add these without the overhead of full K8s.
**Action:** Install K3s via Ansible, bootstrap Flux for GitOps, migrate services to K8s manifests (stateless first, then stateful).

- [ ] K3s install via Ansible role
- [ ] Flux bootstrap — watches `k8s/` path
- [ ] Migrate services to K8s manifests (stateless first, then stateful)
- [ ] App repo integration — Flux image automation

## Phase 7 — Automated Deployment

**Context:** Phase 4's SSH-based deploy works but doesn't leverage K8s capabilities. Helm + Flux would give declarative deploys with rollback.
**Action:** Helm charts for all services, Flux image automation for tag-push deploys, health check gates with automatic rollback.

- [ ] Helm charts for infra services + coupette
- [ ] Flux image automation — tag push triggers rollout
- [ ] Health check gate + rollback
- [ ] Retire `deploy_infra.sh` and `deploy.sh` SSH-based workflows

## Phase 9 — WireGuard VPN

**Context:** SSH and observability tools are exposed on the public interface. Port 22 is brute-forced daily (fail2ban mitigates, but the surface exists). Moving admin traffic behind a VPN eliminates the exposure entirely.
**Action:** Host-level WireGuard tunnel, peer setup for dev machine, SSH hardened to listen only on tunnel interface. Break-glass via Hetzner web console.

### Host-level WireGuard

- [ ] Install WireGuard on the VPS host (not a container — needs full host network access)
- [ ] Generate server keypair, configure `wg0` interface (`10.0.0.1/24`)
- [ ] systemd unit: `wg-quick@wg0` (enabled, starts on boot)
- [ ] UFW: allow UDP 51820 on public interface
- [ ] IP forwarding enabled (`net.ipv4.ip_forward=1`) for tunnel routing to Docker network

### Peer setup

- [ ] Generate peer keypair for dev machine (macOS)
- [ ] Dev machine: `10.0.0.2`, server: `10.0.0.1`
- [ ] macOS WireGuard client config with DNS + allowed IPs
- [ ] Validate: tunnel up, `ping 10.0.0.1`, reach Docker containers by `10.0.0.1:<port>`

### SSH hardening

- [ ] `sshd_config`: `ListenAddress 10.0.0.1` — SSH only on WireGuard interface
- [ ] UFW: remove `allow 22` from public interface
- [ ] Verify: SSH unreachable from public internet, reachable via tunnel
- [ ] Verify: Hetzner web console still works as break-glass path
- [ ] Update GitHub Actions deploy workflow — SSH via WireGuard or keep a scoped exception (deploy key from GitHub IP ranges)

### Documentation

- [ ] `docs/guides/WIREGUARD_SETUP_GUIDE.md` — server config, peer setup, key generation, macOS client, troubleshooting, break-glass procedure
- [ ] Update SECURITY.md — new network posture, attack surface reduction
- [ ] Update ARCHITECTURE.md — SSH access method change
- [ ] ADR: `decisions/0009-wireguard-vpn.md`

---

## Backlog

Concrete housekeeping — not phased, ship when convenient.

- [ ] Rename `saq_sommelier` in backup script — blocked on coupette DB rename (#21, coupette #423)
- [ ] Rename uptime-kuma volume to follow naming convention (#79)
- [ ] Enable `pg_stat_statements` for query monitoring (#96)
- [ ] Run security hardening audits — docker-bench, Lynis, ssh-audit (#56). Informs Phase 9.
- [ ] Evaluate GitHub organization for shared workflows (#73)

## Ideas (unscoped)

- [ ] Coupette analytics dashboard — intent distribution, user engagement, search patterns (separate from ops dashboards)
- [ ] Staging environment — same VPS, separate ports + DB, promotion pattern
- [ ] Multi-node — second VPS, load balancing (only if traffic demands)
- [ ] HashiCorp Vault — centralized secrets with RBAC (overkill until team grows)
- [ ] Postgres tuning — `shared_buffers`, `effective_cache_size`, `work_mem` for pgvector workload on 4GB VPS
- [ ] Structured JSON logging for Coupette — `structlog`/`python-json-logger`, enables LogQL field queries in Loki
