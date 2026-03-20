#!/bin/bash
set -e

case "${1:-up}" in
  up)
    echo "Starting WordPress..."
    docker compose up --build -d
    echo ""
    echo "WordPress: http://localhost:8080"
    ;;
  down|stop)
    docker compose down
    ;;
  reset)
    docker compose down -v
    docker compose up --build -d
    echo ""
    echo "WordPress reset complete: http://localhost:8080"
    ;;
  logs)
    docker compose logs -f wordpress
    ;;
  cli)
    shift
    docker compose run --rm wpcli "$@"
    ;;
  backup)
    echo "Backing up database..."
    mkdir -p backups
    docker compose exec mysql mysqldump -uroot -p"WordPress_Dev123!" wordpress > "backups/backup_$(date +%Y%m%d_%H%M%S).sql"
    echo "Backup saved to backups/"
    ;;
  restore)
    if [ -z "$2" ]; then
      echo "Usage: ./dev.sh restore backups/filename.sql"
      exit 1
    fi
    echo "Restoring database from $2..."
    docker compose exec -T mysql mysql -uroot -p"WordPress_Dev123!" wordpress < "$2"
    echo "Restore complete."
    ;;
  *)
    echo "Usage: ./dev.sh [up|down|reset|logs|cli|backup|restore]"
    ;;
esac
