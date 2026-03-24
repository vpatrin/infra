# Ansible — VPS Provisioning

Provisions a Debian 13 (trixie) VPS from scratch. One playbook, two phases: bootstrap as root, then configure as admin.

## Quick start

```bash
cd ansible
./setup.sh              # one-time: vault password, admin password, age key
ansible-galaxy install -r requirements.yml   # pulls geerlingguy roles

# First run against a fresh VPS (unknown host key):
ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook site.yml

# Subsequent runs (host key already accepted):
ansible-playbook site.yml
```

See [setup.sh](setup.sh) for details. Requires `ansible`, `mkpasswd`, `sops` on your laptop.

## Playbook structure

```text
site.yml
  Phase 1 (root):    base → security → docker
  Phase 2 (victor):  infra
```

Phase 1 runs as root (the only user on a fresh Hetzner VPS). It creates the admin user, hardens SSH to disable root login, and installs Docker. Phase 2 reconnects as the admin user and sets up the deploy pipeline.

## Roles

### `base`

System bootstrap: sets hostname, timezone, configures swap (2G, swappiness 10), installs base apt packages (`sudo`, `curl`, `git`, `wget`, `awscli`, `needrestart`), purges leftover configs from removed packages, creates the admin user with SSH key, and creates a locked deploy user (no password, no sudo).

### `security`

Multi-layer hardening following CIS benchmarks and ANSSI-BP-028 guidelines:

- **SSH** — delegates to [geerlingguy.security](https://github.com/geerlingguy/ansible-role-security) for baseline SSH config (disable root login, password auth, empty passwords, auto-updates), then layers a custom `sshd_config.d/hardening.conf` drop-in with stricter ciphers and key exchange.
- **Firewall** — ufw: deny incoming, allow outgoing, open ports 22/80/443 only.
- **Fail2ban** — custom jail config (3 retries, 1h ban, 10m find window).
- **Kernel modules** — blacklists unused filesystems (cramfs, hfs, squashfs, etc.) and protocols (dccp, sctp, rds, tipc, usb-storage).
- **Filesystem** — mounts `/tmp` and `/dev/shm` as tmpfs with `noexec,nosuid,nodev`. Restricts permissions on shadow files.
- **Sysctl** — network anti-spoofing, SYN flood protection, disables ICMP redirects/source routing, restricts dmesg/kptr/ptrace/eBPF, protects hardlinks/symlinks/FIFOs.
- **Auditd** — logs privilege escalation, user/group changes, and network config modifications.
- **Access control** — restricts `su` to the sudo group via pam_wheel.

### `docker`

Installs Python Docker dependencies (`python3-debian`, `python3-docker`), then delegates to [geerlingguy.docker](https://github.com/geerlingguy/ansible-role-docker) which handles the Docker CE APT repo, engine install, Compose plugin, and adding users to the docker group. Daemon is configured with `json-file` log driver (10MB max, 3 files).

### `infra`

Platform deployment (runs as admin user, not root):

- Adds deploy user to the docker group, installs its SSH key for CD.
- Configures scoped sudo for deploy — limited to `systemctl daemon-reload/enable/start` and writing specific systemd units (`pg-backup`, `disk-alert`).
- Installs sops, clones infra and coupette repos, creates the Docker `internal` network and persistent volumes (`shared-postgres_pgdata`, `uptime-kuma_uptime-kuma-data`).
- Writes the SOPS age key to the deploy user's home, then runs `deploy_infra.sh` to bring up all services.

## Galaxy dependencies

Two [Jeff Geerling](https://github.com/geerlingguy) roles are used as trusted building blocks (pinned in `requirements.yml`):

| Role                                                                             | Version | Used by    | Purpose                                                |
|----------------------------------------------------------------------------------|---------|------------|--------------------------------------------------------|
| [`geerlingguy.security`](https://github.com/geerlingguy/ansible-role-security)   | 3.0.0   | `security` | SSH hardening baseline, auto-updates, fail2ban install |
| [`geerlingguy.docker`](https://github.com/geerlingguy/ansible-role-docker)       | 7.9.0   | `docker`   | Docker CE repo setup, engine + Compose plugin install  |

These roles handle the vendor-specific plumbing (APT repos, GPG keys, package names) that would be tedious and fragile to maintain ourselves. Our roles wrap them and layer project-specific config on top.

## Vault secrets

Created by `setup.sh` and encrypted with `ansible-vault`. See [vault.yml.example](group_vars/all/vault.yml.example).

| Secret | Purpose |
|--------|---------|
| `vault_sops_age_key` | Bootstrap secret — enables sops decrypt of all .env.prod.enc files |
| `vault_admin_password` | SHA-512 hash for admin user (sudo + Hetzner console break-glass) |
| `vault_admin_password_plain` | Plaintext for ansible become (sudo) |
| `vault_deploy_ssh_public_key` | Optional — deploy user SSH key for CD (follow-up issue) |

## After playbook completes

1. Update DNS in Porkbun → new VPS IP
2. Wait for Caddy to auto-issue TLS certs
3. Restore Postgres from S3 (manual)
4. Reconfigure CD with new IP (separate issue)

## Security hardening

All hardening decisions are documented with sources in [docs/SECURITY.md](../docs/SECURITY.md).
