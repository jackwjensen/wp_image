# WordPress Docker Template

This is a boilerplate for creating Docker-based WordPress sites deployed to a Hetzner VPS via GitHub Actions. It follows the same deployment pattern as the other projects on this server (allegro-it-services, DonorLink).

## How to Use This Template to Create a New Site

When asked to create a new WordPress site from this template, follow these steps exactly:

### Step 1: Copy the template
Copy the entire contents of this directory to a new repo folder. The target folder should be at `C:\Users\Bruger\source\repos\<site-name>` (the user's standard repos location).

### Step 2: Customize for the domain
Given a domain like `example.com`, derive a site name (e.g., `example` or a slug the user provides). Then:

1. **Create `.env`** (from `.env.example`):
   ```env
   COMPOSE_FILE=docker-compose.yml
   COMPOSE_PROJECT_NAME=<site-name>
   ```

2. **Update `CLAUDE.md`** in the new repo — replace this template documentation with site-specific info (domain, site name, purpose).

3. **No changes needed** to `docker-compose.yml` or `docker-compose.production.yml` — they use `${COMPOSE_PROJECT_NAME}` from `.env`.

### Step 3: Initialize Git
```bash
cd <new-repo-folder>
git init
git add .
git commit -m "Initial WordPress setup from wp_image template"
```

### Step 4: Tell the user what to do next
After creating the repo, instruct the user to:

1. **Create a GitHub repo** and push:
   ```bash
   git remote add origin git@github.com:<user>/<repo-name>.git
   git push -u origin master
   ```

2. **Add GitHub Secrets** (same as other projects):
   - `HETZNER_HOST` — server IP
   - `HETZNER_SSH_KEY` — SSH private key

3. **Set up the server** (SSH into Hetzner):
   ```bash
   ./scripts/setup-server.sh <site-name> git@github.com:<user>/<repo-name>.git
   cd /opt/apps/<site-name>
   docker compose up -d
   ```

4. **Configure Nginx Proxy Manager**:
   - Add proxy host: `example.com` → `<site-name>-wordpress:80`
   - Enable SSL (Let's Encrypt)
   - The container name is `${COMPOSE_PROJECT_NAME}-wordpress` (set in docker-compose.production.yml)

5. **Start local dev**: `dev.bat up` then open `http://localhost:8080`

6. **Import existing site** (if migrating): Use Duplicator plugin to import, then commit wp-content changes.

## Architecture

- WordPress 6.7 + PHP 8.3 + Apache (official `wordpress:6.7-php8.3-apache` image)
- MySQL 8.4 database
- WP-CLI available via `docker compose run --rm wpcli wp <command>` (uses `cli` profile)
- No custom Dockerfile — uses official images directly

## Docker Compose Structure

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Base config + local dev (ports 8080, 3306 exposed, debug on) |
| `docker-compose.production.yml` | Production overrides (no ports, joins `nginx-proxy-network`, debug off, `DISALLOW_FILE_EDIT`) |

Merged in production via `COMPOSE_FILE=docker-compose.yml:docker-compose.production.yml` in the server's `.env`.

### Container naming
Production containers are named `${COMPOSE_PROJECT_NAME}-wordpress` and `${COMPOSE_PROJECT_NAME}-mysql`. This is how NPM routes to the correct site — each site has a unique `COMPOSE_PROJECT_NAME`.

### Network
- Production connects to the external `nginx-proxy-network` (shared with NPM, allegro-it-services, DonorLink)
- MySQL stays on the default internal network only (not exposed to proxy)

## Deployment

- **Trigger**: Push to `master` branch (or manual workflow dispatch)
- **Method**: GitHub Actions SSH into Hetzner server
- **Server path**: `/opt/apps/<repo-name>`
- **Process**: git pull → docker compose up --force-recreate -d → health check
- **Rollback**: Automatic on failure (reverts to previous commit, recreates containers)
- **GitHub Secrets required**: `HETZNER_HOST`, `HETZNER_SSH_KEY` (same secrets as DonorLink/Allegro)

## Server Layout (Hetzner)

All apps live under `/opt/apps/` on the same server:
```
/opt/apps/
├── allegro-it-services/    (existing)
├── DonorLink/              (existing)
├── <wp-site-1>/            (new WordPress site)
├── <wp-site-2>/            (new WordPress site)
└── <wp-site-3>/            (new WordPress site)
```

Nginx Proxy Manager handles routing:
- Each WordPress container joins `nginx-proxy-network`
- NPM proxy host maps domain → `<compose-project-name>-wordpress:80`

## What's Version Controlled

| Path | Tracked | Notes |
|------|---------|-------|
| `wp-content/themes/` | Yes | Theme files |
| `wp-content/plugins/` | Yes | Plugin files |
| `config/` | Yes | PHP config (upload limits etc.) |
| `wp-content/uploads/` | No | Docker volume, sync separately |
| `.env` | No | Contains passwords, created per environment |
| `backups/` | No | Local DB dumps |

## DB Migration Strategy

WordPress doesn't have a migration framework like Laravel/Django. The approach:
- **Plugin install/uninstall**: Do locally, commit plugin files. WordPress auto-runs `dbDelta()` on activation — schema converges.
- **Pull prod DB to local**: Use `./scripts/sync-db-from-prod.sh` (dumps, imports, URL search-replace).
- **Never push local DB to prod** — let WordPress/plugins handle their own schema upgrades.
- **Duplicator plugin** can be used for full site migrations (initial setup).

## Development Commands

| Command | Description |
|---------|-------------|
| `dev.bat up` | Start containers |
| `dev.bat down` | Stop containers |
| `dev.bat reset` | Destroy volumes and restart fresh |
| `dev.bat logs` | Follow WordPress logs |
| `dev.bat cli wp plugin list` | Run WP-CLI commands |
| `dev.bat backup` | Dump DB to `backups/` |
| `dev.bat restore backups/file.sql` | Restore DB from dump |

## Files Reference

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Base + local dev config |
| `docker-compose.production.yml` | Production overrides (no ports, nginx-proxy-network) |
| `.env.example` | Template for `.env` |
| `.github/workflows/deploy.yml` | GitHub Actions deploy-on-push |
| `config/uploads.ini` | PHP upload limits (256M) |
| `scripts/setup-server.sh` | One-time server setup script |
| `scripts/sync-db-from-prod.sh` | Pull production DB to local |
| `dev.bat` / `dev.sh` | Local development helper scripts |
