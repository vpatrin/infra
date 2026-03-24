# Ansible — VPS Provisioning

Provisions a Debian 13 (trixie) VPS from scratch. One playbook, two phases: bootstrap as root, then configure as admin.

## Quick start

```bash
cd ansible
pip install passlib                          # required for password_hash on macOS
ansible-galaxy install -r requirements.yml   # pulls geerlingguy roles

# Create vault (see vault.yml.example for template):
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
# Edit vault.yml with real values, then:
ansible-vault encrypt group_vars/all/vault.yml

# First run against a fresh VPS (unknown host key):
ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook site.yml

# Subsequent runs (host key already accepted):
ansible-playbook site.yml
```

Requires `ansible` and `passlib` on your laptop. Vault password file at `~/.ansible_vault_pass`.

## Playbook structure

```text
site.yml
  Phase 1 (root):    base → security → docker
  Phase 2 (admin):   infra
```

Phase 1 runs as root (the only user on a fresh Hetzner VPS). It creates the admin user, hardens SSH to disable root login, and installs Docker. Phase 2 reconnects as the admin user and sets up the deploy pipeline.

## Roles

### `base`

System bootstrap: sets hostname, timezone, configures swap (2G, swappiness 10), installs base apt packages (`sudo`, `curl`, `git`, `wget`, `awscli`, `needrestart`, `lynis`), purges leftover configs from removed packages, reboots if a kernel upgrade is pending, creates the admin user with SSH key, and creates a locked deploy user (no password, no sudo).

### `security`

Multi-layer hardening following CIS benchmarks and ANSSI-BP-028 guidelines:

- **SSH** — delegates to [geerlingguy.security](https://github.com/geerlingguy/ansible-role-security) for baseline SSH config (disable root login, password auth, empty passwords, auto-updates), then layers a custom `sshd_config.d/hardening.conf` drop-in with stricter ciphers and key exchange.
- **Firewall** — ufw: deny incoming, allow outgoing, open ports 22/80/443 only.
- **Fail2ban** — custom jail config (3 retries, 1h ban, 10m find window).
- **Kernel modules** — blacklists unused filesystems (cramfs, hfs, squashfs, etc.) and protocols (dccp, sctp, rds, tipc).
- **Filesystem** — mounts `/tmp` and `/dev/shm` as tmpfs with `noexec,nosuid,nodev`. Restricts permissions on shadow files.
- **Sysctl** — network anti-spoofing, SYN flood protection, disables ICMP redirects/source routing, restricts dmesg/kptr/ptrace/eBPF, protects hardlinks/symlinks/FIFOs.
- **Auditd** — logs privilege escalation, user/group changes, and network config modifications.
- **Access control** — restricts `su` to the sudo group via pam_wheel.

### `docker`

Installs Python Docker dependencies (`python3-debian`, `python3-docker`), then delegates to [geerlingguy.docker](https://github.com/geerlingguy/ansible-role-docker) which handles the Docker CE APT repo, engine install, Compose plugin, and adding users to the docker group. Daemon is configured with `json-file` log driver (10MB max, 3 files).

### `infra`

Platform setup (runs as admin user, not root). Brings the VPS to a deploy-ready state — CD handles actually running the services.

- Adds admin to the deploy group (cross-user file access), installs deploy user's SSH key for CD.
- Configures scoped sudo for deploy — limited to `systemctl daemon-reload/enable/start` and writing specific systemd units (`pg-backup`, `disk-alert`).
- Installs sops, clones infra and coupette repos, creates the frontend static files directory.
- Creates the Docker `internal` network and external volumes (`shared-postgres_pgdata`, `uptime-kuma_uptime-kuma-data`) — platform prerequisites for compose stacks.

## Galaxy dependencies

Two [Jeff Geerling](https://github.com/geerlingguy) roles are used as trusted building blocks (pinned in `requirements.yml`):

| Role                                                                             | Version | Used by    | Purpose                                                |
|----------------------------------------------------------------------------------|---------|------------|--------------------------------------------------------|
| [`geerlingguy.security`](https://github.com/geerlingguy/ansible-role-security)   | 3.0.0   | `security` | SSH hardening baseline, auto-updates, fail2ban install |
| [`geerlingguy.docker`](https://github.com/geerlingguy/ansible-role-docker)       | 7.9.0   | `docker`   | Docker CE repo setup, engine + Compose plugin install  |

These roles handle the vendor-specific plumbing (APT repos, GPG keys, package names) that would be tedious and fragile to maintain ourselves. Our roles wrap them and layer project-specific config on top.

## Vault secrets

Encrypted with `ansible-vault`. See [vault.yml.example](group_vars/all/vault.yml.example).

| Secret | Purpose |
|--------|---------|
| `vault_admin_password_plain` | Admin password — hashed at runtime for user creation, plaintext for ansible become (sudo) |
| `vault_deploy_ssh_public_key` | Deploy user SSH public key for CD access |

## After playbook completes

1. Add SSH host alias to `~/.ssh/config` on your laptop:

   ```text
   Host web-01
       HostName <vps-ip>
       User admin
       IdentityFile ~/.ssh/id_ed25519
   ```

2. Update `SSH_DEPLOY_HOST` GitHub Actions secret with new VPS IP
3. Update DNS in Porkbun → new VPS IP
4. Wait for Caddy to auto-issue TLS certs
5. Trigger CD: `gh workflow run deploy` on infra, then coupette
6. Restore Postgres from S3 backup (manual)

## Security hardening

All hardening decisions are documented with sources in [docs/SECURITY.md](../docs/SECURITY.md).
