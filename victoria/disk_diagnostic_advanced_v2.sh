#!/bin/bash
# Название: disk_diagnostic_advanced_v2.sh
# Описание: Диагностика + восстановление данных с диска на указанный внешний носитель
# Функции: SMART, ddrescue, photorec, выбор источника и цели, GUI (whiptail)

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Проверка root
if [ "$EUID" -ne 0 ]; then
    whiptail --title "Ошибка" --msgbox "Этот скрипт требует прав root." 8 50
    exec sudo "$0" "$@"
fi

# Функции GUI
show_msg() {
    whiptail --title "$1" --msgbox "$2" 12 60
}

ask_yes_no() {
    whiptail --title "$1" --yesno "$2" 12 60
}

choose_disk() {
    local title="$1"
    shift
    whiptail --title "$title" --menu "Выберите диск:" 15 60 6 "$@" 3>&1 1>&2 2>&3
}

input_text() {
    whiptail --inputbox "$2" 10 60 "$3" --title "$1" 3>&1 1>&2 2>&3
}

# Установка пакетов
PACKAGES=("smartmontools" "gddrescue" "testdisk" "ntfs-3g" "whiptail")
MISSING=()

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    apt update -qq
    apt install -y "${MISSING[@]}" >/dev/null 2>&1
    show_msg "Установка" "Установлены: ${MISSING[*]}"
fi

# === ШАГ 1: Выбор диска-источника ===
DISK_LIST=()
while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    model=$(echo "$line" | cut -d' ' -f3-)
    [ -z "$model" ] && model="Unknown"
    DISK_LIST+=("$name" "$size $model")
done < <(lsblk -d -n -o NAME,SIZE,MODEL | grep -E "sd|hd|nvme" | grep -v "sr")

if [ ${#DISK_LIST[@]} -eq 0 ]; then
    show_msg "Ошибка" "Не найдено ни одного диска."
    exit 1
fi

SRC_DISK=$(choose_disk "Источник" "Выберите диск для диагностики и восстановления:" "${DISK_LIST[@]}")
if [ -z "$SRC_DISK" ]; then exit 1; fi

SRC_DEV="/dev/$SRC_DISK"
ROOT_DISK=$(mount | grep " / " | awk '{print $1}' | sed 's/[0-9]//g' | sed 's/p[0-9]//g' | head -n1)

# === ШАГ 2: Диагностика диска ===
TEMP_FILE=$(mktemp)
smartctl -a "$SRC_DEV" > "$TEMP_FILE" 2>&1 || {
    show_msg "Ошибка" "Не удалось прочитать SMART."
    exit 1
}

HEALTH=$(grep "SMART overall-health" "$TEMP_FILE" | awk '{print $6}')
REALLOC=$(grep "Reallocated_Sector_Ct" "$TEMP_FILE" | awk '{print $4}')
PENDING=$(grep "Current_Pending_Sector" "$TEMP_FILE" | awk '{print $4:-0}')

DANGER=0
REASON=""

if [ "$HEALTH" != "PASSED" ]; then
    REASON+="❌ Диск не прошёл проверку здоровья.\n"
    DANGER=1
fi

if [ -n "$REALLOC" ] && [ "$REALLOC" -gt 0 ]; then
    REASON+="⚠️ Переназначенные сектора: $REALLOC\n"
    DANGER=1
fi

if [ -n "$PENDING" ] && [ "$PENDING" -gt 0 ]; then
    REASON+="⚠️ Ожидающие сектора: $PENDING\n"
    DANGER=1
fi

if [ $DANGER -eq 1 ]; then
    if ! ask_yes_no "Повреждённый диск" "$REASON\n\nНачать восстановление?"; then
        exit 0
    fi
else
    if ! ask_yes_no "Здоровый диск" "Диск выглядит нормально. Всё равно начать восстановление данных?"; then
        exit 0
    fi
fi

# === ШАГ 3: Выбор целевого диска (флешка/диск) ===
DEST_LIST=()
while IFS= read -r dev; do
    if [[ "$dev" == *"$SRC_DISK"* ]]; then continue; fi
    if mount | grep "$dev" | grep -q " / "; then continue; fi
    size=$(lsblk -n -o SIZE "/dev/$dev" 2>/dev/null || echo "N/A")
    DEST_LIST+=("$dev" "Диск /dev/$dev ($size)")
done < <(lsblk -l -o NAME | grep -E "^sd|^nvme" | sed 's/^/\/dev\//' | sed 's/\/dev\///')

if [ ${#DEST_LIST[@]} -eq 0 ]; then
    show_msg "Ошибка" "Не найдено ни одного подходящего целевого диска (флешка/внешний HDD)."
    exit 1
fi

DEST_DISK=$(choose_disk "Назначение" "Выберите флешку или диск для сохранения данных:" "${DEST_LIST[@]}")
if [ -z "$DEST_DISK" ]; then exit 1; fi

DEST_DEV="/dev/$DEST_DISK"

# Проверка, не является ли целевой диск системным
if echo "$DEST_DEV" | grep -q "$ROOT_DISK"; then
    show_msg "Ошибка" "❌ Нельзя использовать системный диск как цель!"
    exit 1
fi

# Находим точку монтирования
DEST_MOUNT=$(mount | grep "$DEST_DEV" | awk '{print $3}' | head -n1)
if [ -z "$DEST_MOUNT" ]; then
    DEST_MOUNT="/mnt/$(basename "$DEST_DEV")"
    mkdir -p "$DEST_MOUNT"
    mount "$DEST_DEV" "$DEST_MOUNT" || {
        show_msg "Ошибка" "Не удалось смонтировать $DEST_DEV"
        exit 1
    }
    MOUNTED_TEMP=1
else
    MOUNTED_TEMP=0
fi

# === ШАГ 4: Выбор режима восстановления ===
ACTION=$(choose_disk "Режим" "Что делать?" \
    "image" "Создать образ диска (ddrescue)" \
    "files" "Найти и скопировать файлы (photorec)")

if [ "$ACTION" = "image" ]; then
    IMAGE_PATH="$DEST_MOUNT/$(date +%Y%m%d)_${SRC_DISK}_rescue.img"
    LOG_PATH="$IMAGE_PATH.log"
    if ask_yes_no "Копирование образа" "Создать образ $SRC_DEV → $IMAGE_PATH?"; then
        ddrescue -r 3 -v "$SRC_DEV" "$IMAGE_PATH" "$LOG_PATH"
        show_msg "Готово" "Образ создан: $IMAGE_PATH"
    fi
elif [ "$ACTION" = "files" ]; then
    OUTPUT_DIR="$DEST_MOUNT/recovered_files_$(date +%H%M)"
    mkdir -p "$OUTPUT_DIR"
    show_msg "Photorec" "Запустите выбор: $SRC_DEV → $OUTPUT_DIR\nНажмите OK."
    photorec
    # Вручную: выбрать диск, потом partition type (usually [None]), потом [File Opt], потом [Search], потом путь $OUTPUT_DIR
    show_msg "Готово" "Файлы восстановлены в:\n$OUTPUT_DIR"
fi

# === Финал ===
if [ "${MOUNTED_TEMP:-0}" -eq 1 ]; then
    umount "$DEST_MOUNT"
    rmdir "$DEST_MOUNT"
    show_msg "Очистка" "Целевой диск отключён."
fi

show_msg "Завершено" "✅ Восстановление данных завершено.\nЦелевой диск: $DEST_DEV\nДанные: $DEST_MOUNT"