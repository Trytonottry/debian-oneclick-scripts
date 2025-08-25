#!/bin/bash

# Полный one-click скрипт: Nextcloud с Nginx, PostgreSQL, Let's Encrypt
# Поддержка автоматического HTTPS
# Запуск: sudo ./install-nextcloud.sh your-domain.com

set -euo pipefail

echo "🚀 Установка Nextcloud с Nginx, PostgreSQL и HTTPS..."

# Проверка прав
if [[ $EUID -ne 0 ]]; then
   echo "❌ Запустите скрипт с sudo."
   exit 1
fi

# Проверка аргумента — домен
if [ -z "${1:-}" ]; then
    echo "📌 Использование: $0 your-domain.com"
    exit 1
fi

DOMAIN=$1
ADMIN_EMAIL="admin@$DOMAIN"  # Можно изменить
NEXTCLOUD_DIR="/var/www/nextcloud"

# Обновление системы
echo "🔄 Обновление системы..."
apt update && apt upgrade -y

# Установка необходимых пакетов
echo "📦 Установка Nginx, PostgreSQL, PHP и зависимостей..."
apt install -y nginx postgresql postgresql-contrib php-fpm php-gd php-mysql \
    php-curl php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick \
    php-zip php-pgsql wget unzip certbot python3-certbot-nginx

# Генерация пароля для БД
DB_PASS=$(openssl rand -base64 12)

# Создание пользователя и базы в PostgreSQL
echo "🗄️ Настройка PostgreSQL..."
sudo -u postgres psql -c "CREATE USER nextclouduser WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "CREATE DATABASE nextcloud OWNER nextclouduser TEMPLATE template0 ENCODING 'UTF8';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextclouduser;"

# Скачивание и установка Nextcloud
echo "⬇️ Скачивание Nextcloud..."
cd /tmp
wget -q https://download.nextcloud.com/server/releases/latest.zip -O nextcloud.zip
unzip -q nextcloud.zip
rm -rf $NEXTCLOUD_DIR
mv nextcloud $NEXTCLOUD_DIR

# Права доступа
chown -R www-www-data $NEXTCLOUD_DIR
chmod -R 755 $NEXTCLOUD_DIR

# Настройка Nginx
echo "🔧 Настройка Nginx..."
cat > /etc/nginx/sites-available/nextcloud <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        default_type "text/plain";
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF

ln -sf /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Перезагрузка Nginx
systemctl reload nginx

# Получение SSL-сертификата от Let's Encrypt
echo "🔐 Получение SSL-сертификата через Let's Encrypt..."
mkdir -p /var/www/html
# Временный файл для проверки
echo "ok" > /var/www/html/letsencrypt-test.txt

# Получаем сертификат
if certbot --nginx -m "$ADMIN_EMAIL" --agree-tos -n --redirect -d "$DOMAIN"; then
    echo "✅ HTTPS настроен успешно!"
else
    echo "❌ Ошибка при получении сертификата. Проверьте DNS и порт 80."
    exit 1
fi

# Удаляем временный файл
rm -f /var/www/html/letsencrypt-test.txt

# Автообновление сертификатов
if ! grep -q "certbot.*renew" /etc/crontab; then
    echo "0 12 * * * root certbot renew --quiet" >> /etc/crontab
fi

# Финал
echo "🎉 Установка завершена!"
echo ""
echo "🌐 Перейдите по адресу: https://$DOMAIN"
echo ""
echo "📝 При первой настройке в веб-интерфейсе:"
echo "   - Администратор: (выберите имя и пароль)"
echo "   - Хранилище и база данных:"
echo "     - Тип: PostgreSQL"
echo "     - Логин: nextclouduser"
echo "     - Пароль: $DB_PASS"
echo "     - Имя базы: nextcloud"
echo "     - Хост: localhost"
echo ""
echo "💡 Рекомендации:"
echo "   - Включите фоновые задачи: Настройки → Основные → 'Фоновые задачи' → Cron"
echo "   - Добавьте в crontab: */5 * * * * www-data php /var/www/nextcloud/cron.php"
echo "   - Регулярно обновляйте систему и Nextcloud."

# Открытие портов (если включен ufw)
if ufw status | grep -q "Status: active"; then
    ufw allow 80,443/tcp > /dev/null 2>&1 || true
    echo "🔓 Порты 80 и 443 открыты в ufw."
fi