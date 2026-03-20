#!/bin/bash
# Pull production database to local development.
# Usage: ./scripts/sync-db-from-prod.sh <site-name> [prod-domain] [local-url]
# Example: ./scripts/sync-db-from-prod.sh my-wp-site designtest.allegroit.dk http://localhost:8080
#
# NOTE: This script requires the HETZNER_HOST env var and SSH access to the server.
# On Windows, use sync-db-from-prod.bat instead, or run the manual steps from CLAUDE.md.

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

# URL replacement using MySQL directly (WP-CLI is not available in the WordPress container)
if [ -n "$PROD_DOMAIN" ]; then
  echo "Replacing URLs: https://${PROD_DOMAIN} -> ${LOCAL_URL}"
  docker compose exec -T mysql mysql -uroot -p"WordPress_Dev123!" wordpress -e "
    UPDATE wp_options SET option_value = REPLACE(option_value, 'https://${PROD_DOMAIN}', '${LOCAL_URL}') WHERE option_value LIKE '%${PROD_DOMAIN}%';
    UPDATE wp_options SET option_value = REPLACE(option_value, 'http://${PROD_DOMAIN}', '${LOCAL_URL}') WHERE option_value LIKE '%${PROD_DOMAIN}%';
    UPDATE wp_posts SET post_content = REPLACE(post_content, 'https://${PROD_DOMAIN}', '${LOCAL_URL}') WHERE post_content LIKE '%${PROD_DOMAIN}%';
    UPDATE wp_posts SET guid = REPLACE(guid, 'https://${PROD_DOMAIN}', '${LOCAL_URL}') WHERE guid LIKE '%${PROD_DOMAIN}%';
    UPDATE wp_postmeta SET meta_value = REPLACE(meta_value, 'https://${PROD_DOMAIN}', '${LOCAL_URL}') WHERE meta_value LIKE '%${PROD_DOMAIN}%';
  "
fi

# Fix uploads permissions
echo "Fixing uploads permissions..."
docker compose exec wordpress chown -R www-data:www-data /var/www/html/wp-content/uploads

echo "Done! Local DB is now a copy of production."
