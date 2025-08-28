#!/bin/bash
# config.sh — глобальные переменные

DOMAIN="${1:?Укажите домен: ./main.sh example.com}"
ADMIN_EMAIL="admin@$DOMAIN"

NEXTCLOUD_DIR="/var/www/nextcloud"
BACKUP_DIR="/opt/nextcloud-backup"

DB_USER="nextclouduser"
DB_NAME="nextcloud"
DB_PASS=$(openssl rand -base64 12)

ADMIN_USER="admin"
ADMIN_PASS=$(openssl rand -base64 12)

LOG_FILE="/var/log/nextcloud-install-$(date +%F).log"