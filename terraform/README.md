# Terraform — Hetzner VPS Provisioning

Provisions a Hetzner Cloud VPS for disaster recovery. **Does NOT manage web-01** — this config creates new servers only.

## Credentials

| Credential | Scope | Where to get it |
|------------|-------|-----------------|
| `HCLOUD_TOKEN` | **Project** — controls which servers you manage | Hetzner Console → Project → Security → API Tokens |
| `AWS_ACCESS_KEY_ID` | **Account** — works across all projects | Hetzner Console → Object Storage → S3 Credentials |
| `AWS_SECRET_ACCESS_KEY` | **Account** — same as above | Hetzner Console → Object Storage → S3 Credentials |

Switching projects = swap `HCLOUD_TOKEN` only. S3 credentials stay the same.

## Variables

Override any variable with `-var="name=value"` on `plan` or `apply`.

| Variable | Default | Description |
|----------|---------|-------------|
| `server_name` | `web-01` | Server hostname |
| `server_type` | `cx23` | Hetzner plan (cx22, cx23, cx32...) |
| `location` | `hel1` | Datacenter (hel1=Helsinki, nbg1=Nuremberg, fsn1=Falkenstein) |
| `image` | `debian-13` | OS image |
| `ssh_key_name` | `victor-laptop` | SSH key name in Hetzner Console (must match exactly) |
| `firewall_name` | `web-firewall` | Cloud firewall name |
| `ingress_ports` | `["22", "80", "443"]` | Allowed inbound TCP ports |
| `backups` | `true` | Hetzner automated weekly snapshots (~€0.70/month) |
| `delete_protection` | `true` | Prevent accidental server deletion |

Examples:

```bash
# Production replacement (defaults)
terraform plan

# DR test (throwaway, no protection)
terraform plan -var="delete_protection=false" -var="backups=false"

# Different server size
terraform plan -var="server_type=cx32"
```

## Setup

Requires Terraform >= 1.5 and [direnv](https://direnv.net/) (`brew install terraform direnv`, add `eval "$(direnv hook zsh)"` to `~/.zshrc`).

```bash
cd terraform
cp .envrc.example .envrc
# Fill in credentials from Bitwarden
direnv allow
terraform init
```

## Usage

```bash
terraform plan              # preview
terraform apply             # create
terraform output ip         # get IP for Ansible
terraform destroy           # tear down (DR test only)
```

**DR test vs real replacement:**

- **DR test:** use `-var="delete_protection=false" -var="backups=false"`. Destroy when done.
- **Real DR:** use defaults (protection on). After Ansible + data restore + DNS update, the server becomes production. **Never destroy it** — `delete_protection` prevents accidental deletion.

## New project (DR test)

To spin up the full app in a new Hetzner project:

**One-time setup (console):**
1. Create new Hetzner Cloud project (e.g. "DR Test")
2. Upload your SSH public key (`~/.ssh/id_ed25519.pub`) in the new project — name it `victor-laptop` (must match `ssh_key_name` variable)
3. Generate API token in the new project

**Terraform:**
4. Update `HCLOUD_TOKEN` in `.envrc` with the new project token
5. `direnv allow`
6. Plan and apply:

```bash
terraform plan -var="delete_protection=false" -var="backups=false"
terraform apply
terraform output ip
```

**Then:**
8. Run Ansible against the new IP
9. Restore Postgres from S3
10. Update DNS in Porkbun → new IP

**Cleanup:**
```bash
terraform destroy
# Switch HCLOUD_TOKEN back to production in .envrc
```

## What this provisions

- Hetzner CX23 server (Debian 13)
- Cloud firewall (TCP 22, 80, 443 inbound)
- Your SSH public key added to the server (so you can `ssh root@<ip>` immediately after creation)
- Automated backups + delete/rebuild protection (overridable)

## What this does NOT manage

- web-01 (existing production server) — never import it. Running `apply` in the production project creates a second server alongside web-01 (you'll be billed for both).
- DNS (manual Porkbun update)
- Object Storage buckets (created manually, account-wide)
- Server configuration (Ansible handles that)

## State

Terraform tracks what it created (server ID, IP, firewall ID) in a state file. This file is stored remotely in Hetzner Object Storage so it's not lost if your laptop dies.

**Bucket:** `s3://victorpatrin-terraform-state/` (account-wide, accessible from any project)

State is written to `infra/terraform.tfstate`. After `terraform destroy`, the state shows zero resources but the file remains — next `apply` starts fresh.
