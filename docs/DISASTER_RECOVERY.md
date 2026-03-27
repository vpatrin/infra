# Disaster Recovery

Step-by-step runbook for recovering the platform when web-01 is lost. Covers both same-project recovery (server dies, Hetzner account fine) and full re-provision (new project).

## RTO/RPO targets

- **RPO (data loss):** ≤ 24 hours — daily Postgres dumps to AWS S3
- **RTO (recovery time):** < 1 hour — server creation + Ansible + restore + DNS

## Prerequisites (on your laptop)

- `hcloud` CLI installed and authenticated (`brew install hcloud`)
- Ansible installed with Galaxy roles (`cd ansible && ansible-galaxy install -r requirements.yml`)
- `~/.ansible_vault_pass` — from password manager (decrypts ansible-vault secrets)
- AWS CLI configured — for downloading Postgres backups from S3
- Terraform installed — for DNS switch (or do it manually in Hetzner Console)
- `SOPS_AGE_KEY` — age private key for decrypting `.env.prod.enc` files (Ansible places this on the server)

## Scenario 1: Server dies, same Hetzner project

The common case — hardware failure, bad deploy, kernel panic. Hetzner account and project are fine.

### 1. Create replacement server

```bash
hcloud server create \
  --name web-02 \
  --type cx23 \
  --image debian-13 \
  --location hel1 \
  --ssh-key victor-laptop \
  --label role=web
```

The `role=web` label auto-attaches the cloud firewall (ports 22, 80, 443). Verify:

```bash
hcloud server describe web-02 -o format='{{.PublicNet.IPv4.IP}}'
# → note this IP for the next steps
```

### 2. Configure the server with Ansible

Update the inventory with the new IP:

```bash
cd ansible
cat > inventory/hosts.ini << EOF
[web]
web-02 ansible_host=<NEW_IP>
EOF
```

Run the playbook:

```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

This runs both phases:
- **Phase 1 (bootstrap):** creates admin user, disables root SSH
- **Phase 2 (configure):** system hardening, Docker, deploy user, clone repos, create Docker network + volumes

After completion, SSH in as admin to verify:

```bash
ssh admin@<NEW_IP>
docker ps    # should show no containers yet (deploy hasn't run)
```

### 3. Deploy infrastructure services

Trigger the deploy — either manually or via GitHub Actions:

```bash
# On the server as deploy user
cd ~/infra
./scripts/deploy_infra.sh
```

Or update the GitHub Actions secret `SSH_DEPLOY_HOST` to the new IP and trigger the deploy workflow.

### 4. Restore Postgres from S3

**From your laptop** — download the latest dumps:

```bash
aws s3 ls s3://victorpatrin-backups/postgres/saq_sommelier/
aws s3 ls s3://victorpatrin-backups/postgres/umami/

aws s3 cp s3://victorpatrin-backups/postgres/saq_sommelier/<LATEST_SAQ>.sql.gz /tmp/
aws s3 cp s3://victorpatrin-backups/postgres/umami/<LATEST_UMAMI>.sql.gz /tmp/

scp /tmp/<LATEST_SAQ>.sql.gz deploy@<NEW_IP>:/tmp/
scp /tmp/<LATEST_UMAMI>.sql.gz deploy@<NEW_IP>:/tmp/
```

**On the server** (`ssh deploy@<NEW_IP>`) — restore each database:

```bash
# saq_sommelier
docker exec shared-postgres psql -U postgres -c "DROP DATABASE IF EXISTS saq_sommelier;"
docker exec shared-postgres psql -U postgres -c "CREATE DATABASE saq_sommelier OWNER saq_sommelier;"
gunzip -c /tmp/<LATEST_SAQ>.sql.gz | docker exec -i shared-postgres psql -U postgres -d saq_sommelier

# umami
docker exec shared-postgres psql -U postgres -c "DROP DATABASE IF EXISTS umami;"
docker exec shared-postgres psql -U postgres -c "CREATE DATABASE umami OWNER umami;"
gunzip -c /tmp/<LATEST_UMAMI>.sql.gz | docker exec -i shared-postgres psql -U postgres -d umami
```

**Verify:**

```bash
docker exec shared-postgres psql -U postgres -d saq_sommelier -c "SELECT count(*) FROM product;"
docker exec shared-postgres psql -U postgres -d umami -c "SELECT count(*) FROM website;"
```

### 5. Verify services

```bash
# On the server
docker ps                              # all containers running
curl -s http://localhost:3000           # umami responds
curl -s http://localhost:3001           # uptime kuma responds
curl -s http://localhost:9090/-/ready   # prometheus ready
```

### 6. Switch DNS

Once everything is verified, point DNS to the new IP. Either:

**Option A — Terraform:**

```bash
cd terraform
terraform apply -var="vps_ip=<NEW_IP>"
```

**Option B — Hetzner Console:**

Go to DNS → each zone → edit A records (`@` and `*`) → set to new IP.

### 7. Verify DNS propagation

```bash
dig victorpatrin.dev A          # should show new IP
dig coupette.club A             # should show new IP
curl -sI https://victorpatrin.dev  # should return 200
curl -sI https://coupette.club    # should return 200
```

### 8. Deploy app services

After infra is up and DNS is pointing to the new server:

```bash
# Trigger coupette deploy via GitHub Actions (tag push or manual dispatch)
# Or manually on the server:
cd ~/coupette
./scripts/deploy.sh
```

### 9. Post-recovery cleanup

- Update GitHub Actions secret `SSH_DEPLOY_HOST` if not done in step 3
- Delete old web-01 if confirmed dead: `hcloud server delete web-01`
- Update `ansible/inventory/hosts.ini` to reflect the permanent name
- Run `./scripts/restore_smoke_test.sh` to verify backups are working on the new server
- Verify Uptime Kuma monitors are green
- Verify systemd timers are running: `systemctl list-timers`

## Scenario 2: New Hetzner project (account issue)

Nuclear scenario — Hetzner account compromised or unavailable. You need everything from scratch.

### Additional prerequisites

- Create a new Hetzner Cloud project in a new or existing account
- Upload your SSH public key (`~/.ssh/id_ed25519.pub`), name it `victor-laptop`
- Generate an API token for the new project
- Create an Object Storage bucket for Terraform state (or use local state temporarily)

### Steps

```bash
# Set credentials for the new project
export HCLOUD_TOKEN=<new-project-token>

# Create the server first (before DNS — you need the IP)
hcloud server create \
  --name web-02 \
  --type cx23 \
  --image debian-13 \
  --location hel1 \
  --ssh-key victor-laptop \
  --label role=web

# Get the new IP
NEW_IP=$(hcloud server describe web-02 -o format='{{.PublicNet.IPv4.IP}}')

# Apply Terraform (creates firewall + DNS zones pointing to the new IP)
cd terraform
terraform init    # may need to reconfigure backend for new state bucket
terraform apply -var="vps_ip=${NEW_IP}"
```

Then follow steps 2–9 from Scenario 1.

Additionally:
- At Porkbun, update nameservers to the new Hetzner DNS nameservers (`terraform output nameservers`)
- Update `HCLOUD_TOKEN` in `terraform/.envrc`

## What's backed up vs recoverable

| Data | Backup | Recovery method |
|------|--------|-----------------|
| Postgres (saq_sommelier, umami) | AWS S3 (daily, 30-day retention) | Download + `psql` restore |
| TLS certificates (Caddy) | Not backed up | Auto-renewed by Caddy on startup |
| Grafana dashboards | Not backed up | Re-provisioned from `services/grafana/` |
| Prometheus metrics | Not backed up | Rebuilt from scrape targets (30d loss) |
| Loki logs | Not backed up | Rebuilt from Docker log tailing (7d loss) |
| Uptime Kuma config | Not backed up | Manual reconfiguration (~15 min) |
| Alloy WAL | Not backed up | Rebuilt on restart |
| Coupette app data | In Postgres backup | Restored with saq_sommelier DB |

Only Postgres is high-risk. Everything else is recoverable from code or auto-renewed.

## DR test procedure

Test the full flow with a throwaway server. Costs ~€0.02 (CX23 for 1-2 hours).

```bash
# Create throwaway (no label = no firewall = isolated)
hcloud server create \
  --name dr-test \
  --type cx23 \
  --image debian-13 \
  --location hel1 \
  --ssh-key victor-laptop

# Run Ansible
cd ansible
cat > inventory/hosts.ini << EOF
[web]
dr-test ansible_host=<DR_TEST_IP>
EOF
ansible-playbook -i inventory/hosts.ini site.yml

# Deploy + restore + verify (don't switch DNS)
# ...

# Cleanup
hcloud server delete dr-test

# Restore production inventory
cat > inventory/hosts.ini << EOF
[web]
web-01 ansible_host=<PROD_IP>
EOF
```

Run this after major infrastructure changes (new Ansible roles, Compose changes, security hardening).

## Rollback — DNS

If the new server has issues after DNS switch, revert DNS to the old IP:

**Terraform:** `terraform apply -var="vps_ip=<OLD_IP>"`

**Console:** edit A records back to the old IP in Hetzner DNS.

**Nuclear (Hetzner DNS unavailable):** at Porkbun, switch nameservers back to `curitiba/fortaleza/maceio/salvador.ns.porkbun.com` and set A records there.
