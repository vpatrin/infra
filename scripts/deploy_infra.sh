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

echo "==> Pulling latest infra repo..."
git -C "${INFRA_DIR}" pull

ENCRYPTED_SERVICES=(postgres umami grafana)

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

check_health() {
    local name="$1" cmd="$2"
    if eval "${cmd}" > /dev/null 2>&1; then
        echo "  ✓ ${name}"
    else
        echo "  ✗ ${name}"
        FAILED=1
    fi
}

check_health "postgres"    "docker exec shared-postgres pg_isready -U postgres"
check_health "caddy"       "curl -sf --max-time 5 https://victorpatrin.dev"
check_health "umami"       "docker exec umami wget --quiet --spider --timeout=5 http://localhost:3000"
check_health "uptime-kuma" "docker exec uptime-kuma wget --quiet --spider --timeout=5 http://localhost:3001"
check_health "loki"        "docker exec loki wget --quiet --spider --timeout=5 http://localhost:3100/ready"
check_health "prometheus"  "docker exec prometheus wget --quiet --spider --timeout=5 http://localhost:9090/-/healthy"
check_health "grafana"     "docker exec grafana wget --quiet --spider --timeout=5 http://localhost:3000/api/health"
check_health "alloy"       "docker exec alloy wget --quiet --spider --timeout=5 http://localhost:12345/-/ready"

if [[ "${FAILED}" -eq 1 ]]; then
    echo "ERROR: one or more health checks failed"
    exit 1
fi

echo "==> Deploy complete"
