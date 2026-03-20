#!/bin/bash
# Run this once on the Hetzner server to set up a new WordPress site.
# Usage: ./scripts/setup-server.sh <site-name> <repo-url>
# Example: ./scripts/setup-server.sh my-wp-site git@github.com:youruser/my-wp-site.git

set -e

SITE_NAME="${1:?Usage: setup-server.sh <site-name> <repo-url>}"
REPO_URL="${2:?Usage: setup-server.sh <site-name> <repo-url>}"
APP_DIR="/opt/apps/${SITE_NAME}"

if [ -d "$APP_DIR" ]; then
  echo "Error: $APP_DIR already exists"
  exit 1
fi

# Clone the repo
git clone "$REPO_URL" "$APP_DIR"
cd "$APP_DIR"

# Generate a strong password
MYSQL_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

# Create production .env
cat > .env <<EOF
COMPOSE_FILE=docker-compose.yml:docker-compose.production.yml
COMPOSE_PROJECT_NAME=${SITE_NAME}
MYSQL_ROOT_PASSWORD=${MYSQL_PASSWORD}
EOF

echo ""
echo "=== Setup complete ==="
echo "App directory: $APP_DIR"
echo "MySQL password: $MYSQL_PASSWORD (saved in .env)"
echo ""
echo "Next steps:"
echo "  1. Start containers: cd $APP_DIR && docker compose up -d"
echo "  2. Configure NPM to proxy to container: ${SITE_NAME}-wordpress:80"
echo "  3. Complete WordPress install via browser"
echo "  4. (Optional) Import Duplicator backup"
echo ""
