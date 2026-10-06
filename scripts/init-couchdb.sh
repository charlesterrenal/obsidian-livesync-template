#!/usr/bin/env bash
# ==============================================================================
# CouchDB Initialization Script for Obsidian LiveSync
# Creates required system databases (_users, _replicator, _global_changes)
# and the target vault database.
# ==============================================================================

set -euo pipefail

# Load environment variables
if [ -f .env ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' .env | xargs)
elif [ -f ../.env ]; then
  # shellcheck disable=SC2046
  export $(grep -v '^#' ../.env | xargs)
fi

COUCHDB_USER="${COUCHDB_USER:-admin}"
COUCHDB_PASSWORD="${COUCHDB_PASSWORD:-}"
COUCHDB_PORT="${COUCHDB_PORT:-5984}"
COUCHDB_DB="${COUCHDB_DB:-obsidian-livesync}"
HOST="${HOST:-http://127.0.0.1:${COUCHDB_PORT}}"

if [ -z "$COUCHDB_PASSWORD" ]; then
  echo "Error: COUCHDB_PASSWORD is not set. Please configure .env before running." >&2
  exit 1
fi

AUTH="${COUCHDB_USER}:${COUCHDB_PASSWORD}"

echo "Waiting for CouchDB to become ready at ${HOST}..."
until curl -s -f -u "$AUTH" "${HOST}/" > /dev/null 2>&1; do
  sleep 1
done

echo "CouchDB is online!"

create_db() {
  local db="$1"
  echo "Checking database: ${db}..."
  status=$(curl -s -o /dev/null -w "%{http_code}" -u "$AUTH" -X GET "${HOST}/${db}")
  if [ "$status" -eq 404 ]; then
    echo "Creating database: ${db}..."
    curl -s -u "$AUTH" -X PUT "${HOST}/${db}"
    echo ""
  else
    echo "Database ${db} already exists (HTTP ${status})."
  fi
}

# 1. System databases (required for CouchDB internal operations and auth)
create_db "_users"
create_db "_replicator"
create_db "_global_changes"

# 2. Vault database
create_db "${COUCHDB_DB}"

echo "=========================================================="
echo " CouchDB setup completed successfully!"
echo " Vault Database: ${HOST}/${COUCHDB_DB}"
echo "=========================================================="
