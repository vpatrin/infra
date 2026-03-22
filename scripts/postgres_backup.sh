#!/usr/bin/env bash
set -euo pipefail

# Backup PostgreSQL databases to AWS S3.
# Retention handled by S3 lifecycle rule (30-day expiry).
# Usage:
#   ./postgres_backup.sh              # Dump all databases
#   ./postgres_backup.sh saq_sommelier # Dump a single database

S3_BUCKET="${S3_BUCKET:-victorpatrin-backups}"
S3_PREFIX="postgres"
CONTAINER="shared-postgres"
PG_USER="postgres"
DATE=$(date +%Y%m%d)

DATABASES=("saq_sommelier" "umami")

if [[ $# -ge 1 ]]; then
    DATABASES=("$1")
fi

WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

for db in "${DATABASES[@]}"; do
    file="${WORK_DIR}/${db}_${DATE}.sql.gz"
    s3_path="s3://${S3_BUCKET}/${S3_PREFIX}/${db}/${DATE}.sql.gz"

    echo "Dumping ${db}..."
    docker exec "${CONTAINER}" pg_dump -U "${PG_USER}" "${db}" | gzip > "${file}"
    echo "  dumped: $(du -h "${file}" | cut -f1)"

    echo "  uploading to ${s3_path}..."
    aws s3 cp "${file}" "${s3_path}" --quiet
    echo "  uploaded"
done

echo "Done."
