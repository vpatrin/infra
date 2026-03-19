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

No service except Caddy has a host port binding in the base compose. Dev port bindings (PostgreSQL, Grafana, Prometheus, Alloy) are in `docker-compose.override.yml`. Production adds localhost-only bindings for SSH tunnel access to the observability stack.

---

## TLS

Caddy handles automatic HTTPS via Let's Encrypt (ACME). Certificates are auto-renewed — no manual intervention required.

- HSTS enabled automatically by Caddy on all HTTPS sites
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
| PostgreSQL | `CHOWN`, `SETUID`, `SETGID`, `DAC_OVERRIDE`, `FOWNER` | Init data directory ownership |
| Umami | (none) | Read-only filesystem + tmpfs |
| Uptime Kuma | `CHOWN`, `SETUID`, `SETGID`, `DAC_OVERRIDE` | setpriv user switch at startup |
| Loki | (none) | Log storage only |
| Prometheus | (none) | Metrics storage only |
| Alloy | `DAC_OVERRIDE`, `DAC_READ_SEARCH`, `FOWNER` | Read Docker socket + host filesystems for metrics |
| Grafana | `CHOWN`, `SETUID`, `SETGID`, `FOWNER` | Init data directory ownership |

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

### Current state

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

Backups cover PostgreSQL only. All other volumes are considered recoverable — observability data rebuilds from live sources, Caddy certs auto-renew. See [INFRASTRUCTURE.md](INFRASTRUCTURE.md#backups) for backup strategy.
