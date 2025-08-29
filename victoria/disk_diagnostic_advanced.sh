#!/bin/bash
# Название: disk_diagnostic_advanced.sh
# Описание: Полноценный аналог Victoria с GUI, автовыбором дисков, ddrescue и photorec
# Поддержка: Debian/Ubuntu

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Проверка, запущено ли от root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Этот скрипт должен быть запущен с правами root (sudo)${NC}"
    exit 1
fi

# Функция: показ уведомлений через whiptail
show_msg() {
    whiptail --title "$1" --msgbox "$2" 12 60
}

# Функция: диалог выбора
choose_option() {
    whiptail --title "$1" --menu "$2" 15 60 4 "${@:3}"
}

echo -e "${BLUE}=== Автоматическая диагностика дисков (аналог Victoria) ===${NC}"
show_msg "Запуск" "Скрипт начнёт проверку и при необходимости установит пакеты."

# Пакеты
PACKAGES=("smartmontools" "gddrescue" "testdisk" "ntfs-3g" "whiptail")
MISSING=()

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        MISSING+=("$pkg")
    fi
done

if [ ${#MISSING[@]} -gt 0 ]; then
    echo -e "${YELLOW}Устанавливаются пакеты: ${MISSING[*]}${NC}"
    apt update
    apt install -y "${MISSING[@]}"
    show_msg "Установка" "Необходимые пакеты установлены."
fi

# Список дисков (исключаем ram, loop)
DISK_LIST=()
while IFS= read -r line; do
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    model=$(echo "$line" | cut -d' ' -f3-)
    [ -z "$model" ] && model="Unknown"
    DISK_LIST+=("$name" "$size $model")
done < <(lsblk -d -n -o NAME,SIZE,MODEL | grep -E "^sd|^hd|^nvme" | grep -v "sr")

if [ ${#DISK_LIST[@]} -eq 0 ]; then
    show_msg "Ошибка" "Не найдено ни одного диска."
    exit 1
fi

CHOSEN_DISK=$(choose_option "Выбор диска" "Выберите диск для диагностики:" "${DISK_LIST[@]}" 3>&1 1>&2 2>&3)
if [ -z "$CHOSEN_DISK" ]; then
    show_msg "Отмена" "Диагностика отменена."
    exit 0
fi

DEVICE="/dev/$CHOSEN_DISK"
echo "Выбран диск: $DEVICE"

# SMART анализ
TEMP_FILE=$(mktemp)
smartctl -a "$DEVICE" > "$TEMP_FILE" 2>&1 || {
    show_msg "Ошибка" "Не удалось прочитать S.M.A.R.T. информацию."
    exit 1
}

# Проверка здоровья
HEALTH=$(grep "SMART overall-health" "$TEMP_FILE" | awk '{print $6}')
REALLOC=$(grep "Reallocated_Sector_Ct" "$TEMP_FILE" | awk '{print $4}')
REALLOC_COUNT=$(grep "Reallocated_Event_Count" "$TEMP_FILE" | awk '{print $4}')
PENDING=$(grep "Current_Pending_Sector" "$TEMP_FILE" | awk '{print $4}')

# Запуск короткого теста
echo "Запуск короткого теста..."
smartctl -t short "$DEVICE" > /dev/null
sleep 120
SHORT_RESULT=$(smartctl -l selftest "$DEVICE" | grep "# 1" | awk '{print $5}')

# Оценка риска
DANGER=0
REASON=""

if [ "$HEALTH" != "PASSED" ]; then
    REASON+="Диск не прошёл S.M.A.R.T. здоровье.\n"
    DANGER=1
fi

if [ -n "$REALLOC" ] && [ "$REALLOC" -gt 0 ]; then
    REASON+="Переназначенные сектора: $REALLOC.\n"
    DANGER=1
fi

if [ -n "$PENDING" ] && [ "$PENDING" -gt 0 ]; then
    REASON+="Ожидающие переназначения сектора: $PENDING.\n"
    DANGER=1
fi

if [ "$SHORT_RESULT" != "Completed" ]; then
    REASON+="Короткий тест не завершился: $SHORT_RESULT.\n"
    DANGER=1
fi

if [ $DANGER -eq 1 ]; then
    MSG="⚠️ Обнаружены признаки неисправности:\n\n$REASON\nРекомендуется срочно скопировать данные."
    if whiptail --title "Предупреждение" --yesno "$MSG\n\nНачать клонирование с помощью ddrescue?" 12 60; then
        # Поиск внешних дисков для сохранения образа
        DEST_LIST=()
        while IFS= read -r dev; do
            # Пропускаем системный корень и сам диагностируемый диск
            if mount | grep "$dev" | grep -q " / "; then
                continue
            fi
            if [[ "$dev" == *"$CHOSEN_DISK"* ]]; then
                continue
            fi
            size=$(lsblk -n -o SIZE "$dev" 2>/dev/null || echo "Unknown")
            DEST_LIST+=("$dev" "Внешний диск ($size)")
        done < <(lsblk -l -o NAME | grep -E "^sd|^nvme" | grep -v "$CHOSEN_DISK" | sed 's/^/\/dev\//')

        # Добавим опцию "свой путь"
        DEST_LIST+=("manual" "Указать вручную")

        if [ ${#DEST_LIST[@]} -eq 0 ]; then
            show_msg "Ошибка" "Не найдено подходящих внешних дисков для сохранения образа."
            exit 1
        fi

        TARGET=$(choose_option "Куда сохранить?" "Выберите место для образа:" "${DEST_LIST[@]}" 3>&1 1>&2 2>&3)
        if [ "$TARGET" == "manual" ]; then
            IMAGE_PATH=$(whiptail --inputbox "Введите полный путь к файлу образа (например, /mnt/backup/disk.img)" 10 60 --title "Путь к образу" 3>&1 1>&2 2>&3)
        else
            IMAGE_PATH="$TARGET/$(date +%Y%m%d)_${CHOSEN_DISK}_rescue.img"
        fi

        LOG_PATH="${IMAGE_PATH}.log"

        if whiptail --title "Подтверждение" --yesno "Создать образ диска:\n\nИсточник: $DEVICE\nЦель: $IMAGE_PATH\n\nЭто может занять несколько часов. Продолжить?" 13 60; then
            echo "Запуск ddrescue: копирование с 3 повторами..."
            ddrescue -r 3 -v "$DEVICE" "$IMAGE_PATH" "$LOG_PATH"
            show_msg "Готово" "Копирование завершено. Лог: $LOG_PATH"

            # Предложить восстановить файлы
            if whiptail --title "Восстановление" --yesno "Запустить photorec для восстановления файлов из образа?" 10 60; then
                photorec "$IMAGE_PATH"
            fi

            # Предложить смонтировать образ (если NTFS)
            if file -s "$IMAGE_PATH" | grep -q "NTFS"; then
                if whiptail --title "Монтирование" --yesno "Образ содержит NTFS. Хотите смонтировать его?" 10 60; then
                    MOUNT_POINT="/mnt/rescue_mount"
                    mkdir -p "$MOUNT_POINT"
                    mount -o loop,ro "$IMAGE_PATH" "$MOUNT_POINT"
                    show_msg "Смонтировано" "Образ смонтирован в: $MOUNT_POINT\nДля отключения: umount $MOUNT_POINT"
                fi
            fi
        fi
    fi
else
    show_msg "Здоровый диск" "Диск $DEVICE выглядит нормально.\nРекомендуется периодически проверять S.M.A.R.T."
fi

# Чистка
rm -f "$TEMP_FILE"

echo -e "${GREEN}✅ Диагностика завершена.${NC}"