@echo off
setlocal

if "%1"=="" goto up
if "%1"=="up" goto up
if "%1"=="down" goto down
if "%1"=="stop" goto down
if "%1"=="reset" goto reset
if "%1"=="logs" goto logs
if "%1"=="cli" goto cli
if "%1"=="backup" goto backup
if "%1"=="restore" goto restore
echo Unknown command: %1
echo Usage: dev.bat [up^|down^|reset^|logs^|cli^|backup^|restore]
goto end

:up
echo Starting WordPress...
docker compose up --build -d
echo.
echo WordPress: http://localhost:8080
echo.
goto end

:down
docker compose down
goto end

:reset
docker compose down -v
docker compose up --build -d
echo.
echo WordPress reset complete: http://localhost:8080
goto end

:logs
docker compose logs -f wordpress
goto end

:cli
shift
docker compose run --rm wpcli %*
goto end

:backup
echo Backing up database...
if not exist backups mkdir backups
docker compose exec mysql mysqldump -uroot -p"WordPress_Dev123!" wordpress > backups\backup_%date:~-4%%date:~3,2%%date:~0,2%.sql
echo Backup saved to backups\
goto end

:restore
if "%2"=="" (
    echo Usage: dev.bat restore backups\filename.sql
    goto end
)
echo Restoring database from %2...
docker compose exec -T mysql mysql -uroot -p"WordPress_Dev123!" wordpress < %2
echo Restore complete.
goto end

:end
endlocal
