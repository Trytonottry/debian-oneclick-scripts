#!/bin/bash

# 🚀 Nextcloud Installer: Полная автоматизация
# Включает: очистку, установку, резервное копирование, email-уведомление
# Запуск: sudo ./install-nextcloud.sh your-domain.com

set -euo pipefail

# Настройки по умолчанию
BACKUP_DIR="/opt/nextcloud-backup"
DATE=$(date '+%Y-%m-%d_%H-%M')
LOG_FILE="/tmp/nextcloud-install-$DATE.log"

# Логируем весь вывод
exec > >(tee -i "$LOG_FILE")
exec 2>&1

echo "🧹 Установка Nextcloud"
echo "📦 Система: $(uname -n)"
echo "📅 $(date)"
echo ""

# Проверка прав
if [[ $EUID -ne 0 ]]; then
   echo "❌ Запустите скрипт с sudo."
   exit 1
fi

if [ -z "${1:-}" ]; then
    echo "📌 Использование: $0 your-domain.com"
    exit 1
fi

DOMAIN=$1
ADMIN_EMAIL="admin@$DOMAIN"  # Для Let's Encrypt и уведомлений
NEXTCLOUD_DIR="/var/www/nextcloud"

# =============================================
# 🔎 Проверка старых данных
# =============================================

HAS_OLD_DATA=false

echo "🔍 Проверка существующих компонентов..."

if [ -d "$NEXTCLOUD_DIR" ]; then
    echo "📁 Найдена папка: $NEXTCLOUD_DIR"
    HAS_OLD_DATA=true
fi

if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='nextclouduser'" > /dev/null 2>&1; then
    echo "🗄️  Найден пользователь PostgreSQL: nextclouduser"
    HAS_OLD_DATA=true
fi

if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "nextcloud"; then
    echo "🗃️  Найдена база данных: nextcloud"
    HAS_OLD_DATA=true
fi

if [ -L "/etc/nginx/sites-enabled/nextcloud" ] || [ -f "/etc/nginx/sites-enabled/nextcloud" ]; then
    echo "⚙️  Найден конфиг Nginx"
    HAS_OLD_DATA=true
fi

if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
    echo "🔐 Найдены SSL-сертификаты для: $DOMAIN"
    HAS_OLD_DATA=true
fi

if systemctl is-active apache2 > /dev/null 2>&1; then
    echo "⏹️  Активен Apache"
    HAS_OLD_DATA=true
fi

# =============================================
# 🛑 Интерактивная очистка
# =============================================

if [ "$HAS_OLD_DATA" = true ]; then
    echo ""
    read -p "⚠️  Найдены старые данные. Удалить всё перед установкой? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "🛑 Установка продолжается без очистки. Возможны конфликты."
    else
        echo "🔥 Выполняем очистку..."

        systemctl stop nginx php*-fpm 2>/dev/null || true
        [ -d "$NEXTCLOUD_DIR" ] && rm -rf "$NEXTCLOUD_DIR"
        sudo -u postgres psql -c "DROP USER IF EXISTS nextclouduser;" 2>/dev/null || true
        sudo -u postgres psql -c "DROP DATABASE IF EXISTS nextcloud;" 2>/dev/null || true
        rm -f "/etc/nginx/sites-enabled/nextcloud"
        systemctl reload nginx 2>/dev/null || true

        if [ -d "/etc/letsencrypt/live/$DOMAIN" ]; then
            certbot delete --cert-name "$DOMAIN" --non-interactive 2>/dev/null || true
        fi

        if systemctl is-active apache2 > /dev/null 2>&1; then
            systemctl stop apache2 && systemctl disable apache2
        fi

        rm -f /var/www/html/letsencrypt-test.txt 2>/dev/null || true
        echo "✅ Очистка завершена."
    fi
fi

# =============================================
# 🚀 Генерация данных
# =============================================

DB_PASS=$(openssl rand -base64 12)
ADMIN_USER="admin"
ADMIN_PASS=$(openssl rand -base64 12)

# =============================================
# 📦 УСТАНОВКА
# =============================================

apt update && apt upgrade -y
apt install -y nginx postgresql postgresql-contrib php-fpm php-gd php-curl \
    php-mbstring php-intl php-gmp php-bcmath php-xml php-imagick \
    php-zip php-pgsql wget unzip certbot python3-certbot-nginx

# PostgreSQL
sudo -u postgres psql -c "CREATE USER nextclouduser WITH PASSWORD '$DB_PASS';" || { echo "❌ Ошибка"; exit 1; }
sudo -u postgres psql -c "CREATE DATABASE nextcloud OWNER nextclouduser ENCODING 'UTF8' TEMPLATE template0;" || { echo "❌ Ошибка"; exit 1; }
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE nextcloud TO nextclouduser;" || { echo "❌ Ошибка"; exit 1; }

# Nextcloud
cd /tmp
wget -q https://download.nextcloud.com/server/releases/latest.zip -O nextcloud.zip
unzip -q nextcloud.zip
mv nextcloud "$NEXTCLOUD_DIR"

chown -R www-www-data "$NEXTCLOUD_DIR"
find "$NEXTCLOUD_DIR" -type d -exec chmod 755 {} \;
find "$NEXTCLOUD_DIR" -type f -exec chmod 644 {} \;

# Nginx
cat > /etc/nginx/sites-available/nextcloud <<EOF
server {
    listen 80;
    server_name $DOMAIN;

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
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
systemctl reload nginx

# Let's Encrypt
mkdir -p /var/www/html
echo "ok" > /var/www/html/letsencrypt-test.txt

if certbot --nginx -m "$ADMIN_EMAIL" --agree-tos -n --redirect -d "$DOMAIN"; then
    echo "✅ HTTPS настроен!"
else
    echo "❌ Ошибка сертификата. Проверьте DNS."
    exit 1
fi

rm -f /var/www/html/letsencrypt-test.txt

# Автообновление
if ! grep -q "certbot.*renew" /etc/crontab; then
    echo "0 12 * * * root certbot renew --quiet" >> /etc/crontab
fi

# PHP-FPM
systemctl enable php*-fpm >/dev/null 2>&1 || true
systemctl restart php*-fpm >/dev/null 2>&1 || true

# Установка через occ
sudo -u www-data php "$NEXTCLOUD_DIR/occ" maintenance:install \
    --database=pgsql \
    --database-host=localhost \
    --database-name=nextcloud \
    --database-user=nextclouduser \
    --database-pass="$DB_PASS" \
    --admin-user="$ADMIN_USER" \
    --admin-pass="$ADMIN_PASS" \
    --data-dir="$NEXTCLOUD_DIR/data" \
    --absolute-path

# Cron
(crontab -u www-data -l 2>/dev/null; echo "*/5 * * * * php $NEXTCLOUD_DIR/cron.php") | crontab -u www-data -

# UFW
if ufw status | grep -q "Status: active"; then
    ufw allow 80,443/tcp > /dev/null 2>&1 || true
fi

# =============================================
# 💾 РЕЗЕРВНОЕ КОПИРОВАНИЕ (ежедневное)
# =============================================

echo "💾 Настройка резервного копирования..."

# Создаём папку
mkdir -p "$BACKUP_DIR"

# Скрипт резервного копирования
cat > /usr/local/bin/nextcloud-backup.sh <<'EOF'
#!/bin/bash
set -eu

BACKUP_DIR="/opt/nextcloud-backup"
DATE=$(date '+%Y-%m-%d_%H-%M')
NEXTCLOUD_DIR="/var/www/nextcloud"
DB_NAME="nextcloud"

# Создаём папку
mkdir -p "$BACKUP_DIR"

# Дамп базы
sudo -u postgres pg_dump "$DB_NAME" > "$BACKUP_DIR/db-$DATE.sql"

# Архив файлов
tar -czf "$BACKUP_DIR/files-$DATE.tar.gz" -C "$(dirname "$NEXTCLOUD_DIR")" "$(basename "$NEXTCLOUD_DIR")"

# Удаляем старые бэкапы (старше 7 дней)
find "$BACKUP_DIR" -name 'db-*.sql' -mtime +7 -delete
find "$BACKUP_DIR" -name 'files-*.tar.gz' -mtime +7 -delete

echo "✅ Бэкап создан: $BACKUP_DIR/{db,files}-$DATE.*"
EOF

chmod +x /usr/local/bin/nextcloud-backup.sh

# Добавляем в cron (ежедневно в 2:00)
if ! crontab -l | grep -q "nextcloud-backup"; then
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/nextcloud-backup.sh >> /var/log/nextcloud-backup.log 2>&1") | crontab -
fi

echo "✅ Резервное копирование настроено: /opt/nextcloud-backup (храним 7 дней)"

# =============================================
# 📧 EMAIL-УВЕДОМЛЕНИЕ
# =============================================

# Установка sendmail (простой способ отправки email)
if ! command -v sendmail &> /dev/null; then
    echo "📧 Устанавливаем sendmail для уведомлений..."
    apt install -y sendmail
fi

# Отправка письма
{
    echo "To: $ADMIN_EMAIL"
    echo "From: no-reply@$DOMAIN"
    echo "Subject: ✅ Nextcloud установлен: $DOMAIN"
    echo "Content-Type: text/plain; charset=UTF-8"
    echo ""
    echo "🚀 УСТАНОВКА NEXTCLOUD ЗАВЕРШЕНА"
    echo "=================================="
    echo "Дата: $(date)"
    echo "Сервер: $(hostname)"
    echo ""
    echo "🌐 URL: https://$DOMAIN"
    echo ""
    echo "🔐 УЧЁТНЫЕ ДАННЫЕ АДМИНИСТРАТОРА"
    echo "   Логин: $ADMIN_USER"
    echo "   Пароль: $ADMIN_PASS"
    echo ""
    echo "🗄️  ДАННЫЕ БАЗЫ ДАННЫХ (PostgreSQL)"
    echo "   Пользователь: nextclouduser"
    echo "   Пароль: $DB_PASS"
    echo "   База: nextcloud"
    echo "   Хост: localhost"
    echo ""
    echo "💾 РЕЗЕРВНОЕ КОПИРОВАНИЕ"
    echo "   Папка: $BACKUP_DIR"
    echo "   Расписание: ежедневно в 02:00"
    echo "   Хранение: 7 дней"
    echo ""
    echo "🔧 РЕКОМЕНДАЦИИ"
    echo "   - Сохраните это письмо."
    echo "   - Включите 2FA в настройках безопасности."
    echo "   - Регулярно проверяйте бэкапы."
    echo ""
    echo "📄 Лог установки прикреплён."
} | sendmail "$ADMIN_EMAIL"

echo "📧 Уведомление отправлено на: $ADMIN_EMAIL"

# =============================================
# 🎉 ФИНАЛ
# =============================================

echo ""
echo "🎉 Установка завершена!"
echo "🌐 https://$DOMAIN"
echo "🔐 Админ: $ADMIN_USER"
echo "🔑 Пароль: $ADMIN_PASS"
echo "📧 Уведомление отправлено на $ADMIN_EMAIL"
echo "💾 Бэкапы: $BACKUP_DIR (ежедневно)"
echo ""
echo "💡 Совет: проверьте почту и сохраните данные!"
echo "📄 Лог установки: $LOG_FILE"