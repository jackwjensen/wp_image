@echo off
setlocal
REM Pull production database to local development.
REM Usage: sync-db-from-prod.bat <server-ip> <site-name> [prod-domain]
REM Example: sync-db-from-prod.bat 89.167.41.204 my-wp-site designtest.example.com

if "%1"=="" (
    echo Usage: sync-db-from-prod.bat ^<server-ip^> ^<site-name^> [prod-domain]
    goto end
)
if "%2"=="" (
    echo Usage: sync-db-from-prod.bat ^<server-ip^> ^<site-name^> [prod-domain]
    goto end
)

set SERVER=%1
set SITE_NAME=%2
set PROD_DOMAIN=%3

if not exist backups mkdir backups

echo Step 1: Dumping production database...
echo   (You will be prompted for your SSH passphrase)
ssh root@%SERVER% "cd /opt/apps/%SITE_NAME% && docker compose exec -T mysql mysqldump -uroot -p$(grep MYSQL_ROOT_PASSWORD .env | cut -d= -f2) wordpress" > backups\prod_sync.sql
if errorlevel 1 (
    echo ERROR: Failed to dump production database. Check SSH connection.
    goto end
)

echo Step 2: Importing into local database...
docker compose exec -T mysql mysql -uroot -pWordPress_Dev123! wordpress < backups\prod_sync.sql

echo Step 3: Fixing URLs...
if not "%PROD_DOMAIN%"=="" (
    docker compose exec mysql mysql -uroot -pWordPress_Dev123! wordpress -e "UPDATE wp_options SET option_value='http://localhost:8080' WHERE option_name IN ('siteurl','home');"
    docker compose exec mysql mysql -uroot -pWordPress_Dev123! wordpress -e "UPDATE wp_posts SET post_content = REPLACE(post_content, 'https://%PROD_DOMAIN%', 'http://localhost:8080') WHERE post_content LIKE '%%%PROD_DOMAIN%%%';"
    docker compose exec mysql mysql -uroot -pWordPress_Dev123! wordpress -e "UPDATE wp_postmeta SET meta_value = REPLACE(meta_value, 'https://%PROD_DOMAIN%', 'http://localhost:8080') WHERE meta_value LIKE '%%%PROD_DOMAIN%%%';"
)

echo Step 4: Fixing uploads permissions...
docker compose exec wordpress chown -R www-data:www-data /var/www/html/wp-content/uploads

echo.
echo Done! Local DB is now a copy of production.
echo Open http://localhost:8080

:end
endlocal
