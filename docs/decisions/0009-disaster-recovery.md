# ADR 0009: Disaster Recovery Strategy

**Date:** 2026-03-22
**Status:** Accepted

## Context

web-01 (Hetzner CX22) is a single point of failure. If the VPS dies — hardware failure, account issue, bad deploy — recovery is manual: re-provision via Hetzner console, walk through a 17-step VPS setup guide, restore Postgres from local backups that live on the same disk. Local backups don't survive disk failure. There's no tested recovery path.

The platform now runs 8 containers (Caddy, Postgres, Umami, Uptime Kuma, Grafana, Loki, Prometheus, Alloy) plus coupette's app services. Manual recovery would take hours and is error-prone.

## Options considered

1. **Improve the runbook** — keep manual setup, just document it better. Zero automation cost, but recovery time stays at 2-4 hours and depends on operator memory under stress. Doesn't solve the offsite backup problem.

2. **Offsite backups only** — upload Postgres dumps to cloud storage, keep manual provisioning. Solves data loss but recovery still requires 17 manual steps. The most valuable single change, but leaves automation on the table.

3. **Terraform + Ansible + offsite backups** — automate VPS provisioning (Terraform) and server configuration (Ansible), store backups off-provider (AWS S3). Recovery becomes: `terraform apply`, `ansible-playbook site.yml`, restore Postgres, update DNS. Tested end-to-end with a throwaway VPS.

4. **Full GitOps (K3s + Flux)** — skip Compose-era DR, go straight to Kubernetes with declarative everything. Solves DR but introduces K3s complexity before the platform needs it. Over-engineers the current single-VPS setup.

## Decision

Option 3: Terraform + Ansible + offsite backups.

- **Backups → AWS S3** for provider diversity. If Hetzner has an outage or account issue, backups survive. No local retention — S3 is the primary store. 3-tier retention: daily 7d, weekly 4w, monthly 3m.
- **Terraform → Hetzner API** for VPS provisioning. State stored in Hetzner Object Storage (provisioning Hetzner infra, so state stays with the provider). Bucket created manually (one-time, like DNS).
- **Ansible → fresh VPS** for full server configuration. 5 roles: base, security, docker, infra, timers. Ansible vault for bootstrap secrets (`~/.ansible_vault_pass`). App secrets stay in sops-encrypted `.env.prod.enc` files — Ansible places the age key, future deploys decrypt.
- **Ansible scope is DR only.** It provisions a fresh server. It does not handle ongoing CD (that's GitHub Actions) or app deploys (that's coupette's own CI/CD).

### Manual vs automated boundary

```
MANUAL (one-time or rare)
  AWS S3 bucket creation
  Hetzner Object Storage bucket creation
  Porkbun DNS update (A record → new VPS IP)
  ~/.ansible_vault_pass (from password manager)
  Postgres restore from S3 (verified before DNS cutover)

TERRAFORM (laptop → Hetzner API)
  VPS (Debian 13, CX22)
  Cloud firewall (22, 80, 443)
  SSH key registration
  → outputs: VPS IP

ANSIBLE (laptop → fresh VPS)
  OS: swap, timezone, locale, log rotation
  Security: SSH hardening, fail2ban, ufw
  Docker: Docker CE + Compose plugin
  Infra: clone repos, internal network, external volumes,
         place age key, sops decrypt, compose up
  Timers: pg-backup, disk-alert systemd units

APP-OWNED (after infra is up)
  Coupette deploy (tag-push → GitHub Actions)
```

### RTO/RPO targets

- **RPO (data loss):** ≤ 24 hours. Daily Postgres dumps to S3. Acceptable — the app is a wine recommender, not a payment system.
- **RTO (recovery time):** < 1 hour. Terraform + Ansible + restore + DNS. Manual recovery would take hours.

## Rationale

- Provider diversity: AWS S3 for backups survives a Hetzner outage. Terraform state in Hetzner Object Storage is fine — if Hetzner is down, you can't provision there anyway.
- Ansible codifies the VPS setup guide as a runnable artifact. The 17-step manual process becomes a playbook that's tested against a throwaway VPS before it's needed.
- Keeping Ansible scoped to DR avoids the complexity of Ansible-as-CD. GitHub Actions SSH-based deploy already works for both repos.
- `aws-cli` for S3 uploads is a first step into AWS tooling — transferable skills.
- Fail-loud backup script (exit non-zero on upload failure) ensures Uptime Kuma alerts on backup problems.

## Consequences

- Two new directories (`terraform/`, `ansible/`) to maintain. CI gates (`terraform validate`, `ansible-lint`) prevent rot.
- AWS account required (free tier covers S3 for this volume). Separate bill from Hetzner.
- Hetzner Object Storage bucket required for Terraform state. Manual one-time creation.
- Ansible vault password is a new secret to manage (password manager only, `~/.ansible_vault_pass` on laptop).
- DR test costs ~€0.02 (a CX22 for 1-2 hours). Should be re-run after major infrastructure changes.
- Raspberry Pi home storage planned as a future secondary backup target (not in this phase).
