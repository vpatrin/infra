# Roadmap

Phased plan for platform infrastructure. Each phase is independently deployable.

Infrastructure-level concerns only — app-level roadmaps live in their respective repos.

---

## Phase 0 — Foundation ✅

Caddy reverse proxy, static homepage, basic Makefile.

## Phase 1 — Consolidation ✅

Absorb shared-postgres, umami, uptime-kuma into single repo. Restructure into `services/` layout. Single root `docker-compose.yml`. CI + Dependabot. Container security hardening (cap_drop, read-only, healthchecks, mem_limit).

*(#22–#30)*

## Phase 2 — Documentation & Contracts ✅

Make the platform legible. Zero blast radius — no running services touched.

- [x] `ROADMAP.md` — this file
- [x] `SERVICE_CATALOG.md` — service inventory + platform contract for app repos
- [x] `SECURITY.md` — platform security posture
- [x] `INFRASTRUCTURE.md` updates — restore procedure, systemd timer inventory, extension requirements
- [x] `decisions/` — ADR directory with consolidation decision record

*(#31)*

## Phase 3 — Monitoring & Alerts ✅

First real alerting. Know when things break instead of discovering it weeks later.

- [x] Uptime Kuma push monitors for systemd timers (backup, scraper, availability)
- [x] Document push monitor pattern for app repos to adopt
- [x] Cron failure → alert path

*(#33, #34, #35, #39)*

## Phase 4 — Continuous Deployment ✅

No more manual deploys. Tag push deploys coupette. One-click deploys infra.

- [x] SSH deploy key + GitHub Actions secrets (#44)
- [x] sops + age encrypted secrets (#45)
- [x] `deploy_infra.sh` — idempotent deploy script (#44)
- [x] GitHub Actions workflow — manual dispatch (#44)
- [x] `SERVICE_CATALOG.md` — deploy key pattern documented
- [x] Coupette CD — `deploy.sh` + tag-push workflow (coupette repo)

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

Platform observability on Compose. Grafana + Loki + Prometheus + Alloy — learn the stack with fast feedback loops before K3s migration.

Coupette's RAG pipeline needs structured metrics and log aggregation. `docker logs` and `journalctl` don't answer "is retrieval quality degrading?" or "what's the daily LLM cost?" Compose-first, then migrate alongside everything else in the K3s phase.

### Phase 8a — Stack + Platform Dashboard

- [x] ADR: `decisions/0008-observability-stack.md`
- [x] Add Grafana, Loki, Prometheus, Alloy to `docker-compose.yml`
- [x] Alloy config: Docker log collection via socket + node metrics
- [x] Prometheus scrape config: Alloy, Prometheus self-metrics
- [x] Grafana provisioning: datasources (Loki + Prometheus), dashboard provider
- [x] Platform Overview dashboard (container status, CPU/memory/disk, log volume, error rates, systemd timer health)
- [x] Temporary localhost port bindings for Grafana (until WireGuard in Phase 9)
- [x] `docs/OBSERVABILITY.md` — stack overview, config walkthrough, querying with LogQL/PromQL, adding dashboards
- [x] Update SERVICE_CATALOG.md, INFRASTRUCTURE.md, SECURITY.md

### Phase 8b — Additional Exporters

- [ ] Caddy Prometheus metrics — `metrics` global option in Caddyfile, Prometheus scrape target (no extra container)
- [ ] postgres_exporter — connections, query latency, table sizes, dead tuples, pgvector index stats
- [ ] Postgres dashboard in Grafana
- [ ] systemd journal logs — Alloy `loki.source.journal` for timer/service logs (pg-backup, disk-alert, coupette timers)
- [ ] systemd unit status metrics — Alloy `prometheus.exporter.unix` with `systemd` collector enabled, dashboard for timer success/failure/last-run

### Phase 8c — Application Dashboards (blocked on coupette contract)

- [ ] Coupette emits structured JSON logs (event, query, similarity scores, latency, token usage)
- [ ] Coupette exposes Prometheus metrics at `/metrics`
- [ ] Recommendations & RAG Quality dashboard (latency, similarity distribution, token cost, zero-candidate rate)
- [ ] Scraper & Data Pipeline dashboard (run duration, products scraped, embedding rate)
- [ ] Alerting rules (low similarity, high error rate, scraper failure)

## Phase 9 — WireGuard VPN

Zero-trust network access to the VPS. All admin traffic (SSH, observability, database) moves behind a WireGuard tunnel. Port 22 closes on the public interface. The only internet-facing ports are 80, 443, and 51820/udp.

Break-glass recovery: Hetzner web console (browser-based, always available, no SSH required).

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

### Private DNS

- [ ] CoreDNS as a Compose service on the `internal` network — resolves `*.internal` to `10.0.0.1`, forwards everything else upstream
- [ ] WireGuard client config: `DNS = 10.0.0.1` — Mac uses CoreDNS when tunnel is up
- [ ] DNS records: `grafana.internal`, `prometheus.internal`, `loki.internal`
- [ ] CoreDNS config as code in `services/coredns/Corefile`

### Observability lockdown

- [ ] Remove Grafana/Prometheus/Loki localhost port bindings from `docker-compose.yml`
- [ ] Access via tunnel only: `http://grafana.internal:3000`, `http://prometheus.internal:9090`

### Documentation

- [ ] `docs/guides/WIREGUARD_SETUP.md` — server config, peer setup, key generation, macOS client, troubleshooting, break-glass procedure
- [ ] Update SECURITY.md — new network posture, attack surface reduction
- [ ] Update INFRASTRUCTURE.md — SSH access method change
- [ ] ADR: `decisions/0009-wireguard-vpn.md`

## Backlog

Scoped, ready-to-pick-up work that doesn't belong to a phase.

- [ ] Add `Content-Security-Policy` header to Caddyfile `(security_headers)` snippet (#69)

## Ideas (unscoped)

- [ ] Staging environment — same VPS, separate ports + DB, promotion pattern
- [ ] Multi-node — second VPS, load balancing (only if traffic demands)
- [ ] HashiCorp Vault — centralized secrets with RBAC (overkill until team grows)
- [ ] Postgres tuning — `shared_buffers`, `effective_cache_size`, `work_mem` for pgvector workload on 4GB VPS
