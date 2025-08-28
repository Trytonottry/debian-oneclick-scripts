#!/bin/bash
set -eu
source config.sh "$@"

exec > >(tee -a "$LOG_FILE")
exec 2>&1

log "🚀 Запуск установки Nextcloud: $DOMAIN"

./01-clean.sh "$DOMAIN"
./02-install.sh "$DOMAIN"
./03-backup.sh "$DOMAIN"
./04-notify.sh "$DOMAIN"

log "🎉 Установка завершена: https://$DOMAIN"