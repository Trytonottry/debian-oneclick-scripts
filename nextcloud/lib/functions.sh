#!/bin/bash
# lib/functions.sh

log() { echo "[$(date +'%H:%M:%S')] $1"; }
error() { log "❌ Ошибка: $1"; exit 1; }
run() { "$@" 2>&1 | sed 's/^/   | /'; }

# Проверка команды
require_cmd() {
    command -v "$1" > /dev/null || error "Не хватает: $1"
}