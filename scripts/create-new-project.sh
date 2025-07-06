echo "Projeto $PROJECT_NAME criado em $WWW_PATH."
echo "Arquivo Nginx: $NGINX_CONF_PATH"
echo "Adicione ${PROJECT_NAME}.local ao seu /etc/hosts."

#!/bin/bash
# =============================================
# Laravel Project Creator for Docker Workspace
# =============================================
# Usage: ./scripts/create-new-project.sh <project-name>
#
# Este script cria um novo projeto Laravel e gera automaticamente
# o arquivo de configuração Nginx para acesso via <project-name>.local
# =============================================

set -e

CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
BOLD='\033[1m'
RESET='\033[0m'

if [ -z "$1" ]; then
  echo -e "${RED}${BOLD}Usage:${RESET} $0 <project-name>"
  exit 1
fi

PROJECT_NAME="$1"
WWW_PATH="/home/brenosm/me/developments/Laravel/var/www/$PROJECT_NAME"
NGINX_CONF_PATH="/home/brenosm/me/developments/Laravel/nginx/conf.d/${PROJECT_NAME}.local.conf"

echo -e "${CYAN}============================================="
echo -e "${BOLD}Laravel Project Creator${RESET}"
echo -e "=============================================${RESET}"

echo -e "${YELLOW}Criando diretório do projeto em:${RESET} $WWW_PATH"
mkdir -p "$WWW_PATH"








# === Criação automática do banco de dados único para o projeto ===
DB_DATABASE="laravel_${PROJECT_NAME}"
DB_USERNAME="laravel"
DB_PASSWORD="laravel"
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD="root"

echo -e "${YELLOW}Criando banco de dados MySQL: ${DB_DATABASE}...${RESET}"
# Aguarda o MySQL estar pronto antes de criar o banco
for i in $(seq 1 30); do
  if docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "SELECT 1;" 2>/dev/null; then
    break
  else
    sleep 2
  fi
done

# Cria o banco de dados se não existir usando root
docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS \`${DB_DATABASE}\`;"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔ Banco de dados ${DB_DATABASE} pronto!${RESET}"
else
  echo -e "${RED}✖ Falha ao criar banco de dados ${DB_DATABASE}.${RESET}"
  exit 1
fi

# Garante que o usuário laravel@'%' e laravel@'localhost' existem, senha correta, plugin correto e concede permissões
docker compose exec -T mysql bash -c "mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD}" <<EOSQL
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USERNAME}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
ALTER USER '${DB_USERNAME}'@'%' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
ALTER USER '${DB_USERNAME}'@'localhost' IDENTIFIED WITH mysql_native_password BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USERNAME}'@'%';
GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USERNAME}'@'localhost';
FLUSH PRIVILEGES;
SELECT user,host,plugin FROM mysql.user WHERE user='${DB_USERNAME}';
EOSQL
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔ Usuários, plugin e permissões garantidos para ${DB_USERNAME} em ${DB_DATABASE}!${RESET}"
else
  echo -e "${RED}✖ Falha ao garantir usuários/permissões/plugin para ${DB_USERNAME} em ${DB_DATABASE}.${RESET}"
  exit 1
fi

# Força flush de privilégios extra
docker compose exec -T mysql mysql -u${MYSQL_ROOT_USER} -p${MYSQL_ROOT_PASSWORD} -e "FLUSH PRIVILEGES;"


# Cria o .env no host e copia para dentro do container (garantindo laravel/laravel)
echo -e "${YELLOW}Configurando .env do projeto com credenciais do MySQL...${RESET}"
cat > "/tmp/${PROJECT_NAME}.env" <<EOL
APP_NAME=Laravel
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://${PROJECT_NAME}.local

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
MAIL_HOST=mailpit
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="${PROJECT_NAME}"

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

VITE_APP_NAME="${PROJECT_NAME}"
VITE_PUSHER_APP_KEY="
VITE_PUSHER_HOST="
VITE_PUSHER_PORT="
VITE_PUSHER_SCHEME="
VITE_PUSHER_APP_CLUSTER="
EOL

# Instala o Laravel no container, já com o .env correto
echo -e "${YELLOW}Instalando Laravel no container...${RESET}"
docker compose run --rm php-fpm bash -c "cd /var/www && composer create-project --no-scripts laravel/laravel $PROJECT_NAME"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✔ Projeto Laravel criado com sucesso!${RESET}"
else
  echo -e "${RED}✖ Falha ao criar o projeto Laravel.${RESET}"
  exit 1
fi

docker compose cp "/tmp/${PROJECT_NAME}.env" php-fpm:/var/www/$PROJECT_NAME/.env
rm "/tmp/${PROJECT_NAME}.env"
echo -e "${GREEN}✔ .env configurado!${RESET}"

# Limpa o cache de configuração antes das migrations
echo -e "${YELLOW}Limpando cache de configuração do Laravel...${RESET}"
docker compose run --rm php-fpm bash -c "cd /var/www/$PROJECT_NAME && php artisan config:clear"
echo -e "${GREEN}✔ Cache de configuração limpo!${RESET}"

# Gera a APP_KEY automaticamente
echo -e "${YELLOW}Gerando APP_KEY do Laravel...${RESET}"
docker compose run --rm php-fpm bash -c "cd /var/www/$PROJECT_NAME && php artisan key:generate"
echo -e "${GREEN}✔ APP_KEY gerada!${RESET}"

# Aguarda o MySQL estar pronto antes de rodar as migrations
echo -e "${YELLOW}Aguardando o MySQL ficar disponível para rodar as migrations...${RESET}"
for i in $(seq 1 30); do
  if docker compose exec -T mysql mysql -ularavel -plaravel -e "SELECT 1;" 2>/dev/null; then
    echo -e "${GREEN}✔ MySQL está pronto!${RESET}"
    break
  else
    echo -e "${YELLOW}Aguardando MySQL... (${i}/30)${RESET}"
    sleep 2
  fi
  if [ "$i" -eq 30 ]; then
    echo -e "${RED}✖ MySQL não respondeu a tempo. Migrations não foram executadas.${RESET}"
    break
  fi
done



# Reinicia o MySQL para garantir privilégios atualizados
echo -e "${YELLOW}Reiniciando o MySQL para garantir privilégios atualizados...${RESET}"
docker compose restart mysql
echo -e "${GREEN}✔ MySQL reiniciado!${RESET}"

# Aguarda o MySQL estar pronto após o restart
echo -e "${YELLOW}Aguardando o MySQL ficar disponível após o restart...${RESET}"
for i in $(seq 1 30); do
  if docker compose exec -T mysql mysql -ularavel -plaravel -e "SELECT 1;" 2>/dev/null; then
    echo -e "${GREEN}✔ MySQL está pronto após o restart!${RESET}"
    break
  else
    echo -e "${YELLOW}Aguardando MySQL... (${i}/30)${RESET}"
    sleep 2
  fi
  if [ "$i" -eq 30 ]; then
    echo -e "${RED}✖ MySQL não respondeu a tempo após o restart.${RESET}"
    exit 1
  fi
done

# Roda as migrations
echo -e "${YELLOW}Executando migrations do Laravel...${RESET}"
docker compose run --rm php-fpm bash -c "cd /var/www/$PROJECT_NAME && php artisan migrate --force"
echo -e "${GREEN}✔ Migrations executadas!${RESET}"

# Limpa todos os caches do Laravel (agora que as tabelas existem)
echo -e "${YELLOW}Limpando todos os caches do Laravel...${RESET}"
docker compose exec php-fpm bash -c "cd /var/www/$PROJECT_NAME && php artisan config:clear && php artisan cache:clear && php artisan route:clear && php artisan view:clear"
echo -e "${GREEN}✔ Caches do Laravel limpos!${RESET}"

echo -e "${YELLOW}Gerando configuração Nginx em:${RESET} $NGINX_CONF_PATH"
cat > "$NGINX_CONF_PATH" <<EOL
server {
    listen 80;
    server_name ${PROJECT_NAME}.local;
    root /var/www/${PROJECT_NAME}/public;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

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



# Corrige permissões e dono das pastas storage e bootstrap/cache
echo -e "${YELLOW}Ajustando permissões e dono das pastas storage e bootstrap/cache...${RESET}"
docker compose run --rm php-fpm bash -c "cd /var/www/$PROJECT_NAME && chown -R www-data:www-data storage bootstrap/cache && chmod -R 775 storage bootstrap/cache"
echo -e "${GREEN}✔ Permissões e dono ajustados!${RESET}"

echo -e "${GREEN}✔ Configuração Nginx criada!${RESET}"

echo -e "\n${CYAN}============================================="
echo -e "${BOLD}Projeto pronto!${RESET}"
echo -e "=============================================${RESET}"
echo -e "${BOLD}Diretório:${RESET} $WWW_PATH"
echo -e "${BOLD}Nginx conf:${RESET} $NGINX_CONF_PATH"

# Adiciona a entrada no /etc/hosts se não existir
HOSTS_LINE="127.0.0.1   ${PROJECT_NAME}.local"
if grep -q "${PROJECT_NAME}\.local" /etc/hosts; then
  echo -e "${YELLOW}Entrada já existe em /etc/hosts:${RESET} ${PROJECT_NAME}.local"
else
  echo -e "${YELLOW}Adicionando entrada em /etc/hosts...${RESET}"
  if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Permissão de root necessária para editar /etc/hosts. Será solicitado sudo...${RESET}"
    echo "$HOSTS_LINE" | sudo tee -a /etc/hosts > /dev/null
  else
    echo "$HOSTS_LINE" >> /etc/hosts
  fi
  echo -e "${GREEN}✔ Entrada adicionada em /etc/hosts!${RESET}"
fi


# Reinicia o webserver para aplicar nova configuração
echo -e "${YELLOW}Reiniciando o webserver (nginx)...${RESET}"
docker compose restart webserver
echo -e "${GREEN}✔ Webserver reiniciado!${RESET}"

echo -e "${BOLD}URL de acesso:${RESET} http://${PROJECT_NAME}.local"
echo -e "\n${GREEN}Tudo pronto! Abra a URL acima no navegador.${RESET}"
