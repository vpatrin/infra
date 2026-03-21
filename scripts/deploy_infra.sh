#!/usr/bin/env bash
set -euo pipefail

# Idempotent infra deploy script.
# Runs on the VPS — safe to re-run at any time.
# Called by GitHub Actions (manual dispatch) or directly: ./deploy_infra.sh

INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE=(docker compose -f "${INFRA_DIR}/docker-compose.yml" -f "${INFRA_DIR}/docker-compose.prod.yml")
UNITS_SRC="${INFRA_DIR}/systemd"
UNITS_DST="/etc/systemd/system"

# Check for sops installation for secret decryption before proceeding
command -v sops >/dev/null || { echo "ERROR: sops not found in PATH"; exit 1; }
[[ -n "${SOPS_AGE_KEY:-}" ]] || { echo "ERROR: SOPS_AGE_KEY not set"; exit 1; }

ENCRYPTED_SERVICES=(postgres umami grafana alloy)

echo "==> Decrypting secrets..."
(
    umask 077  # owner-only from creation — no race window unlike chmod after write
    for svc in "${ENCRYPTED_SERVICES[@]}"; do
        enc="${INFRA_DIR}/services/${svc}/.env.prod.enc"
        [[ -f "${enc}" ]] || { echo "ERROR: ${enc} not found"; exit 1; }
        sops --decrypt --output-type dotenv "${enc}" > "${INFRA_DIR}/services/${svc}/.env.prod"
    done
)

# Validate decrypted files are non-empty before proceeding
for svc in "${ENCRYPTED_SERVICES[@]}"; do
    env_file="${INFRA_DIR}/services/${svc}/.env.prod"
    if [[ ! -s "${env_file}" ]]; then
        echo "ERROR: ${env_file} is empty after decryption"
        exit 1
    fi
done

echo "==> Validating compose config..."
"${COMPOSE[@]}" config --quiet

echo "==> Pulling latest images..."
"${COMPOSE[@]}" pull

echo "==> Starting services..."
"${COMPOSE[@]}" up -d

echo "==> Validating Caddyfile..."
docker exec caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

echo "==> Reloading Caddy..."
docker exec caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile

echo "==> Syncing systemd units..."
CHANGED=0
shopt -s nullglob

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
    if [[ ${#timers[@]} -gt 0 ]]; then
        sudo systemctl enable "${timers[@]##*/}"
        sudo systemctl start "${timers[@]##*/}"
    fi
    echo "  systemd units reloaded"
else
    echo "  systemd units unchanged"
fi

echo "==> Health checks..."
FAILED=0

check_health_inspect() {
    local name="$1" container="${2:-$1}" retries=5 delay=3
    for _ in $(seq 1 "${retries}"); do
        status="$(docker inspect --format='{{.State.Health.Status}}' "${container}" 2>/dev/null || true)"
        if [[ "${status}" == "healthy" ]]; then
            echo "  ✓ ${name}"
            return 0
        fi
        sleep "${delay}"
    done
    echo "  ✗ ${name} (status: ${status:-unknown})"
    FAILED=1
}

# Services with compose healthchecks — reuse via docker inspect
check_health_inspect "postgres"   "shared-postgres"
check_health_inspect "caddy"
check_health_inspect "umami"
check_health_inspect "uptime-kuma"
check_health_inspect "prometheus"
check_health_inspect "grafana"

if [[ "${FAILED}" -eq 1 ]]; then
    echo "ERROR: one or more health checks failed"
    exit 1
fi

echo "==> Deploy complete"
