#!/bin/bash
set -euo pipefail

echo "🚀 Установка Matrix Synapse сервера..."

# Проверка на root
if [[ $EUID -ne 0 ]]; then
   echo "❌ Этот скрипт должен запускаться от root или через sudo"
   exit 1
fi

# Запрос домена
read -p "Введите домен (например, matrix.example.com): " DOMAIN
read -p "Введите email администратора: " ADMIN_EMAIL

# Обновление системы
apt update && apt upgrade -y

# Установка зависимостей
apt install -y curl wget gnupg lsb-release postgresql postgresql-contrib nginx certbot python3-certbot-nginx

# Добавление репозитория Matrix
curl -fsSL https://repo.matrix.org/gpg.key | gpg --dearmor > /etc/apt/trusted.gpg.d/matrix-org.gpg
echo "deb https://repo.matrix.org/debian/ $(lsb_release -cs) main" > /etc/apt/sources.list.d/matrix-org.list
apt update

# Установка Synapse
apt install -y matrix-synapse-py3

# Остановка Synapse для настройки
systemctl stop matrix-synapse

# Настройка PostgreSQL
sudo -u postgres psql -c "CREATE USER synapse WITH PASSWORD 'synapse';"
sudo -u postgres psql -c "CREATE DATABASE synapse OWNER synapse;"

# Резервная копия конфига
cp /etc/matrix-synapse/homeserver.yaml /etc/matrix-synapse/homeserver.yaml.bak

# Генерация нового homeserver.yaml
cat > /etc/matrix-synapse/homeserver.yaml <<EOF
server_name: "$DOMAIN"
public_baseurl: "https://$DOMAIN/"

# База данных
database:
  name: psycopg2
  args:
    user: synapse
    password: synapse
    database: synapse
    host: localhost
    port: 5432
    cp_min: 5
    cp_max: 10

listeners:
  - port: 8008
    tls: false
    type: http
    x_forwarded: true
    bind_address: '127.0.0.1'
    resources:
      - names: [client, federation]
        compress: false

  - port: 8448
    tls: true
    type: http
    bind_address: ''
    x_forwarded: true
    resources:
      - names: [federation]
        compress: false

federation_domain_whitelist: []

enable_registration: false
enable_registration_without_verification: false
registration_shared_secret: $(openssl rand -hex 32)

# Email для уведомлений
email:
  enable_notifs: false
  smtp_host: localhost
  smtp_port: 25
  notif_from: "Matrix <$DOMAIN>"
  app_name: Matrix

# Требовать подтверждение email
request_token_inhibit_3pid_errors: true

# Логирование
log_config: /etc/matrix-synapse/log.yaml
EOF

# Генерация shared secret для регистрации
SECRET=$(openssl rand -hex 32)
sed -i "s|registration_shared_secret: .*|registration_shared_secret: $SECRET|" /etc/matrix-synapse/homeserver.yaml

# Настройка Nginx
cat > /etc/nginx/sites-available/matrix <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/matrix/server {
        default_type application/json;
        return 200 '{"m.server": "$DOMAIN:443"}';
    }
    location /.well-known/matrix/client {
        default_type application/json;
        return 200 '{"im.vector.riot.jitsi": {"preferredDomain": "meet.jit.si"}}';
    }
    location / {
        return 301 https://\$host\$request_uri;
    }
}
EOF

ln -sf /etc/nginx/sites-available/matrix /etc/nginx/sites-enabled/matrix
rm -f /etc/nginx/sites-enabled/default

# Перезагрузка Nginx
systemctl reload nginx

# Получение SSL-сертификата
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $ADMIN_EMAIL --redirect

# Перезапуск Nginx
systemctl reload nginx

# Запуск Synapse
systemctl enable matrix-synapse
systemctl start matrix-synapse

# Ожидание запуска
sleep 5

# Создание администратора
echo "🔐 Создаём первого администратора..."
register-json -k "$SECRET" << EOF
{
  "username": "admin",
  "displayname": "Admin",
  "password": "$(openssl rand -hex 16)",
  "admin": true
}
EOF

echo "✅ Matrix сервер установлен!"
echo "🌐 Доступ: https://$DOMAIN"
echo "📌 Редактируйте /etc/matrix-synapse/homeserver.yaml для дополнительных настроек."
echo "ℹ️  Чтобы включить регистрацию: enable_registration: true"