#!/usr/bin/env bash
set -euo pipefail

# First-time Ansible setup. Run once on your laptop before ansible-playbook.
# Requires: ansible, ansible-vault, mkpasswd (brew install whois), sops, age

cd "$(dirname "$0")"

echo "==> Checking prerequisites..."
for cmd in ansible ansible-vault ansible-galaxy mkpasswd sops; do
    command -v "${cmd}" >/dev/null || { echo "ERROR: ${cmd} not found. Install it first."; exit 1; }
done

echo "==> Installing Galaxy roles..."
ansible-galaxy install -r requirements.yml

# --- Vault password ---
VAULT_PASS_FILE="${HOME}/.ansible_vault_pass"
if [[ -f "${VAULT_PASS_FILE}" ]]; then
    echo "==> Vault password file exists: ${VAULT_PASS_FILE}"
else
    echo ""
    echo "==> Create a vault password (store it in Bitwarden too)."
    read -rsp "Vault password: " vault_pass
    echo
    read -rsp "Confirm: " vault_pass_confirm
    echo
    [[ "${vault_pass}" == "${vault_pass_confirm}" ]] || { echo "ERROR: passwords don't match"; exit 1; }
    (umask 077; echo "${vault_pass}" > "${VAULT_PASS_FILE}")
    echo "  Saved to ${VAULT_PASS_FILE}"
fi

# --- Admin password ---
echo ""
echo "==> Create a password for the admin user (for sudo + Hetzner console break-glass)."
echo "  Store the plaintext in Bitwarden."
read -rsp "Admin password: " admin_pass
echo
read -rsp "Confirm: " admin_pass_confirm
echo
[[ "${admin_pass}" == "${admin_pass_confirm}" ]] || { echo "ERROR: passwords don't match"; exit 1; }
admin_hash=$(echo "${admin_pass}" | mkpasswd --method=sha-512 --stdin)

# --- sops age key ---
AGE_KEYS_FILE="${HOME}/.sops/age/keys.txt"
if [[ -f "${AGE_KEYS_FILE}" ]]; then
    age_key=$(grep '^AGE-SECRET-KEY-' "${AGE_KEYS_FILE}" | head -1)
    echo "==> Read age key from ${AGE_KEYS_FILE}"
else
    echo ""
    echo "==> Could not find ${AGE_KEYS_FILE}."
    echo "  Enter the sops age secret key (starts with AGE-SECRET-KEY-1...)."
    read -rsp "Age key: " age_key
    echo
fi
[[ "${age_key}" == AGE-SECRET-KEY-* ]] || { echo "ERROR: doesn't look like an age secret key"; exit 1; }

# --- Write vault ---
echo ""
echo "==> Writing vault..."
VAULT_FILE="group_vars/all/vault.yml"

python3 -c "
import yaml, sys
data = {
    'vault_sops_age_key': sys.argv[1],
    'vault_admin_password': sys.argv[2],
    'vault_admin_password_plain': sys.argv[3],
}
with open(sys.argv[4], 'w') as f:
    yaml.dump(data, f, default_flow_style=False)
" "${age_key}" "${admin_hash}" "${admin_pass}" "${VAULT_FILE}"

ansible-vault encrypt "${VAULT_FILE}"
echo "  Encrypted: ${VAULT_FILE}"

# --- Terraform IP ---
echo ""
echo "==> Getting VPS IP from Terraform..."
if command -v terraform >/dev/null && [[ -d ../terraform ]]; then
    ip=$(cd ../terraform && terraform output -raw ip 2>/dev/null) || ip=""
fi

if [[ -n "${ip:-}" ]]; then
    echo "  Found: ${ip}"
    # macOS sed requires -i '' (GNU sed uses -i without arg)
    sed -i '' "s/CHANGEME/${ip}/" inventory/hosts.ini || echo "  WARNING: could not update inventory/hosts.ini — update manually"
    echo "  Updated inventory/hosts.ini"
else
    echo "  Could not read terraform output. Update inventory/hosts.ini manually."
fi

echo ""
echo "==> Setup complete. Run:"
echo ""
echo "  cd ansible"
echo "  ansible-playbook site.yml"
echo ""
echo "After playbook finishes:"
echo "  1. Update DNS in Porkbun → ${ip:-<VPS_IP>}"
echo "  2. Restore Postgres from S3 (manual)"
echo "  3. Reconfigure CD (separate issue)"
