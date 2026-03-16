#!/usr/bin/env bash
set -euo pipefail

# Backup individual PostgreSQL databases from the shared-postgres container.
# Usage:
#   ./backup.sh              # Dump all databases
#   ./backup.sh saq_sommelier # Dump a single database (used by deploy scripts)

BACKUP_DIR="/var/backups/postgres"
CONTAINER="shared-postgres"
PG_USER="postgres"
RETENTION_DAYS=30
DATE=$(date +%Y%m%d)

DATABASES=("saq_sommelier" "umami")

# If a specific database is requested, only dump that one
if [[ $# -ge 1 ]]; then
    DATABASES=("$1")
fi

mkdir -p "$BACKUP_DIR"

for db in "${DATABASES[@]}"; do
    file="${BACKUP_DIR}/${db}_${DATE}.sql.gz"
    echo "Backing up ${db}..."
    docker exec "$CONTAINER" pg_dump -U "$PG_USER" "$db" | gzip > "${file}.tmp"
    mv "${file}.tmp" "$file"
    echo "  -> ${file} ($(du -h "$file" | cut -f1))"
done

# Clean up backups older than retention period
echo "Cleaning up backups older than ${RETENTION_DAYS} days..."
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo "Done."
