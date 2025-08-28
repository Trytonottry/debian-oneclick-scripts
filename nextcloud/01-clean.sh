#!/bin/bash
source config.sh
source lib/functions.sh

log "🧹 Проверка и очистка старых данных..."

read -p "Удалить старые данные? [y/N] " -n 1 -r; echo
[[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

systemctl stop nginx php*-fpm 2>/dev/null || true
rm -rf "$NEXTCLOUD_DIR"
sudo -u postgres psql -c "DROP OWNED BY nextclouduser;" 2>/dev/null || true
sudo -u postgres psql -c "DROP USER IF EXISTS nextclouduser;"
sudo -u postgres psql -c "DROP DATABASE IF EXISTS nextcloud;"
rm -f /etc/nginx/sites-enabled/nextcloud
certbot delete --cert-name "$DOMAIN" --non-interactive 2>/dev/null || true

log "✅ Очистка завершена"