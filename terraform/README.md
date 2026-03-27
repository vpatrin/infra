# Terraform — Hetzner Cloud

Manages production cloud resources as code. State is permanent — tracks DNS and firewall.

Server provisioning (DR or benchmarks) is done via `hcloud` CLI or Console — see `docs/DISASTER_RECOVERY.md`.

## Credentials

| Credential | Scope | Where to get it |
|------------|-------|-----------------|
| `HCLOUD_TOKEN` | **Project** — controls servers, firewall, and DNS | Hetzner Console → Project → Security → API Tokens |
| `AWS_ACCESS_KEY_ID` | **Account** — works across all projects | Hetzner Console → Object Storage → S3 Credentials |
| `AWS_SECRET_ACCESS_KEY` | **Account** — same as above | Hetzner Console → Object Storage → S3 Credentials |

Set credentials in `.envrc` (gitignored). See `.envrc.example` for the template.

## Setup

Requires Terraform >= 1.5 and [direnv](https://direnv.net/) (`brew install terraform direnv`, add `eval "$(direnv hook zsh)"` to `~/.zshrc`).

```bash
cd terraform
cp .envrc.example .envrc
# Fill in credentials from Bitwarden
direnv allow
terraform init
```

## Resources

- **Cloud firewall** (TCP 22, 80, 443 inbound) — auto-applies to any server with label `role=web`
- **DNS zones** (`victorpatrin.dev`, `coupette.club`) with A records pointing to the VPS IP

## Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `vps_ip` | *(required)* | Production VPS IPv4 — set in `.tfvars` or `-var` |
| `firewall_name` | `allow-ssh-http-https` | Cloud firewall name |
| `ingress_ports` | `["22", "80", "443"]` | Allowed inbound TCP ports |
| `dns_zones` | *(see variables.tf)* | DNS zones + records (A records default to `vps_ip`) |

## Usage

```bash
cd terraform

# First time
terraform init
terraform plan -var="vps_ip=<web-01-ip>"
terraform apply -var="vps_ip=<web-01-ip>"

# Or use a .tfvars file (gitignored)
echo 'vps_ip = "<web-01-ip>"' > terraform.tfvars
terraform plan
terraform apply

# Drift check
terraform plan
```

## Import existing DNS zones

After first `init`, import the manually-created zones:

```bash
terraform import -var="vps_ip=<web-01-ip>" 'hcloud_zone.zones["victorpatrin.dev"]' <zone-id>
terraform import -var="vps_ip=<web-01-ip>" 'hcloud_zone.zones["coupette.club"]' <zone-id>

# Verify — should show no changes (or only drift to correct)
terraform plan -var="vps_ip=<web-01-ip>"
```

Get zone IDs from `hcloud dns zone list` or the Hetzner Console.

## Firewall auto-attachment

The firewall uses `apply_to` with label selector `role=web`. Any server with that label automatically gets the firewall rules. To create a server with firewall access:

```bash
hcloud server create --name web-02 --type cx23 --image debian-13 \
  --location hel1 --ssh-key victor-laptop --label role=web
```

Servers without the `role=web` label are isolated from the internet (no inbound ports open).

## DNS migration (Porkbun → Hetzner DNS)

One-time setup after first `apply`:

1. `terraform output nameservers` — get the Hetzner nameservers
2. Verify records before switching NS:
   ```bash
   dig @hydrogen.ns.hetzner.com victorpatrin.dev A
   dig @hydrogen.ns.hetzner.com coupette.club A
   ```
3. At Porkbun, replace nameservers with the Hetzner NS (both domains)
4. Wait for propagation:
   ```bash
   dig victorpatrin.dev NS    # should show Hetzner NS
   dig victorpatrin.dev A     # should show VPS IP
   dig coupette.club A        # should show VPS IP
   ```

**Rollback:** set Porkbun nameservers back to `curitiba/fortaleza/maceio/salvador.ns.porkbun.com`.

## What this does NOT manage

- **Servers** — created via `hcloud` CLI or Console (DR, benchmarks, staging). Firewall applies automatically via label.
- **S3 buckets** — Terraform state (Hetzner Object Storage) and Postgres backups (AWS S3) are created manually. One-time setup.
- **Server configuration** — Ansible handles that after server creation.

## State backend

State is stored in Hetzner Object Storage (`victorpatrin-terraform-state` bucket), key: `infra/terraform.tfstate`.
