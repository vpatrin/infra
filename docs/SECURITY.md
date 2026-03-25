# Security

Platform-level security posture. Application-level security (auth, JWT, rate limiting) lives in each app repo.

**Lynis: 80/100** (baseline Debian 13: 64) | **ssh-audit: clean** (post-quantum KEX, AEAD-only, ETM MACs) | **testssl.sh: A+** (96/100). Hardening is codified in the Ansible `security` role and validated on every fresh provision.

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

Configured via geerlingguy.security + `/etc/ssh/sshd_config.d/hardening.conf` (Ansible `security` role).

| Control | Value | Source |
| ------- | ----- | ------ |
| Key-only auth | `PasswordAuthentication no`, `PermitRootLogin no` | CIS 5.3.1, 5.3.2 |
| Post-quantum KEX | `mlkem768x25519-sha256`, curve25519 | [ssh-audit.com](https://www.sshaudit.com/hardening_guides.html), ANSSI-BP-028 R67 |
| AEAD ciphers only | chacha20-poly1305, aes256-gcm, aes128-gcm | CIS 5.3.14 |
| ETM MACs only | hmac-sha2-512-etm, hmac-sha2-256-etm | CIS 5.3.15 |
| AllowUsers | `admin deploy` | ANSSI-BP-028 R37 |
| MaxAuthTries | 3 | CIS 5.3.5 |
| Session timeout | ClientAliveInterval 300s, CountMax 2 | CIS 5.3.18 |
| Verbose logging | LogLevel VERBOSE | ANSSI-BP-028 R67 |
| Fail2ban | 3 retries, 1h ban, 10m window | CIS 5.3.5, practical choice |

OpenSSH 10.0 (Debian 13) removed `ChallengeResponseAuthentication` — replaced by `KbdInteractiveAuthentication`.

---

## Kernel Hardening

Sysctl parameters in `/etc/sysctl.d/99-hardening.conf` (Ansible `security` role). Not `/etc/sysctl.conf` — [deprecated in Debian 13](https://blog.gudynas.lt/2025/10/04/debian-13-trixie-sysctl-tutorial/).

| Parameter | Value | Source |
| --------- | ----- | ------ |
| net.ipv4.conf.all.rp_filter | 1 | CIS 3.3.7 — anti-spoofing |
| net.ipv4.conf.all.accept_redirects | 0 | CIS 3.3.2 — ICMP redirect MITM prevention |
| net.ipv4.conf.all.send_redirects | 0 | CIS 3.3.1 — not a router |
| net.ipv4.tcp_syncookies | 1 | CIS 3.3.8 — SYN flood protection |
| kernel.dmesg_restrict | 1 | ANSSI-BP-028 Enhanced — prevent info leakage |
| kernel.kptr_restrict | 2 | ANSSI-BP-028 Enhanced — hide kernel pointers |
| kernel.yama.ptrace_scope | 2 | ANSSI-BP-028 Enhanced — restrict ptrace to root |
| kernel.unprivileged_bpf_disabled | 1 | dev-sec — block eBPF exploits |
| fs.suid_dumpable | 0 | CIS 1.5.1 — no core dumps from SUID |
| fs.protected_hardlinks/symlinks | 1 | CIS 1.6.1 — link-based attack prevention |

`net.ipv4.ip_forward` stays `1` — required for Docker networking (CIS recommends `0` but Docker breaks without it).

### Kernel module blacklist (CIS 1.1.1.x, 3.5.x)

Unused filesystem and network protocol modules are blacklisted via `/etc/modprobe.d/hardening.conf`: cramfs, freevxfs, hfs, hfsplus, jffs2, squashfs, udf, dccp, sctp, rds, tipc. Reduces kernel attack surface — none of these are needed on a Docker VPS.

### Access control

| Control | Source |
| ------- | ------ |
| `su` restricted to sudo group via `pam_wheel.so` | CIS 5.7, ANSSI-BP-028 R39 |
| `/etc/shadow`, `/etc/gshadow` set to `0640` | CIS 6.1.x |

---

## Filesystem Hardening

Mount options applied by Ansible `security` role.

| Mount | Options | Source |
| ----- | ------- | ------ |
| /tmp | noexec,nosuid,nodev (tmpfs 512m) | CIS 1.1.2-1.1.5 — blocks execution from temp dirs |
| /dev/shm | noexec,nosuid,nodev | CIS 1.1.8-1.1.10 — shared memory abuse prevention |

---

## Audit Logging

`auditd` with immutable rules in `/etc/audit/rules.d/hardening.rules` (Ansible `security` role).

| Audited path | Source |
| ------------ | ------ |
| /etc/passwd, shadow, group, gshadow | CIS 4.1.4 — identity file tampering |
| /etc/sudoers, sudoers.d/ | CIS 4.1.8 — privilege escalation config |
| /usr/bin/sudo, /usr/bin/su | CIS 4.1.11 — privileged command execution |
| /var/run/docker.sock | Custom — unauthorized Docker API access |
| /etc/ssh/sshd_config* | Custom — SSH config tampering |
| `-e 2` (immutable rules) | CIS 4.1.18 — requires reboot to change |

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
| ansible-lint | Ansible playbook quality | PR |
| `docker compose config` | Compose syntax validation | PR |
| Dependabot | Docker image + GitHub Actions updates | Weekly |

---

## Security Auditing

Run after provisioning or major changes to validate hardening.

| Tool | Layer | How to run | Target |
| ---- | ----- | ---------- | ------ |
| [Lynis](https://cisofy.com/lynis/) | OS hardening | `sudo lynis audit system` (installed on VPS) | 80+ |
| [ssh-audit](https://github.com/jtesta/ssh-audit) | SSH crypto | `ssh-audit <vps-ip>` (run from laptop) | No warnings |
| [testssl.sh](https://testssl.sh/) | TLS/HTTPS | `docker run --rm drwetter/testssl.sh https://victorpatrin.dev` | A+ |

---

## Automatic Updates & Maintenance Window

Security patches are applied automatically. The maintenance window is **6:00–7:00 UTC** — the only time services or the kernel may restart.

### How it works

| Event | Handler | Impact | When |
| ----- | ------- | ------ | ---- |
| Library/package security patch | `unattended-upgrades` installs, `needrestart` auto-restarts affected services | Brief service blip (~seconds) | ~6:00–7:00 UTC (apt-daily-upgrade.timer + 60m random delay) |
| Kernel security update | `unattended-upgrades` installs, auto-reboot at 07:00 UTC | Full reboot, ~60s downtime, containers restart via `unless-stopped` | 07:00 UTC |
| Manual `apt install/upgrade` | `needrestart` auto-restarts affected services immediately | Brief service blip | Whenever you run apt |

### Configuration (Ansible `security` role via geerlingguy.security)

- `security_autoupdate_enabled: true` — unattended-upgrades active
- `security_autoupdate_reboot: true` — auto-reboot after kernel updates
- `security_autoupdate_reboot_time: "07:00"` — reboot after apt finishes (~6:00–7:00 UTC)
- `needrestart` mode `'a'` (automatic) — restarts services without prompting after apt

### Accepted risks

- **Brief downtime during maintenance window (~6:00–7:00 UTC):** containers restart automatically, but there's a brief window where services are unavailable. Acceptable for a solo-dev VPS with no SLA.
- **Manual apt during the day:** if you SSH in and run `apt upgrade`, needrestart may restart services immediately. Be aware when running apt manually.
- **No drain/health-check before restart:** unlike K3s with `kured`, there's no graceful pod draining. Services stop and start. At this scale, this is fine.

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
**Action:** Added `cap_drop: ALL` + minimal `cap_add`, `no-new-privileges`, log rotation (10MB × 3), healthchecks to every service. Umami set to `read_only: true`. Only three services retain caps: Caddy (`NET_BIND_SERVICE`), PostgreSQL (`SETUID/SETGID/CHOWN/FOWNER/DAC_READ_SEARCH`), Alloy (`DAC_READ_SEARCH/DAC_OVERRIDE`).

### 2026-03-09 — Security headers (#12)

**Context:** Caddy served traffic with no security headers — no HSTS, no CSP, no clickjacking protection.
**Action:** Added shared Caddyfile snippet with HSTS (2yr), X-Frame-Options DENY, CSP, Referrer-Policy, Permissions-Policy. Removed Server header. All sites inherit via `import security_headers`; per-site CSP overrides where needed.

### 2026-03-16 — Service consolidation (#23, #25)

**Context:** PostgreSQL, Umami, and Uptime Kuma ran as separate repos with inconsistent security posture.
**Action:** Absorbed all services into single repo. Applied uniform hardening (cap_drop, no-new-privileges, log rotation) across all containers.

### 2026-03-17 — Push monitor credentials (#39)

**Context:** Push monitor URLs (Uptime Kuma heartbeat endpoints) needed to be accessible to systemd timers without being in the repo.
**Action:** Stored push URLs in `/etc/push-monitor/<job>.env` (root-owned, `0600`). Systemd units load via `EnvironmentFile`.

### 2026-03-18 — sops + age secrets management (#45, #46)

**Context:** Production `.env` files lived on the VPS with no encryption, no version control, no audit trail. Losing the VPS meant losing all secrets.
**Action:** Encrypted all production secrets with sops + age, committed as `.env.prod.enc`. Deploy script decrypts at deploy time with `SOPS_AGE_KEY`. Decrypted files created with `umask 077`. Secrets now version-controlled (encrypted), recoverable from git, deploy-time only on disk.

### 2026-03-18 — Deploy user isolation (#44)

**Context:** CI deploys ran as the admin user — overprivileged for automated workloads.
**Action:** Created dedicated `deploy` system user with scoped sudo (systemd commands only). Dedicated ed25519 SSH deploy key for GitHub Actions. Admin (`admin`) and automation (`deploy`) are now separate users with separate privilege sets.

### 2026-03-19 — Observability stack security (#75)

**Context:** Alloy needs host filesystem access (`/proc`, `/sys`, `/`) for node metrics and Docker socket for log collection — broad attack surface.
**Action:** `read_only: true`, `no-new-privileges`, `cap_drop: ALL` + only `DAC_READ_SEARCH/DAC_OVERRIDE`. Docker socket mounted read-only. All observability services internal-only — no host port bindings in base compose, no internet exposure.

### 2026-03-21 — Per-site CSP headers (#92)

**Context:** All sites shared a single CSP policy. Coupette needed `unsafe-eval` for a Telegram widget, but other sites shouldn't have it.
**Action:** Moved CSP to per-site configuration in Caddyfile. Each domain block defines its own CSP policy — only `coupette.club` allows `unsafe-eval`.

### 2026-03-23 — Ansible server hardening

**Context:** VPS provisioning was manual (VPS_SETUP_GUIDE.md). No kernel sysctl hardening, no SSH crypto pinning, no filesystem mount hardening, no audit logging.
**Action:** Ansible playbook codifies full VPS setup. Added: sysctl hardening (28 parameters from CIS/ANSSI/dev-sec/Lynis), SSH crypto pinning (post-quantum KEX, AEAD-only ciphers, ETM MACs, AllowUsers), `/tmp` and `/dev/shm` noexec mounts, `auditd` with immutable rules covering identity files, sudoers, Docker socket, and SSH config. Validated with Lynis audit: baseline Debian 13 scores 64/100, after hardening 80/100 (+16). Remaining suggestions triaged — most are noise at single-VPS scale (GRUB password, separate partitions, password aging on key-only users). Sources: CIS Debian Linux Benchmark, ANSSI-BP-028 v2.0, dev-sec.io baselines, ssh-audit.com, Lynis 3.1.4.

---

## Accepted Risks

- **Deploy user in Docker group is root-equivalent:** required for `docker compose` — mitigated by SSH key in vault, fail2ban, AllowUsers, and auditd on the Docker socket. Goes away with K3s migration (Phase 7).
- **Deploy user has scoped sudo to write systemd units:** `tee` to 4 specific unit file paths. Doesn't expand blast radius beyond Docker group membership. Scoped to `pg-backup` and `disk-alert` units only.

---

## References

- [CIS Debian Linux Benchmark](https://www.cisecurity.org/benchmark/debian_linux) — Level 1 and Level 2 controls
- [ANSSI-BP-028 v2.0](https://cyber.gouv.fr/publications/configuration-recommendations-gnulinux-system) — French cybersecurity agency Linux hardening guide
- [dev-sec.io Linux Baseline](https://dev-sec.io/baselines/linux/) — Ansible/InSpec hardening framework
- [dev-sec.io SSH Baseline](https://dev-sec.io/baselines/ssh/)
- [ssh-audit.com hardening guides](https://www.sshaudit.com/hardening_guides.html) — Algorithm-specific SSH configuration
- [OVH debian-cis](https://github.com/ovh/debian-cis) — CIS benchmark scripts for Debian
