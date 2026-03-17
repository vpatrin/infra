#!/usr/bin/env bash
set -euo pipefail

# Alert via Telegram when disk usage exceeds threshold.
# Called by disk-alert.service (daily systemd timer).
#
# Requires: BOT_TOKEN, CHAT_ID (loaded via EnvironmentFile)

THRESHOLD=85

usage=$(df --output=pcent / | tail -1 | tr -d ' %')

if [[ "${usage}" -le "${THRESHOLD}" ]]; then
    echo "disk-alert: ${usage}% used, below ${THRESHOLD}% threshold"
    exit 0
fi

hostname=$(hostname)
message="⚠️ Disk usage on ${hostname}: ${usage}% (threshold: ${THRESHOLD}%)"

if curl --silent --fail --max-time 10 \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="${CHAT_ID}" \
    -d text="${message}" > /dev/null; then
    echo "disk-alert: ${usage}% used, alert sent"
else
    echo "disk-alert: ${usage}% used, failed to send alert" >&2
fi
