#!/bin/bash
# =============================================
# Remove totalmente um projeto Laravel do ambiente Dockerizado
# =============================================
# Uso: ./scripts/remove-project.sh <nome-do-projeto>
# =============================================

set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Uso:${RESET} $0 <nome-do-projeto>"
  exit 1
fi

PROJECT_NAME="$1"
WWW_PATH="/home/brenosm/me/developments/Laravel/var/www/$PROJECT_NAME"
NGINX_CONF_PATH="/home/brenosm/me/developments/Laravel/nginx/conf.d/${PROJECT_NAME}.local.conf"
DB_DATABASE="laravel_${PROJECT_NAME}"

# Remove banco de dados
echo -e "${YELLOW}Removendo banco de dados MySQL: ${DB_DATABASE}...${RESET}"
docker compose exec -T mysql mysql -uroot -proot -e "DROP DATABASE IF EXISTS \`${DB_DATABASE}\`;"
echo -e "${GREEN}✔ Banco de dados removido!${RESET}"

# Remove diretório do projeto
if [ -d "$WWW_PATH" ]; then
  echo -e "${YELLOW}Removendo diretório do projeto: $WWW_PATH${RESET}"
  rm -rf "$WWW_PATH"
  echo -e "${GREEN}✔ Diretório removido!${RESET}"
else
  echo -e "${YELLOW}Diretório do projeto não encontrado: $WWW_PATH${RESET}"
fi

# Remove configuração do Nginx
if [ -f "$NGINX_CONF_PATH" ]; then
  echo -e "${YELLOW}Removendo configuração Nginx: $NGINX_CONF_PATH${RESET}"
  rm -f "$NGINX_CONF_PATH"
  echo -e "${GREEN}✔ Configuração Nginx removida!${RESET}"
else
  echo -e "${YELLOW}Configuração Nginx não encontrada: $NGINX_CONF_PATH${RESET}"
fi

# Remove entrada do /etc/hosts
HOSTS_LINE="127.0.0.1   ${PROJECT_NAME}.local"
if grep -q "${PROJECT_NAME}\.local" /etc/hosts; then
  echo -e "${YELLOW}Removendo entrada do /etc/hosts...${RESET}"
  if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Permissão de root necessária para editar /etc/hosts. Será solicitado sudo...${RESET}"
    sudo sed -i "/${PROJECT_NAME}\.local/d" /etc/hosts
  else
    sed -i "/${PROJECT_NAME}\.local/d" /etc/hosts
  fi
  echo -e "${GREEN}✔ Entrada removida do /etc/hosts!${RESET}"
else
  echo -e "${YELLOW}Entrada do /etc/hosts não encontrada.${RESET}"
fi

echo -e "${GREEN}${BOLD}Projeto ${PROJECT_NAME} removido completamente!${RESET}"
