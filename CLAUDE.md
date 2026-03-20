# WordPress Docker Template

This is a boilerplate for creating Docker-based WordPress sites deployed to a Hetzner VPS via GitHub Actions. It follows the same deployment pattern as the other projects on this server (allegro-it-services, DonorLink).

## How to Use This Template to Create a New Site

When asked to create a new WordPress site from this template, follow these steps exactly:

### Step 1: Copy the template
Copy the entire contents of this directory to a new repo folder. The target folder should be at `C:\Users\Bruger\source\repos\<site-name>` (the user's standard repos location). Remove the `.git` folder from the copy.

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

### Step 4: Create GitHub repo and push
Create a **private** GitHub repo using `gh` CLI and push:
```bash
cd <new-repo-folder>
gh repo create jackwjensen/<repo-name> --private --source=. --push
```
If the push fails due to workflow scope, tell the user to push from GitHub Desktop instead.

### Step 5: Tell the user what to do next
After creating the repo, instruct the user to:

1. **Generate SSH deploy key on the server** (GitHub requires a unique key per repo):
   ```bash
   ssh-keygen -t ed25519 -C "github-deploy-<site-name>" -f /root/.ssh/deploy_<site-name> -N ""
   ```

2. **Add the public key as a deploy key on GitHub**:
   - Go to: `https://github.com/jackwjensen/<repo-name>/settings/keys`
   - Add deploy key, paste output of `cat /root/.ssh/deploy_<site-name>.pub`
   - Check **Allow write access**

3. **Add GitHub Actions Secrets**:
   - `HETZNER_HOST` — server IP
   - `HETZNER_SSH_KEY` — paste output of `cat /root/.ssh/deploy_<site-name>` (the private key)

4. **Add SSH config alias on the server** (so git uses the correct key):
   ```bash
   cat >> /root/.ssh/config << 'EOF'

   Host github-<site-name>
       HostName github.com
       User git
       IdentityFile /root/.ssh/deploy_<site-name>
       IdentitiesOnly yes
   EOF
   ```

5. **Set up the server**:
   ```bash
   ./scripts/setup-server.sh <site-name> git@github-<site-name>:jackwjensen/<repo-name>.git
   ```
   This clones the repo, generates MySQL password, creates `.env`, starts containers, and fixes permissions.

6. **Configure Nginx Proxy Manager**:
   - Add proxy host: `example.com` → `<site-name>-wordpress:80` (port 80, NOT 8080)
   - Enable SSL (Let's Encrypt)
   - The container name is `${COMPOSE_PROJECT_NAME}-wordpress` (set in docker-compose.production.yml)

7. **Import existing site with Duplicator** (if migrating):
   - Complete the WordPress install wizard first (use throwaway values — Duplicator overwrites everything)
   - Copy Duplicator files to the server (scp or similar)
   - Run: `./scripts/import-duplicator.sh installer.php <archive.zip>`
   - Open `https://example.com/installer.php` in browser
   - **DB settings in Duplicator**: Host=`mysql` (NOT localhost), Name=`wordpress`, User=`root`, Password=(from .env)
   - After import: commit wp-content changes, push to deploy

8. **Start local dev**: `dev.bat up` then open `http://localhost:8080`

9. **Sync production DB to local** (after Duplicator import on prod):
   ```bash
   ./scripts/sync-db-from-prod.sh <site-name> <domain> http://localhost:8080
   ```

## Important Gotchas

- **DB host is `mysql`, not `localhost`** — inside Docker, each container has its own network. `localhost` inside the WordPress container refers to itself. The MySQL container is reachable via Docker DNS as `mysql` (the service name from docker-compose.yml).
- **NPM proxy target is port 80, not 8080** — Apache inside the WordPress container listens on port 80. Port 8080 is only the host mapping used in local dev.
- **Duplicator files go INSIDE the container** — files placed on the server filesystem aren't served by Apache. Use `docker compose cp` or the `import-duplicator.sh` script.
- **wp-content permissions** — the container runs Apache as `www-data`. After any file operations, fix ownership: `docker compose exec wordpress chown -R www-data:www-data /var/www/html/wp-content`
- **Uploads subdirectories** — after a fresh DB import, plugins may expect subdirectories under `wp-content/uploads/` that don't exist in the volume. Fix with: `docker compose exec wordpress chown -R www-data:www-data /var/www/html/wp-content/uploads` (the plugin will create its subdirectory on next request once permissions are correct).
- **WordPress install wizard must be completed first** — on a fresh container, WordPress shows its install wizard before any other URL works. Complete it with throwaway values before running Duplicator.
- **GitHub deploy keys are unique per repo** — the same SSH public key cannot be added to multiple repos. Use SSH config host aliases to map each repo to its own key.
- **Production .env is critical** — without it, containers start in dev mode (ports exposed, not on nginx-proxy-network). The `setup-server.sh` script creates this automatically.
- **WP-CLI is NOT in the WordPress container** — the official `wordpress:` image does not include `wp`. The `wpcli` service in docker-compose.yml uses a separate `wordpress:cli-*` image and is for local dev only (behind the `cli` profile). On production, use MySQL queries directly for DB operations.
- **Table prefix** — Duplicator handles table prefixes automatically during import. Only becomes an issue if the MySQL volume is recreated (`docker compose down -v`) after a Duplicator import, as the Docker entrypoint regenerates wp-config.php with the default `wp_` prefix. Avoid resetting volumes after import.
- **Windows has no `export` or Git Bash by default** — the sync-db-from-prod.sh script requires bash with `export`. Use `sync-db-from-prod.bat` on Windows, or do the steps manually (see "Manual DB Sync on Windows" below).
- **NPM "Force SSL" causes redirect loops** — NPM terminates SSL and forwards HTTP to the container. The WordPress Docker image already handles `X-Forwarded-Proto`. Do NOT enable "Force SSL" in NPM — the built-in wp-config.php snippet handles this.

## Manual DB Sync on Windows

If the sync scripts don't work (SSH passphrase prompts, no bash), do it step by step:

1. **On the server** (SSH session):
   ```bash
   cd /opt/apps/<site-name>
   docker compose exec -T mysql mysqldump -uroot -p$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2) wordpress > /tmp/<site-name>-dump.sql
   ```

2. **On Windows** (cmd):
   ```cmd
   scp root@<server-ip>:/tmp/<site-name>-dump.sql backups\prod_sync.sql
   docker compose exec -T mysql mysql -uroot -pWordPress_Dev123! wordpress < backups\prod_sync.sql
   docker compose exec mysql mysql -uroot -pWordPress_Dev123! wordpress -e "UPDATE wp_options SET option_value='http://localhost:8080' WHERE option_name IN ('siteurl','home');"
   docker compose exec wordpress chown -R www-data:www-data /var/www/html/wp-content/uploads
   ```

## Architecture

- WordPress 6.7 + PHP 8.3 + Apache (official `wordpress:6.7-php8.3-apache` image)
- MySQL 8.4 database
- WP-CLI available locally via `docker compose run --rm wpcli wp <command>` (uses `cli` profile, local dev only — NOT available in production)
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
- **GitHub Secrets required**: `HETZNER_HOST`, `HETZNER_SSH_KEY` (unique deploy key per repo)

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
- **Initial setup**: Use Duplicator on production, then sync DB to local.
- **Plugin install/uninstall**: Do locally, commit plugin files. WordPress auto-runs `dbDelta()` on activation — schema converges.
- **Pull prod DB to local**: Use `./scripts/sync-db-from-prod.sh` (dumps, imports, URL search-replace).
- **Never push local DB to prod** — let WordPress/plugins handle their own schema upgrades.
- **User content** (posts, comments) lives only in production. Sync prod → local when you need fresh data.

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
| `scripts/setup-server.sh` | One-time server setup (clones, creates .env, starts containers, fixes permissions) |
| `scripts/import-duplicator.sh` | Copy Duplicator files into container and show DB credentials |
| `scripts/sync-db-from-prod.sh` | Pull production DB to local (bash/Linux/Mac) |
| `scripts/sync-db-from-prod.bat` | Pull production DB to local (Windows cmd) |
| `dev.bat` / `dev.sh` | Local development helper scripts |
