#!/bin/bash
# Pull production database to local development.
# Usage: ./scripts/sync-db-from-prod.sh <site-name> [prod-domain] [local-url]
# Example: ./scripts/sync-db-from-prod.sh my-wp-site mysite.com http://localhost:8080

set -e

SITE_NAME="${1:?Usage: sync-db-from-prod.sh <site-name> [prod-domain] [local-url]}"
PROD_DOMAIN="${2:-}"
LOCAL_URL="${3:-http://localhost:8080}"
SERVER="${HETZNER_HOST:?Set HETZNER_HOST env var}"
REMOTE_DIR="/opt/apps/${SITE_NAME}"

mkdir -p backups

echo "Dumping production database..."
ssh "root@${SERVER}" "cd ${REMOTE_DIR} && docker compose exec -T mysql mysqldump -uroot -p\$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2) wordpress" > backups/prod_sync.sql

echo "Importing into local database..."
docker compose exec -T mysql mysql -uroot -p"WordPress_Dev123!" wordpress < backups/prod_sync.sql

# URL replacement if prod domain provided
if [ -n "$PROD_DOMAIN" ]; then
  echo "Replacing URLs: https://${PROD_DOMAIN} -> ${LOCAL_URL}"
  docker compose run --rm wpcli wp search-replace "https://${PROD_DOMAIN}" "${LOCAL_URL}" --all-tables --skip-columns=guid
  docker compose run --rm wpcli wp search-replace "http://${PROD_DOMAIN}" "${LOCAL_URL}" --all-tables --skip-columns=guid
fi

echo "Flushing cache..."
docker compose run --rm wpcli wp cache flush

echo "Done! Local DB is now a copy of production."
