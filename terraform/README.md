# Terraform — Hetzner VPS Provisioning

Provisions a Hetzner Cloud VPS for disaster recovery. **Does NOT manage web-01** — this config creates new servers only.

## Prerequisites

- Terraform >= 1.5
- `HCLOUD_TOKEN` env var (Hetzner API token, Read & Write)
- S3 credentials for Hetzner Object Storage (state backend)
- SSH key registered in Hetzner Cloud Console

## Setup

Export credentials:

```bash
export HCLOUD_TOKEN=<from Bitwarden>
export AWS_ACCESS_KEY_ID=<Hetzner Object Storage access key>
export AWS_SECRET_ACCESS_KEY=<Hetzner Object Storage secret key>
```

Initialize:

```bash
cd terraform
terraform init
```

## Usage

```bash
# Preview changes
terraform plan

# Create a new VPS (for DR test or replacement)
terraform apply

# Get the IP for Ansible
terraform output ip

# Tear down after DR test
terraform destroy
```

## What this provisions

- Hetzner CX22 server (Debian 13, Helsinki)
- Cloud firewall (TCP 22, 80, 443 inbound)
- SSH key attachment

## What this does NOT manage

- web-01 (existing production server) — never import it
- DNS (manual Porkbun update)
- Object Storage buckets (created manually)
- Server configuration (Ansible handles that)

## State

Stored in Hetzner Object Storage: `s3://victorpatrin-terraform-state/infra/terraform.tfstate`
