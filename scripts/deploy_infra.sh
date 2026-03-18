#!/usr/bin/env bash
set -euo pipefail

# Idempotent infra deploy script.
# Runs on the VPS — safe to re-run at any time.
# Called by GitHub Actions (manual dispatch) or directly: ./deploy_infra.sh

INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
UNITS_SRC="${INFRA_DIR}/systemd"
UNITS_DST="/etc/systemd/system"

# Check for sops installation for secret decryption before proceeding
command -v sops >/dev/null || { echo "ERROR: sops not found in PATH"; exit 1; }
[[ -n "${SOPS_AGE_KEY:-}" ]] || { echo "ERROR: SOPS_AGE_KEY not set"; exit 1; }

echo "==> Pulling latest infra repo..."
git -C "${INFRA_DIR}" pull

ENCRYPTED_SERVICES=(postgres umami)

echo "==> Decrypting secrets..."
(
    umask 077  # owner-only from creation — no race window unlike chmod after write
    for svc in "${ENCRYPTED_SERVICES[@]}"; do
        sops --decrypt "${INFRA_DIR}/services/${svc}/.env.prod.enc" > "${INFRA_DIR}/services/${svc}/.env"
    done
)

# Validate decrypted files are non-empty before proceeding
for svc in "${ENCRYPTED_SERVICES[@]}"; do
    env_file="${INFRA_DIR}/services/${svc}/.env"
    if [[ ! -s "${env_file}" ]]; then
        echo "ERROR: ${env_file} is empty after decryption"
        exit 1
    fi
done

echo "==> Validating compose config..."
docker compose -f "${INFRA_DIR}/docker-compose.yml" config --quiet

echo "==> Pulling latest images..."
docker compose -f "${INFRA_DIR}/docker-compose.yml" pull

echo "==> Starting services..."
docker compose -f "${INFRA_DIR}/docker-compose.yml" up -d

echo "==> Validating Caddyfile..."
docker exec caddy caddy validate --config /etc/caddy/Caddyfile

echo "==> Reloading Caddy..."
docker exec caddy caddy reload --config /etc/caddy/Caddyfile

echo "==> Syncing systemd units..."
CHANGED=0

for unit in "${UNITS_SRC}"/*.{service,timer}; do
    name="$(basename "${unit}")"
    dst="${UNITS_DST}/${name}"
    if [[ ! -f "${dst}" ]] || ! diff -q "${unit}" "${dst}" > /dev/null 2>&1; then
        sudo tee "${dst}" < "${unit}" > /dev/null
        CHANGED=1
        echo "  updated: ${name}"
    fi
done

if [[ "${CHANGED}" -eq 1 ]]; then
    sudo systemctl daemon-reload
    timers=("${UNITS_SRC}"/*.timer)
    sudo systemctl enable "${timers[@]##*/}"
    sudo systemctl start "${timers[@]##*/}"
    echo "  systemd units reloaded"
else
    echo "  systemd units unchanged"
fi

echo "==> Deploy complete"
