# ADR 0007: Continuous Deployment Strategy

**Date:** 2026-03-18
**Status:** Accepted

## Context

All deploys are manual: SSH into web-01, run scripts, copy files. Secrets live only on the VPS filesystem with no version control or recovery path. Public repo means no secrets can be committed unencrypted. CD must be fully automated — tag push = deployed.

## Options considered

1. **Keep manual deploys** — simple, but doesn't scale. Secrets not recoverable if VPS dies. Error-prone for routine operations.
2. **GitHub Actions + sops/age** — CI runs deploy scripts via SSH. Dedicated deploy user with scoped permissions. Secrets encrypted with sops + age, committed to repo. Two age recipients: laptop (DR) and GitHub Actions (CD).

## Decision

Automated CD via GitHub Actions with a dedicated `deploy` user, SSH deploy key, idempotent deploy scripts, and sops + age for secrets management.

**Deploy user:** `deploy` system user with scoped sudo (systemd commands only). Separate from `admin` (human SSH/sudo). Dedicated `github_actions_deploy` ed25519 key stored as GitHub Actions secret.

**Deploy scripts:**
- `deploy_infra.sh` — pull, compose up, Caddy validate + reload, sync systemd units. Triggered manually via workflow dispatch.
- `deploy.sh` (coupette) — pull image, backup, migrate, compose up, healthcheck. Triggered on tag push.

**Secrets:** `.env.prod.enc` files encrypted with sops + age. Two recipients per file: laptop key (DR) and GitHub Actions key (CD). Deploy script decrypts at deploy time with `SOPS_AGE_KEY`. Decrypted files created with `umask 077`.

## Rationale

- Deploys require no manual SSH for routine operations
- Secrets are version-controlled (encrypted), auditable, and recoverable from git
- sops + age is the GitOps standard — natural path to K3s/Flux
- Principle of least privilege — CI runs as `deploy`, not as personal admin user

## Consequences

- Secret rotation requires updating encrypted files + committing. Two age keys to manage (laptop + GitHub Actions).
- Infra deploys are manual dispatch (merge ≠ immediate deploy). Coupette deploys are tag-triggered (fully automated).
- Phase 6 (K3s) will replace SSH-based deploy with Helm + Flux, retiring both deploy scripts.
