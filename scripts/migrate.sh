#!/usr/bin/env bash
# scripts/migrate.sh — Gated, reversible DB migrations
# Usage: ./migrate.sh <environment>
set -euo pipefail

ENV=${1:?Usage: migrate.sh <env>}
MIGRATIONS_DIR="migrations"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗄️  Running DB migrations"
echo "   Environment : ${ENV}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Validate DB_URL is set
if [[ -z "${DB_URL:-}" ]]; then
  echo "❌ DB_URL is not set"
  exit 1
fi

# Install migrate tool if not present
if ! command -v migrate &>/dev/null; then
  echo "📦 Installing golang-migrate..."
  curl -sSL \
    "https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/bin migrate
fi

# Count pending migrations
PENDING=$(migrate -path "${MIGRATIONS_DIR}" -database "${DB_URL}" version 2>&1 || echo "0")
echo "📋 Current schema version: ${PENDING}"

# For prod — gate on explicit confirmation env var
if [[ "${ENV}" == "prod" ]]; then
  if [[ "${ALLOW_PROD_MIGRATION:-false}" != "true" ]]; then
    echo "⚠️  Production migrations require ALLOW_PROD_MIGRATION=true"
    echo "   Set this secret in the GitHub environment to proceed."
    exit 1
  fi
fi

echo "⬆️  Applying migrations..."
migrate -path "${MIGRATIONS_DIR}" \
        -database "${DB_URL}" \
        up

echo "✅ Migrations complete"
migrate -path "${MIGRATIONS_DIR}" -database "${DB_URL}" version
