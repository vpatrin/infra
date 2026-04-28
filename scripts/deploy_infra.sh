~#!/usr/bin/env bash
set -euo pipefail

# Idempotent infra deploy script.
# Runs on the VPS — safe to re-run at any time.
# Called by GitHub Actions (manual dispatch) or directly: ./deploy_infra.sh

INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STACKS_DIR="${INFRA_DIR}/stacks"
UNITS_SRC="${INFRA_DIR}/systemd"
UNITS_DST="/etc/systemd/system"

# Stacks in startup dependency order (data plane first, then edge, then apps).
STACKS=(postgres coupette-redis caddy umami uptime-kuma observability)

# Check for sops installation before proceeding
command -v sops >/dev/null || { echo "ERROR: sops not found in PATH"; exit 1; }
[[ -n "${SOPS_AGE_KEY:-}" ]] || { echo "ERROR: SOPS_AGE_KEY not set"; exit 1; }

ENCRYPTED_SECRETS=(aws-infra-backup monitor-backups telegram-alerts-bot)

echo "==> Decrypting secrets..."
(
    umask 077  # owner-only from creation — no race window unlike chmod after write

    # Stack-level secrets: any .env.enc under stacks/ (discovered dynamically)
    while IFS= read -r -d '' enc; do
        dec="${enc%.enc}"
        sops --decrypt --output-type dotenv "${enc}" > "${dec}"
    done < <(find "${STACKS_DIR}" -type f -name "*.env.enc" -print0)

    # Infra-level secrets (host systemd timers, push monitors)
    for secret in "${ENCRYPTED_SECRETS[@]}"; do
        enc="${INFRA_DIR}/secrets/${secret}.env.enc"
        [[ -f "${enc}" ]] || { echo "ERROR: ${enc} not found"; exit 1; }
        sops --decrypt --output-type dotenv "${enc}" > "${INFRA_DIR}/secrets/${secret}.env"
    done
)

# Validate decrypted files are non-empty before proceeding
while IFS= read -r -d '' enc; do
    dec="${enc%.enc}"
    if [[ ! -s "${dec}" ]]; then
        echo "ERROR: ${dec} is empty after decryption"
        exit 1
    fi
done < <(find "${STACKS_DIR}" -type f -name "*.env.enc" -print0)
for secret in "${ENCRYPTED_SECRETS[@]}"; do
    env_file="${INFRA_DIR}/secrets/${secret}.env"
    if [[ ! -s "${env_file}" ]]; then
        echo "ERROR: ${env_file} is empty after decryption"
        exit 1
    fi
done

# Compose file args for a stack (base + optional prod override if present)
compose_args() {
    local stack="$1"
    local base="${STACKS_DIR}/${stack}/docker-compose.yml"
    local prod="${STACKS_DIR}/${stack}/docker-compose.prod.yml"
    printf -- '-f\n%s\n' "${base}"
    [[ -f "${prod}" ]] && printf -- '-f\n%s\n' "${prod}"
}

echo "==> Validating compose configs..."
for stack in "${STACKS[@]}"; do
    mapfile -t args < <(compose_args "${stack}")
    docker compose "${args[@]}" config --quiet
done

echo "==> Pulling latest images..."
for stack in "${STACKS[@]}"; do
    mapfile -t args < <(compose_args "${stack}")
    docker compose "${args[@]}" pull
done

echo "==> Starting services..."
for stack in "${STACKS[@]}"; do
    mapfile -t args < <(compose_args "${stack}")
    docker compose "${args[@]}" up -d
done

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
    for timer in "${UNITS_SRC}"/*.timer; do
        name="$(basename "${timer}")"
        sudo systemctl enable "${name}"
        sudo systemctl start "${name}"
    done
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
check_health_inspect "postgres"      "shared-postgres"
check_health_inspect "coupette-redis"
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
