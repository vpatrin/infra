# Security

Platform-level security posture. Application-level security (auth, JWT, rate limiting) lives in each app repo.

---

## Network

### Firewall (two layers)

1. **Hetzner cloud firewall** — applied at the network edge before traffic reaches the VPS. Only ports 22, 80, 443 open.
2. **ufw on the VPS** — defense in depth. Same port allowlist: 22, 80, 443.

### Docker network isolation

All services communicate over a shared Docker network (`internal`). Only Caddy binds to host ports 80/443 — everything else is internal-only.

| Service | Host binding | Accessible from |
| ------- | ------------ | --------------- |
| Caddy | `0.0.0.0:80`, `0.0.0.0:443` | Internet |
| All others | — | Internal network only |

No service except Caddy has a host port binding in the base compose. Dev port bindings (PostgreSQL, Grafana, Prometheus, Alloy) are in `docker-compose.dev.yml`. Production adds localhost-only bindings for SSH tunnel access to the observability stack.

---

## TLS

Caddy handles automatic HTTPS via Let's Encrypt (ACME). Certificates are auto-renewed — no manual intervention required.

- HSTS with 2-year max-age (`max-age=63072000; includeSubDomains`)
- HTTP → HTTPS redirect handled automatically

---

## Response Headers

Applied to all sites via a shared Caddyfile snippet:

| Header | Value | Purpose |
| ------ | ----- | ------- |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME-sniffing |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disable unused browser APIs |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | Force HTTPS for 2 years |
| `X-XSS-Protection` | `0` | Disable deprecated XSS auditor |
| `Content-Security-Policy` | per-site (see Caddyfile) | Restrict resource origins |
| `Server` | (removed) | Prevent server fingerprinting |

---

## Container Hardening

Every container in `docker-compose.yml` follows these security defaults:

| Control | Where | What it does |
| ------- | ----- | ------------ |
| `security_opt: [no-new-privileges:true]` | Base | Prevents privilege escalation inside the container |
| `cap_drop: [ALL]` | Base | Drops all Linux capabilities by default |
| `cap_add: [...]` | Base | Re-adds only what each service needs (see below) |
| `logging` (rotation) | Base | Prevents log-based disk exhaustion |
| `mem_limit` | Prod override | Hard memory ceiling per container |
| `restart: unless-stopped` | Prod override | Auto-restart on crash or reboot |

### Per-service capabilities

| Service | Capabilities | Why |
| ------- | ------------ | --- |
| Caddy | `NET_BIND_SERVICE` | Bind to ports 80/443 |
| PostgreSQL | `SETUID`, `SETGID`, `DAC_READ_SEARCH`, `CHOWN`, `FOWNER` | Init data directory ownership (external volume) |
| Umami | (none) | Read-only filesystem + tmpfs |
| Uptime Kuma | (none) | Runs as root, no privilege drop |
| Loki | (none) | Log storage only |
| Prometheus | (none) | Metrics storage only |
| Alloy | `DAC_READ_SEARCH`, `DAC_OVERRIDE` | Read Docker socket + host filesystems for metrics |
| Grafana | (none) | Runs as uid 472, dirs pre-set at build time |

### Additional hardening

| Service | Control | Purpose |
| ------- | ------- | ------- |
| Umami | `read_only: true` + `tmpfs: /tmp` | Immutable filesystem |
| PostgreSQL | `shm_size: 256mb` | Shared memory for query processing |
| All infra services | `logging: max-size 10m, max-file 3` | Prevent log-based disk exhaustion |

### Memory budget

| Service | Limit | Notes |
| ------- | ----- | ----- |
| Caddy | 256m | Reverse proxy, low memory |
| PostgreSQL | 1g | pgvector with 1536-dim embeddings |
| Umami | 512m | Analytics, stateless |
| Uptime Kuma | 256m | Monitoring, SQLite-backed |
| Loki | 512m | Log aggregation |
| Prometheus | 512m | Metrics storage (7d retention) |
| Alloy | 256m | Log + metrics collector |
| Grafana | 256m | Dashboards + visualization |
| **Total reserved** | **3.5g** | Of 4GB VPS (leaves ~0.5GB for apps + OS) |

---

## SSH

- Key-only authentication (`PasswordAuthentication no`, `PermitRootLogin no`)
- Single non-root user: `victor`
- Fail2ban for SSH brute-force protection

---

## Secrets Management

Production secrets are encrypted with sops + age and committed as `.env.prod.enc` files per service. The deploy script decrypts them at deploy time using `SOPS_AGE_KEY` from the environment. Decrypted `.env.prod` files are created with `umask 077` (owner-only).

Development `.env` files live on disk (gitignored). Each service has a committed `.env.example` with placeholder values.

---

## CI Scanning

| Tool | Scope | Trigger |
| ---- | ----- | ------- |
| gitleaks | Secrets in committed code | PR |
| ShellCheck | Shell script safety | PR |
| `docker compose config` | Compose syntax validation | PR |
| Dependabot | Docker image + GitHub Actions updates | Weekly |

---

## Volume Security

Stateful data lives in Docker volumes. Two volumes are `external: true` (pre-existing, not recreated on `docker compose down`):

| Volume | Data | Risk if lost |
| ------ | ---- | ------------ |
| `shared-postgres_pgdata` | All databases (coupette, umami) | **High** — user data, product catalog, analytics |
| `uptime-kuma_uptime-kuma-data` | Monitoring config + history | Medium — reconfigurable |
| `grafana_data` | Dashboards + preferences | Low — dashboards should be provisioned as code |
| `prometheus_data` | Metrics (7d retention) | Low — rebuilt from scrape targets |
| `loki_data` | Logs (7d retention) | Low — rebuilt from Docker log tailing |
| `alloy_data` | Collector WAL | Low — transient, rebuilt on restart |
| `caddy_data` | TLS certificates | Low — auto-renewed |
| `caddy_config` | Auto-generated config | Low — regenerated |

Backups cover PostgreSQL only. All other volumes are considered recoverable — observability data rebuilds from live sources, Caddy certs auto-renew. See [ARCHITECTURE.md](ARCHITECTURE.md#backups) for backup strategy.

---

## Security Log

### 2026-03-09 — Container hardening (#14)

**Context:** All containers ran with default capabilities — full Linux capability set, no memory limits, no log rotation.
**Action:** Added `cap_drop: ALL` + minimal `cap_add`, `no-new-privileges`, log rotation (10MB × 3), healthchecks to every service. Umami set to `read_only: true`.
**Result:** Zero capabilities for most containers. Only Caddy (`NET_BIND_SERVICE`), PostgreSQL (`SETUID/SETGID/CHOWN/FOWNER/DAC_READ_SEARCH`), and Alloy (`DAC_READ_SEARCH/DAC_OVERRIDE`) have caps.

### 2026-03-09 — Security headers (#12)

**Context:** Caddy served traffic with no security headers — no HSTS, no CSP, no clickjacking protection.
**Action:** Added shared Caddyfile snippet with HSTS (2yr), X-Frame-Options DENY, CSP, Referrer-Policy, Permissions-Policy. Removed Server header.
**Result:** All sites behind Caddy inherit security headers. Per-site CSP overrides where needed.

### 2026-03-16 — Service consolidation (#23, #25)

**Context:** PostgreSQL, Umami, and Uptime Kuma ran as separate repos with inconsistent security posture.
**Action:** Absorbed all services into single repo. Applied uniform hardening (cap_drop, no-new-privileges, log rotation) across all containers.
**Result:** Single security baseline for all platform services.

### 2026-03-17 — Push monitor credentials (#39)

**Context:** Push monitor URLs (Uptime Kuma heartbeat endpoints) needed to be accessible to systemd timers without being in the repo.
**Action:** Stored push URLs in `/etc/push-monitor/<job>.env` (root-owned, `0600`). Systemd units load via `EnvironmentFile`.
**Result:** Credentials isolated from repo, readable only by root/systemd.

### 2026-03-18 — sops + age secrets management (#45, #46)

**Context:** Production `.env` files lived on the VPS with no encryption, no version control, no audit trail. Losing the VPS meant losing all secrets.
**Action:** Encrypted all production secrets with sops + age, committed as `.env.prod.enc`. Deploy script decrypts at deploy time with `SOPS_AGE_KEY`. Decrypted files created with `umask 077`.
**Result:** Secrets are version-controlled (encrypted), recoverable from git, and deploy-time only on disk.

### 2026-03-18 — Deploy user isolation (#44)

**Context:** CI deploys ran as `victor` (admin user) — overprivileged for automated workloads.
**Action:** Created dedicated `deploy` system user with scoped sudo (systemd commands only). Dedicated ed25519 SSH deploy key for GitHub Actions.
**Result:** CI workloads run with minimal privileges. Admin and automation are separate users.

### 2026-03-19 — Observability stack security (#75)

**Context:** Alloy needs host filesystem access (`/proc`, `/sys`, `/`) for node metrics and Docker socket for log collection — broad attack surface.
**Action:** `read_only: true`, `no-new-privileges`, `cap_drop: ALL` + only `DAC_READ_SEARCH/DAC_OVERRIDE`. Docker socket mounted read-only. All observability services internal-only (no host port bindings in base compose).
**Result:** Observability stack has no internet exposure. Alloy's host access is read-only with minimal capabilities.

### 2026-03-21 — Per-site CSP headers (#92)

**Context:** All sites shared a single CSP policy. Coupette needed `unsafe-eval` for a Telegram widget, but other sites shouldn't have it.
**Action:** Moved CSP to per-site configuration in Caddyfile. Each domain block defines its own CSP policy.
**Result:** Tighter CSP per site. Only coupette.club allows `unsafe-eval`.
