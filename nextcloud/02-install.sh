#!/bin/bash
source config.sh
source lib/functions.sh

log "📦 Установка пакетов..."
apt install -y nginx postgresql php-fpm php-gd php-curl php-mbstring \
    php-intl php-gmp php-bcmath php-xml php-imagick php-zip php-pgsql \
    wget unzip certbot python3-certbot-nginx

log "🗄️ PostgreSQL..."
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME OWNER $DB_USER ENCODING 'UTF8';"
sudo -u postgres psql -c "GRANT ALL ON DATABASE $DB_NAME TO $DB_USER;"

# ... (остальное как в основном скрипте)