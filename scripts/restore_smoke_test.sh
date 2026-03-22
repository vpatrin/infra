#!/usr/bin/env bash
set -euo pipefail

# Verify the latest S3 backup restores successfully.
# Pulls the most recent daily dump, restores into a throwaway container, checks row counts.
#
# Usage: ./restore_smoke_test.sh [db_name]
#   Defaults to saq_sommelier if no argument given.

S3_BUCKET="${S3_BUCKET:-victorpatrin-backups}"
S3_PREFIX="postgres"
DB="${1:-saq_sommelier}"
TEST_CONTAINER="restore-smoke-test"
PG_IMAGE="pgvector/pgvector:0.8.2-pg16"

WORK_DIR=$(mktemp -d)
trap 'docker rm -f "${TEST_CONTAINER}" 2>/dev/null; rm -rf "${WORK_DIR}"' EXIT

# Find the latest dump for this database
echo "Finding latest dump for ${DB}..."
LATEST=$(aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/${DB}/" | sort | tail -1 | awk '{print $4}')

if [[ -z "${LATEST}" ]]; then
    echo "ERROR: no backup found for ${DB} in s3://${S3_BUCKET}/${S3_PREFIX}/${DB}/"
    exit 1
fi

echo "  found: ${LATEST}"

# Download
echo "Downloading..."
aws s3 cp "s3://${S3_BUCKET}/${S3_PREFIX}/${DB}/${LATEST}" "${WORK_DIR}/${LATEST}" --quiet

# Start throwaway postgres
echo "Starting throwaway container..."
docker run -d --name "${TEST_CONTAINER}" \
    -e POSTGRES_PASSWORD=smoketest \
    -e POSTGRES_DB="${DB}" \
    "${PG_IMAGE}" > /dev/null

# Wait for postgres to be ready
for i in $(seq 1 30); do
    if docker exec "${TEST_CONTAINER}" pg_isready -U postgres > /dev/null 2>&1; then
        break
    fi
    sleep 1
done
docker exec "${TEST_CONTAINER}" pg_isready -U postgres > /dev/null 2>&1 || { echo "ERROR: postgres did not become ready"; exit 1; }

# Create extensions that the dump might reference
docker exec "${TEST_CONTAINER}" psql -U postgres -d "${DB}" -c "CREATE EXTENSION IF NOT EXISTS vector;" > /dev/null 2>&1 || true
docker exec "${TEST_CONTAINER}" psql -U postgres -d "${DB}" -c "CREATE EXTENSION IF NOT EXISTS pg_trgm;" > /dev/null 2>&1 || true

# Restore
echo "Restoring ${LATEST}..."
gunzip -c "${WORK_DIR}/${LATEST}" | docker exec -i "${TEST_CONTAINER}" psql -U postgres -d "${DB}" > /dev/null 2>&1

# Verify — count tables and total rows
TABLE_COUNT=$(docker exec "${TEST_CONTAINER}" psql -U postgres -d "${DB}" -tAc \
    "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';")
ROW_COUNT=$(docker exec "${TEST_CONTAINER}" psql -U postgres -d "${DB}" -tAc \
    "SELECT sum(n_live_tup) FROM pg_stat_user_tables;")

echo "  tables: ${TABLE_COUNT}"
echo "  rows: ${ROW_COUNT:-0}"

if [[ "${TABLE_COUNT}" -eq 0 ]]; then
    echo "ERROR: no tables found after restore"
    exit 1
fi

echo "Smoke test passed."
