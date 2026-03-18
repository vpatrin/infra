#!/usr/bin/env bash
set -euo pipefail

# Idempotent infra deploy script.
# Runs on the VPS — safe to re-run at any time.
# Called by GitHub Actions (manual dispatch) or directly: ./deploy_infra.sh

INFRA_DIR="$(cd "$(dirname "$0")" && pwd)"
UNITS_SRC_POSTGRES="${INFRA_DIR}/services/postgres/backups"
UNITS_SRC_DISK="${INFRA_DIR}/services/disk-alert"
UNITS_DST="/etc/systemd/system"

echo "==> Pulling latest infra repo..."
git -C "${INFRA_DIR}" pull

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

for unit in pg-backup.service pg-backup.timer; do
    src="${UNITS_SRC_POSTGRES}/${unit}"
    dst="${UNITS_DST}/${unit}"
    if [[ ! -f "${dst}" ]] || ! diff -q "${src}" "${dst}" > /dev/null 2>&1; then
        sudo tee "${dst}" < "${src}" > /dev/null
        CHANGED=1
        echo "  updated: ${unit}"
    fi
done

for unit in disk-alert.service disk-alert.timer; do
    src="${UNITS_SRC_DISK}/${unit}"
    dst="${UNITS_DST}/${unit}"
    if [[ ! -f "${dst}" ]] || ! diff -q "${src}" "${dst}" > /dev/null 2>&1; then
        sudo tee "${dst}" < "${src}" > /dev/null
        CHANGED=1
        echo "  updated: ${unit}"
    fi
done

if [[ "${CHANGED}" -eq 1 ]]; then
    sudo systemctl daemon-reload
    sudo systemctl enable pg-backup.timer disk-alert.timer
    sudo systemctl start pg-backup.timer disk-alert.timer
    echo "  systemd units reloaded"
else
    echo "  systemd units unchanged"
fi

echo "==> Deploy complete"
