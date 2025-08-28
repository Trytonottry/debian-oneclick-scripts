#!/bin/bash
# 03-backup.sh — настройка ежедневного резервного копирования

source config.sh
source lib/functions.sh

log "💾 Настройка резервного копирования..."

# Папка для бэкапов
mkdir -p "$BACKUP_DIR"

# Скрипт бэкапа
cat > /usr/local/bin/nextcloud-backup.sh << 'EOF'
#!/bin/bash
set -eu

# === НАСТРОЙКИ (можно вынести в config) ===
BACKUP_DIR="/opt/nextcloud-backup"
NEXTCLOUD_DIR="/var/www/nextcloud"
DB_NAME="nextcloud"
DATE=$(date '+%Y-%m-%d_%H-%M')

# === СОЗДАНИЕ БЭКАПА ===
mkdir -p "$BACKUP_DIR"

# 1. Дамп базы данных
sudo -u postgres pg_dump "$DB_NAME" > "$BACKUP_DIR/db-$DATE.sql"

# 2. Архив файлов Nextcloud
tar -czf "$BACKUP_DIR/files-$DATE.tar.gz" \
    -C "$(dirname "$NEXTCLOUD_DIR")" \
    "$(basename "$NEXTCLOUD_DIR")"

# 3. Лог
echo "✅ Бэкап создан: $BACKUP_DIR/{db,files}-$DATE.*"

# === ОЧИСТКА СТАРЫХ (старше 7 дней) ===
find "$BACKUP_DIR" -name 'db-*.sql' -mtime +7 -delete
find "$BACKUP_DIR" -name 'files-*.tar.gz' -mtime +7 -delete
EOF

# Сделать исполняемым
chmod +x /usr/local/bin/nextcloud-backup.sh

# Добавить в cron (если ещё нет)
if ! crontab -l | grep -q "nextcloud-backup"; then
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/nextcloud-backup.sh >> /var/log/nextcloud-backup.log 2>&1") | crontab -
    log "✅ Cron: ежедневный бэкап в 02:00"
else
    log "🔁 Cron уже настроен"
fi

# Создать лог-файл
touch /var/log/nextcloud-backup.log
chown www-data:www-data /var/log/nextcloud-backup.log 2>/dev/null || true

log "✅ Резервное копирование настроено: $BACKUP_DIR (хранение 7 дней)"