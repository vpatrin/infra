#!/usr/bin/env bash
set -euo pipefail

# Notify an Uptime Kuma push monitor that a job succeeded.
# Called as ExecStartPost= in systemd service units — only runs if ExecStart exits 0.
#
# Usage: push-monitor.sh <PUSH_URL>
#   PUSH_URL: full Uptime Kuma push URL (e.g. https://status.example.com/api/push/xxx)

PUSH_URL="${1:-}"

if [[ -z "${PUSH_URL}" ]]; then
    echo "push-monitor: no URL provided, skipping" >&2
    exit 0
fi

curl --silent --fail --max-time 10 "${PUSH_URL}" > /dev/null

echo "push-monitor: heartbeat sent"
