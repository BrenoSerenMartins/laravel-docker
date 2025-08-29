#!/bin/bash

# =============================================
# Laravel Project Creator for Docker Workspace
# =============================================
# Usage: ./scripts/create-new-project.sh <project-name>
#
# This script creates a new Laravel project and automatically
# generates the Nginx configuration file for access via <project-name>.local
# =============================================

set -e

# --- Colors and Styles ---
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Relative Paths ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"

# --- Input Validation ---
if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Error:${RESET} Project name is required."
  echo -e "${YELLOW}Usage:${RESET} $0 <project-name>"
  exit 1
fi

PROJECT_NAME="$1"

# Validate project name (lowercase letters, numbers, hyphens, and dots)
if ! [[ "$PROJECT_NAME" =~ ^[a-z0-9.-]+$ ]]; then
    echo -e "${RED}${BOLD}Error:${RESET} Invalid project name."
    echo -e "${YELLOW}Use only lowercase letters, numbers, hyphens, and dots (e.g., my-project.local).${RESET}"
    exit 1
fi

# --- Paths ---
WWW_PATH="${PROJECT_ROOT}/var/www/${PROJECT_NAME}"
CONTAINER_WWW_PATH="/var/www/${PROJECT_NAME}"
NGINX_CONF_PATH="${PROJECT_ROOT}/nginx/conf.d/${PROJECT_NAME}.conf"

# --- Check for existing project ---
if [ -d "$WWW_PATH" ] || [ -f "$NGINX_CONF_PATH" ]; then
    echo -e "${RED}${BOLD}Error:${RESET} A project with the name '${PROJECT_NAME}' already exists."
    exit 1
fi

echo -e "${CYAN}============================================="
echo -e "${BOLD}Laravel Project Creator${RESET}"
echo -e "=============================================${RESET}"

# === Automatic creation of the unique database for the project ===
DB_DATABASE="laravel_$(echo "$PROJECT_NAME" | sed 's/[.-]/_/g')" # Replaces hyphens and dots with underscores for the DB
DB_USERNAME="laravel"
DB_PASSWORD="laravel"
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD="root"

echo -e "${YELLOW}Creating MySQL database: ${DB_DATABASE}...${RESET}"
# Waits for MySQL to be ready before creating the database
for i in $(seq 1 30); do
  if docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1;" 2>/dev/null;
  then
    break
  else
    sleep 2
  fi
done

# Creates the database if it doesn't exist using root
docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS \`${DB_DATABASE}\`;"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔ Database ${DB_DATABASE} ready!${RESET}"
else
  echo -e "${RED}✖ Failed to create database ${DB_DATABASE}.${RESET}"
  exit 1
fi

# Ensures that the laravel@'%' and laravel@'localhost' users exist, correct password, correct plugin and grants permissions
docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';"
docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USERNAME}'@'%';"
docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"


# Creates the .env on the host and copies it into the container (ensuring laravel/laravel)
echo -e "${YELLOW}Configuring project .env with MySQL credentials...${RESET}"
TMP_ENV_PATH="/tmp/${PROJECT_NAME}.env"
cat > "${TMP_ENV_PATH}" <<EOL
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://${PROJECT_NAME}

LOG_CHANNEL=stack
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=${DB_DATABASE}
DB_USERNAME=laravel
DB_PASSWORD=laravel

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DRIVER=local
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

MEMCACHED_HOST=127.0.0.1

REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS="hello@${PROJECT_NAME}"
MAIL_FROM_NAME="\${APP_NAME}"

AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
AWS_DEFAULT_REGION=us-east-1
AWS_BUCKET=
AWS_USE_PATH_STYLE_ENDPOINT=false

PUSHER_APP_ID=
PUSHER_APP_KEY=
PUSHER_APP_SECRET=
PUSHER_HOST=
PUSHER_PORT=443
PUSHER_SCHEME=https
PUSHER_APP_CLUSTER=mt1

VITE_APP_NAME="\${APP_NAME}"
VITE_PUSHER_APP_KEY="\${PUSHER_APP_KEY}"
VITE_PUSHER_HOST="\${PUSHER_HOST}"
VITE_PUSHER_PORT="\${PUSHER_PORT}"
VITE_PUSHER_SCHEME="\${PUSHER_SCHEME}"
VITE_PUSHER_APP_CLUSTER="\${PUSHER_APP_CLUSTER}"
EOL

# Installs Laravel in the container, with the correct .env
echo -e "${YELLOW}Installing Laravel via Composer...${RESET}"
docker compose run --rm --workdir /var/www php-fpm composer create-project laravel/laravel ${PROJECT_NAME}

# Copy the .env file to the project directory
docker compose cp "${TMP_ENV_PATH}" "php-fpm:${CONTAINER_WWW_PATH}/.env"
rm "${TMP_ENV_PATH}"


# Clears the configuration cache before migrations
echo -e "${YELLOW}Clearing Laravel configuration cache...${RESET}"
docker compose run --rm --workdir ${CONTAINER_WWW_PATH} php-fpm php artisan config:clear
echo -e "${GREEN}✔ Configuration cache cleared!${RESET}"

# Generates the APP_KEY automatically
echo -e "${YELLOW}Generating Laravel APP_KEY...${RESET}"
docker compose run --rm --workdir ${CONTAINER_WWW_PATH} php-fpm php artisan key:generate
echo -e "${GREEN}✔ APP_KEY generated!${RESET}"

# Waits for MySQL to be ready before running migrations
echo -e "${YELLOW}Waiting for MySQL to be available to run migrations...${RESET}"
for i in $(seq 1 30); do
  if docker compose exec -T mysql mysql -u${DB_USERNAME} -p${DB_PASSWORD} -e "SELECT 1;" 2>/dev/null;
  then
    echo -e "${GREEN}✔ MySQL is ready!${RESET}"
    break
  else
    echo -e "${YELLOW}Waiting for MySQL... (${i}/30)${RESET}"
    sleep 2
  fi
  if [ "$i" -eq 30 ]; then
    echo -e "${RED}✖ MySQL did not respond in time. Migrations were not executed.${RESET}"
    break
  fi
done

# Restarts MySQL to ensure updated privileges
echo -e "${YELLOW}Restarting MySQL to ensure updated privileges...${RESET}"
docker compose restart mysql
echo -e "${GREEN}✔ MySQL restarted!${RESET}"

# Waits for MySQL to be ready after restart
echo -e "${YELLOW}Waiting for MySQL to be available after restart...${RESET}"
for i in $(seq 1 30); do
  if docker compose exec -T mysql mysql -u${DB_USERNAME} -p${DB_PASSWORD} -e "SELECT 1;" 2>/dev/null;
  then
    echo -e "${GREEN}✔ MySQL is ready after restart!${RESET}"
    break
  else
    echo -e "${YELLOW}Waiting for MySQL... (${i}/30)${RESET}"
    sleep 2
  fi
  if [ "$i" -eq 30 ]; then
    echo -e "${RED}✖ MySQL did not respond in time after restart.${RESET}"
    exit 1
  fi
done

# Runs migrations
echo -e "${YELLOW}Running Laravel migrations...${RESET}"
docker compose run --rm --workdir ${CONTAINER_WWW_PATH} php-fpm php artisan migrate --force
echo -e "${GREEN}✔ Migrations executed!${RESET}"

# Clears all Laravel caches (now that the tables exist)
echo -e "${YELLOW}Clearing all Laravel caches...${RESET}"
docker compose exec php-fpm bash -c "cd ${CONTAINER_WWW_PATH} && php artisan config:clear && php artisan cache:clear && php artisan route:clear && php artisan view:clear"
echo -e "${GREEN}✔ Laravel caches cleared!${RESET}"

echo -e "${YELLOW}Generating Nginx configuration at:${RESET} $NGINX_CONF_PATH"
cat > "$NGINX_CONF_PATH" <<EOL
server {
    listen 80;
    server_name ${PROJECT_NAME};
    root ${CONTAINER_WWW_PATH}/public;
    index index.php index.html;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ \.php$ {
        fastcgi_pass laravel-php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL



# Corrects permissions and owner of storage and bootstrap/cache folders
echo -e "${YELLOW}Adjusting permissions and owner of storage and bootstrap/cache folders...${RESET}"
docker compose run --rm --workdir ${CONTAINER_WWW_PATH} php-fpm chown -R www-data:www-data storage bootstrap/cache
docker compose run --rm --workdir ${CONTAINER_WWW_PATH} php-fpm chmod -R 775 storage bootstrap/cache
echo -e "${GREEN}✔ Permissions and owner adjusted!${RESET}"

echo -e "${GREEN}✔ Nginx configuration created!${RESET}"

echo -e "\n${CYAN}============================================="
echo -e "${BOLD}Project ready!${RESET}"
echo -e "=============================================${RESET}"
echo -e "${BOLD}Directory:${RESET} $WWW_PATH"
echo -e "${BOLD}Nginx conf:${RESET} $NGINX_CONF_PATH"

# Adds the entry to /etc/hosts if it doesn't exist
HOSTS_LINE="127.0.0.1   ${PROJECT_NAME}"
if grep -q "${PROJECT_NAME}" /etc/hosts; then
  echo -e "${YELLOW}Entry already exists in /etc/hosts:${RESET} ${PROJECT_NAME}"
else
  echo -e "${YELLOW}Adding entry to /etc/hosts...${RESET}"
  if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Root permission required to edit /etc/hosts. Sudo will be requested...${RESET}"
    echo "$HOSTS_LINE" | sudo tee -a /etc/hosts > /dev/null
  else
    echo "$HOSTS_LINE" >> /etc/hosts
  fi
  echo -e "${GREEN}✔ Entry added to /etc/hosts!${RESET}"
fi


# Restarts the webserver to apply new configuration
echo -e "${YELLOW}Restarting the webserver (nginx)...${RESET}"
docker compose restart webserver
echo -e "${GREEN}✔ Webserver restarted!${RESET}"

echo -e "${BOLD}Access URL:${RESET} http://${PROJECT_NAME}"
echo -e "\n${GREEN}All set! Open the URL above in your browser.${RESET}"