#!/bin/bash
# =============================================
# Completely removes a Laravel project from the Dockerized environment
# =============================================
# Usage: ./scripts/remove-project.sh <project-name>
# =============================================

set -e

# --- Colors and Styles ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

# --- Relative Paths ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "$SCRIPT_DIR" )"

# --- Input Validation ---
if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Usage:${RESET} $0 <project-name>"
  exit 1
fi

PROJECT_NAME="$1"

# --- Paths ---
WWW_PATH="${PROJECT_ROOT}/var/www/$PROJECT_NAME"
NGINX_CONF_PATH="${PROJECT_ROOT}/nginx/conf.d/${PROJECT_NAME}.conf"
DB_DATABASE="laravel_$(echo "$PROJECT_NAME" | sed 's/[.-]/_/g')" # Replaces hyphens and dots with underscores for the DB

# --- Confirmation ---
echo -e "${YELLOW}${BOLD}Attention:${RESET} This action will permanently delete the following:"
echo -e "  - Project directory: ${WWW_PATH}"
echo -e "  - Nginx configuration: ${NGINX_CONF_PATH}"
echo -e "  - MySQL database: ${DB_DATABASE}"
echo -e "  - Entry in /etc/hosts for ${PROJECT_NAME}"
echo -e ""
read -p "Are you sure you want to continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation canceled."
    exit 1
fi

# Remove database
echo -e "${YELLOW}Removing MySQL database: ${DB_DATABASE}...${RESET}"
docker compose exec -T mysql mysql -uroot -proot -e "DROP DATABASE IF EXISTS ${DB_DATABASE};"
echo -e "${GREEN}✔ Database removed!${RESET}"

# Remove project directory
if [ -d "$WWW_PATH" ]; then
  echo -e "${YELLOW}Removing project directory: $WWW_PATH${RESET}"
  rm -rf "$WWW_PATH"
  echo -e "${GREEN}✔ Directory removed!${RESET}"
else
  echo -e "${YELLOW}Project directory not found: $WWW_PATH${RESET}"
fi

# Remove Nginx configuration
if [ -f "$NGINX_CONF_PATH" ]; then
  echo -e "${YELLOW}Removing Nginx configuration: $NGINX_CONF_PATH${RESET}"
  rm -f "$NGINX_CONF_PATH"
  echo -e "${GREEN}✔ Nginx configuration removed!${RESET}"
else
  echo -e "${YELLOW}Nginx configuration not found: $NGINX_CONF_PATH${RESET}"
fi

# Remove entry from /etc/hosts
HOSTS_LINE="127.0.0.1   ${PROJECT_NAME}"
if grep -q "${PROJECT_NAME}" /etc/hosts; then
  echo -e "${YELLOW}Removing entry from /etc/hosts...${RESET}"
  if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Root permission required to edit /etc/hosts. Sudo will be requested...${RESET}"
    sudo sed -i "/${PROJECT_NAME}/d" /etc/hosts
  else
    sed -i "/${PROJECT_NAME}/d" /etc/hosts
  fi
  echo -e "${GREEN}✔ Entry removed from /etc/hosts!${RESET}"
else
  echo -e "${YELLOW}Entry in /etc/hosts not found.${RESET}"
fi

# Restart webserver
echo -e "${YELLOW}Restarting webserver (nginx)...${RESET}"
docker compose restart webserver
echo -e "${GREEN}✔ Webserver restarted!${RESET}"


echo -e "\n${GREEN}${BOLD}Project ${PROJECT_NAME} completely removed!${RESET}"
