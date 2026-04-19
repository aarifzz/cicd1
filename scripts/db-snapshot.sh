#!/usr/bin/env bash
# scripts/db-snapshot.sh — Pre-migration DB snapshot to S3
# Usage: ./db-snapshot.sh <environment>
set -euo pipefail

ENV=${1:?Usage: db-snapshot.sh <env>}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
SNAPSHOT_NAME="${ENV}-snapshot-${TIMESTAMP}.sql.gz"
S3_BUCKET="${S3_BACKUP_BUCKET:-your-backups-bucket}"

echo "📸 Creating DB snapshot before migration"
echo "   Environment : ${ENV}"
echo "   Snapshot    : ${SNAPSHOT_NAME}"

# Parse DB_URL: postgres://user:pass@host:port/dbname
DB_USER=$(echo "${DB_URL}" | sed -E 's|.*://([^:]+):.*|\1|')
DB_PASS=$(echo "${DB_URL}" | sed -E 's|.*://[^:]+:([^@]+)@.*|\1|')
DB_HOST=$(echo "${DB_URL}" | sed -E 's|.*@([^:/]+).*|\1|')
DB_PORT=$(echo "${DB_URL}" | sed -E 's|.*:([0-9]+)/.*|\1|')
DB_NAME=$(echo "${DB_URL}" | sed -E 's|.*/([^?]+).*|\1|')

export PGPASSWORD="${DB_PASS}"

pg_dump \
  -h "${DB_HOST}" \
  -p "${DB_PORT}" \
  -U "${DB_USER}" \
  "${DB_NAME}" \
  | gzip > "/tmp/${SNAPSHOT_NAME}"

echo "📤 Uploading snapshot to s3://${S3_BUCKET}/snapshots/${SNAPSHOT_NAME}"
aws s3 cp "/tmp/${SNAPSHOT_NAME}" \
  "s3://${S3_BUCKET}/snapshots/${SNAPSHOT_NAME}" \
  --storage-class STANDARD_IA

echo "✅ Snapshot complete: s3://${S3_BUCKET}/snapshots/${SNAPSHOT_NAME}"
echo "   To restore: aws s3 cp s3://${S3_BUCKET}/snapshots/${SNAPSHOT_NAME} - | gunzip | psql \$DB_URL"
