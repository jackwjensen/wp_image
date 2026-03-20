# WordPress Docker Template

A boilerplate for deploying Docker-based WordPress sites to a Hetzner VPS with GitHub Actions CI/CD and Nginx Proxy Manager routing.

## Features

- **WordPress 6.7** with PHP 8.3 and Apache (official image)
- **MySQL 8.4** database
- **WP-CLI** for command-line management
- **Docker Compose** with separate local/production configurations
- **GitHub Actions** auto-deploy on push to master
- **Automatic rollback** on failed deployments
- **Nginx Proxy Manager** integration via external Docker network

## Quick Start

### Local Development

1. Copy this template to a new folder for your site
2. Create `.env` from `.env.example`:
   ```env
   COMPOSE_FILE=docker-compose.yml
   COMPOSE_PROJECT_NAME=my-site
   ```
3. Start containers:
   ```bash
   dev.bat up        # Windows
   ./dev.sh up       # Linux/Mac/Git Bash
   ```
4. Open http://localhost:8080 and complete the WordPress setup

### Deploy to Production

1. Create a GitHub repo and push
2. Add secrets: `HETZNER_HOST` and `HETZNER_SSH_KEY`
3. On the server, run:
   ```bash
   ./scripts/setup-server.sh <site-name> <repo-url>
   ```
4. Add a proxy host in Nginx Proxy Manager: `yourdomain.com` → `<site-name>-wordpress:80`
5. Push to master — deploys automatically

## Project Structure

```
├── .github/workflows/deploy.yml    # CI/CD pipeline
├── config/uploads.ini              # PHP upload limits
├── scripts/
│   ├── setup-server.sh             # One-time server setup
│   └── sync-db-from-prod.sh        # Pull prod DB to local
├── wp-content/
│   ├── themes/                     # Version controlled
│   ├── plugins/                    # Version controlled
│   └── uploads/                    # Git-ignored (Docker volume)
├── docker-compose.yml              # Base + local dev config
├── docker-compose.production.yml   # Production overrides
├── dev.bat / dev.sh                # Dev helper scripts
└── .env.example                    # Environment template
```

## Development Commands

| Command | Description |
|---------|-------------|
| `dev.bat up` | Start containers |
| `dev.bat down` | Stop containers |
| `dev.bat reset` | Destroy volumes and restart fresh |
| `dev.bat logs` | Follow WordPress logs |
| `dev.bat cli wp plugin list` | Run WP-CLI commands |
| `dev.bat backup` | Dump database to `backups/` |
| `dev.bat restore backups/file.sql` | Restore database from file |

## Migrating an Existing Site

1. Install the [Duplicator](https://wordpress.org/plugins/duplicator/) plugin on your existing site
2. Create a Duplicator package
3. Set up local dev with this template
4. Import the Duplicator package
5. Commit the `wp-content/themes/` and `wp-content/plugins/` changes
6. Push to deploy

## Database Strategy

WordPress plugins manage their own database schema via `dbDelta()`. There are no migration files — instead:

- **Install/uninstall plugins locally**, commit the files, push. WordPress handles schema on activation.
- **Pull prod DB to local** with `./scripts/sync-db-from-prod.sh` (includes URL search-replace).
- **Never push local DB to production** — let WordPress converge the schema on deploy.

## License

[MIT](LICENSE)

## Developed by

[Allegro IT ApS](https://allegroit.dk/) — International project management with team spirit.
