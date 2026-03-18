<!-- Based on https://github.com/joelparkerhenderson/architecture-decision-record (MADR) -->

# ADR 0007: Continuous Deployment Strategy

**Date:** 2026-03-18
**Status:** Accepted

---

## Context

The platform has no automated deployment pipeline. All deploys — infra and app — are manual: SSH into web-01, run scripts, copy files. Secrets live only on the VPS filesystem with no version control or recovery path.

## Decision Drivers

- Solo developer — complexity must stay proportional to scale
- Public repo — no secrets can be committed unencrypted
- Security posture — CI should not use personal SSH keys or hold prod credentials in plaintext
- CD must be fully automated — tag push = deployed, no manual steps
- K3s migration is planned (Phase 6) — decisions should not block that path

---

## Decisions

### 1. Dedicated `deploy` user for CI

**Decision:** Create a `deploy` system user on the VPS. GitHub Actions authenticates as `deploy`, not as `victor`.

**Options considered:**
- **Personal key (`victor`)** — simpler, already works. Rejected: personal account in CI is a security anti-pattern. Compromise = full VPS access.
- **`deploy` user (chosen)** — scoped permissions, separate key, independently revocable. Industry standard (principle of least privilege).

**Consequences:** Repos live under `/home/deploy/`. Scripts and systemd unit paths reference `/home/deploy/`. `victor` retains full admin access for manual operations. `/opt/coupette` symlink updated to `/home/deploy/projects/coupette`.

**Repo layout:**

| Path | Owner | Contents |
| --- | --- | --- |
| `/home/deploy/infra/` | `deploy` | infra repo |
| `/home/deploy/projects/coupette/` | `deploy` | coupette repo |
| `/opt/coupette` | symlink | → `/home/deploy/projects/coupette` |
| `/srv/coupette/` | `deploy` | frontend static files |
| `/home/victor/` | `victor` | personal admin, unchanged |

---

### 2. SSH deploy key (ed25519, no passphrase)

**Decision:** Dedicated `github_actions_deploy` ed25519 key. Private key in GitHub Actions secrets. Public key in `deploy` user's `authorized_keys`.

**Options considered:**

- **Personal `id_ed25519`** — already on VPS. Rejected: personal key in CI is a security anti-pattern.
- **Passphrase-protected deploy key** — requires `ssh-agent` in CI. Rejected: added complexity, no real gain since GitHub's secret storage already encrypts at rest.
- **No-passphrase deploy key (chosen)** — conventional for CI deploy keys.

**GitHub Actions secrets (both repos):**

- `SSH_DEPLOY_KEY` — private key
- `SSH_DEPLOY_HOST` — VPS IP
- `SSH_DEPLOY_USER` — `deploy`

---

### 3. Idempotent deploy scripts

**Decision:** Two scripts own their respective deploy surfaces. Both are safe to re-run. `victor` can run them manually; CI runs them as `deploy`.

**`deploy_infra.sh`** (infra repo):

- `git pull` latest infra repo
- `docker compose pull` + `docker compose up -d`
- Caddy validate + reload
- Sync infra systemd units (pg-backup, disk-alert) + `daemon-reload` if changed

**`deploy.sh`** (coupette repo, extended from existing):

- Pull image, pre-deploy backup, migrate, compose up, healthcheck
- Sync coupette systemd units (scraper, availability) + `daemon-reload` if changed

---

### 4. GitHub Actions workflows

**Infra** — manual dispatch only:
```
workflow_dispatch
  → validate Caddyfile + docker-compose.yml
  → SSH as deploy → deploy_infra.sh
```

Rationale: infra changes are rare and high-impact. Victor explicitly triggers deploys after merging — merge ≠ immediate deploy.

**Coupette** — tag push:
```
git tag v1.x.x + push
  → build images → push GHCR
  → build frontend → scp → /srv/coupette
  → SSH as deploy → deploy.sh v1.x.x
```

Rationale: a tag expresses intent to deploy. Fully automated.

---

### 5. Secrets management — sops + age

**Decision:** Encrypt `.env` files with sops + age. Encrypted files committed to their respective repos. Two age recipients per file: laptop key (DR) and GitHub Actions key (CD).

**Options considered:**

- **Plaintext `.env` on VPS only** — current state. No automation possible, lost on VPS death.
- **Raw AES256 (`openssl enc`)** — simple but opaque. Whole file is an unreadable blob, no diff readability. Not a standard.
- **Ansible vault only** — laptop-driven, cannot be used in automated CD without storing the vault password in GitHub. Rejected for CD.
- **GitHub Actions secrets per credential** — spreads secrets across GitHub UI, hard to audit and rotate. Rejected.
- **sops + age (chosen)** — industry standard for GitOps. Keys visible in diff, values encrypted. Single encrypted file, multiple recipients. Works for both CD (GitHub Actions age key) and DR (laptop age key). Natural path to K3s/Flux.

**Layout:**
```
services/postgres/.env.prod.enc    # sops encrypted
services/umami/.env.prod.enc
services/coupette/.env.prod.enc    # coupette secrets
.sops.yaml                         # public age keys, committed to repo
```

**Recipients:**

- `age_laptop` — Victor's laptop key (DR — manual decrypt or Ansible)
- `age_github` — age private key stored as GitHub Actions secret (CD — decrypt at deploy time)

Implemented at the end of Phase 4, after CD pipeline structure is in place.

---

## Consequences

**Easier:**

- Deploys require no manual SSH for routine operations
- Secrets are version-controlled, auditable, and rotatable without VPS access
- K3s migration is unblocked — sops+age is the GitOps standard

**Harder:**

- Secret rotation requires updating encrypted files + committing
- Two age keys to manage (laptop + GitHub Actions)

**Deferred to Phase 6 (K3s):**

- Helm-based CD replaces GitHub Actions SSH deploy pattern
- GitOps (Flux image automation) replaces tag-triggered workflows
- `deploy_infra.sh` and `deploy.sh` retired

**See also:** ADR 0008 — Disaster Recovery Strategy (Phase 5)
