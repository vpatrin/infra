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

for db in "${DATABASES[@]}"; do
    s3_path="s3://${S3_BUCKET}/${S3_PREFIX}/${db}/${DATE}.sql.gz"

    echo "Dumping ${db} → ${s3_path}..."
    docker exec "${CONTAINER}" pg_dump -U "${PG_USER}" "${db}" | gzip | \
        aws s3 cp - "${s3_path}" --quiet
    echo "  uploaded"
done

echo "Done."
