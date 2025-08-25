#!/bin/bash

# One-click установка Nextcloud в Docker с Nginx, PostgreSQL и Let's Encrypt
# Запуск: sudo ./install-nextcloud-docker.sh your-domain.com

set -euo pipefail

echo "🚀 Установка Nextcloud в Docker..."

# Проверка прав
if [[ $EUID -ne 0 ]]; then
   echo "❌ Запустите с sudo."
   exit 1
fi

# Проверка аргумента — домен
if [ -z "${1:-}" ]; then
    echo "📌 Использование: $0 your-domain.com"
    exit 1
fi

DOMAIN=$1
EMAIL="admin@$DOMAIN"
DATA_DIR="/opt/nextcloud-docker"
mkdir -p "$DATA_DIR"
cd "$DATA_DIR"

# Установка Docker и docker-compose
if ! command -v docker &> /dev/null; then
    echo "📦 Установка Docker..."
    curl -fsSL https://get.docker.com | sh
    usermod -aG docker $SUDO_USER || true
fi

if ! command -v docker-compose &> /dev/null; then
    echo "📦 Установка Docker Compose..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p "$DOCKER_CONFIG/cli-plugins"
    curl -fsSL https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
    chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
fi

# Создание структуры папок
mkdir -p config data db letsencrypt nginx/conf.d

# Генерация docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3'

services:
  nextcloud:
    image: nextcloud:latest
    restart: unless-stopped
    depends_on:
      - db
    volumes:
      - ./data:/var/www/html
      - ./config:/var/www/html/config
    environment:
      - POSTGRES_HOST=db
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=ncuser
      - POSTGRES_PASSWORD=ncpass123
      - NEXTCLOUD_ADMIN_USER=admin
      # Пароль админа будет запрошен при первом входе
    networks:
      - nextcloud-network

  db:
    image: postgres:15
    restart: unless-stopped
    volumes:
      - ./db:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=nextcloud
      - POSTGRES_USER=ncuser
      - POSTGRES_PASSWORD=ncpass123
    networks:
      - nextcloud-network

  nginx:
    image: nginx:alpine
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d
      - ./letsencrypt:/etc/letsencrypt
      - /var/www/html:/var/www/html
    networks:
      - nextcloud-network
    depends_on:
      - nextcloud

  certbot:
    image: certbot/certbot
    restart: unless-stopped
    volumes:
      - ./letsencrypt:/etc/letsencrypt
      - /var/www/html:/var/www/html
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"

networks:
  nextcloud-network:
    driver: bridge
EOF

# Настройка Nginx (временный HTTP-сайт для проверки)
cat > nginx/conf.d/nextcloud.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/html;
    location /.well-known/acme-challenge/ {
        allow all;
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

# Создание временной папки для certbot
mkdir -p /var/www/html

# Перезапуск Docker
systemctl restart docker || true

# Запуск контейнеров
echo "🔄 Запуск контейнеров..."
docker-compose up -d

# Ожидание запуска Nginx
sleep 10

# Получение SSL-сертификата
echo "🔐 Получение SSL-сертификата Let's Encrypt..."
docker exec -t nginx nginx -s reload
docker run --rm \
  -v "$DATA_DIR/letsencrypt:/etc/letsencrypt" \
  -v "/var/www/html:/var/www/html" \
  -p 80:80 \
  certbot/certbot \
  certonly --standalone --non-interactive --agree-tos -m "$EMAIL" -d "$DOMAIN"

# Обновление конфигурации Nginx на HTTPS
cat > nginx/conf.d/nextcloud.conf <<EOF
server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/$DOMAIN/chain.pem;

    client_max_body_size 10G;
    fastcgi_buffers 64 4K;

    gzip on;
    gzip_vary on;
    gzip_mime_types text/plain text/css text/xml text/javascript application/javascript application/xml+rss application/atom+xml;

    root /var/www/html;

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location / {
        proxy_pass http://nextcloud:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$server_name;
    }
}

server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF

# Перезагрузка Nginx
docker-compose restart nginx

# Автообновление сертификатов (cron)
if ! crontab -l | grep -q "certbot renew"; then
    (crontab -l ; echo "0 12 * * * docker run --rm -v $DATA_DIR/letsencrypt:/etc/letsencrypt -v /var/www/html:/var/www/html certbot/certbot renew --quiet") | crontab -
fi

# Финал
echo "🎉 Nextcloud успешно установлен в Docker!"
echo ""
echo "🌐 Откройте в браузере: https://$DOMAIN"
echo ""
echo "📝 При первом входе:"
echo "   - Создайте учётную запись администратора"
echo "   - Хранилище и база уже настроены автоматически"
echo ""
echo "💡 Советы:"
echo "   - Резервные копии: архивируйте папку $DATA_DIR"
echo "   - Обновление: cd $DATA_DIR && docker-compose pull && docker-compose up -d"
echo "   - Логи: docker-compose logs -f"