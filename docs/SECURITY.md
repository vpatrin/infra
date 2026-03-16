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
| PostgreSQL | `127.0.0.1:5432` | Localhost only (DBeaver, Alembic) |
| Umami | `127.0.0.1:3000` | Localhost only (Caddy proxies) |
| Uptime Kuma | `127.0.0.1:3001` | Localhost only (Caddy proxies) |

No service except Caddy is reachable from the internet. PostgreSQL, Umami, and Uptime Kuma bind to `127.0.0.1` explicitly.

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

Every container in `docker-compose.yml` follows these defaults:

| Control | What it does |
| ------- | ------------ |
| `security_opt: [no-new-privileges:true]` | Prevents privilege escalation inside the container |
| `cap_drop: [ALL]` | Drops all Linux capabilities by default |
| `cap_add: [...]` | Re-adds only what each service needs (see below) |
| `mem_limit` | Hard memory ceiling per container |
| `restart: unless-stopped` | Auto-restart on crash or reboot |

### Per-service capabilities

| Service | Capabilities | Why |
| ------- | ------------ | --- |
| Caddy | `NET_BIND_SERVICE` | Bind to ports 80/443 |
| PostgreSQL | `CHOWN`, `SETUID`, `SETGID`, `DAC_OVERRIDE`, `FOWNER` | Init data directory ownership |
| Umami | (none) | Read-only filesystem + tmpfs |
| Uptime Kuma | `CHOWN`, `SETUID`, `SETGID`, `DAC_OVERRIDE` | setpriv user switch at startup |

### Additional hardening

| Service | Control | Purpose |
| ------- | ------- | ------- |
| Umami | `read_only: true` + `tmpfs: /tmp` | Immutable filesystem |
| PostgreSQL | `shm_size: 256mb` | Shared memory for query processing |
| All | `logging: max-size 10m, max-file 3` | Prevent log-based disk exhaustion |

### Memory budget

| Service | Limit | Notes |
| ------- | ----- | ----- |
| Caddy | 256m | Reverse proxy, low memory |
| PostgreSQL | 1g | pgvector with 1536-dim embeddings |
| Umami | 256m | Analytics, stateless |
| Uptime Kuma | 256m | Monitoring, SQLite-backed |
| **Total reserved** | **1.75g** | Of 4GB VPS (leaves ~2GB for apps + OS) |

---

## SSH

- Key-only authentication (`PasswordAuthentication no`, `PermitRootLogin no`)
- Single non-root user: `victor`
- Fail2ban for SSH brute-force protection

---

## Secrets Management

### Current state

Secrets live in `.env` files on the VPS, one per service (`services/<name>/.env`). All `.env` files are gitignored. Each service has a committed `.env.example` with placeholder values.

**Known limitation:** `.env` files on disk are readable by the `victor` user and Docker daemon. No encryption at rest.

### Planned (Phase 6)

Migrate to sops + age — encrypted secrets committed to the repo, decrypted at deploy time. See [ROADMAP.md](ROADMAP.md).

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
| `caddy_data` | TLS certificates | Low — auto-renewed |
| `caddy_config` | Auto-generated config | Low — regenerated |

Backups cover PostgreSQL only. Uptime Kuma and Caddy data are considered recoverable. See [INFRASTRUCTURE.md](INFRASTRUCTURE.md#backups) for backup strategy.
