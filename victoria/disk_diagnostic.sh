#!/bin/bash
# Название: disk_diagnostic.sh
# Описание: Автоматическая диагностика дисков (аналог Victoria) на Debian/Ubuntu
# Функции: установка пакетов, SMART, тесты, ddrescue, рекомендации

set -e  # Выход при ошибке

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Автоматическая диагностика дисков (аналог Victoria) ===${NC}"
echo -e "${YELLOW}Проверка и установка необходимых пакетов...${NC}"

PACKAGES=("smartmontools" "gddrescue" "testdisk" "ntfs-3g")
MISSING_PACKAGES=()

for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ Все необходимые пакеты уже установлены.${NC}"
else
    echo -e "${YELLOW}Устанавливаются пакеты: ${MISSING_PACKAGES[*]}${NC}"
    sudo apt update
    sudo apt install -y "${MISSING_PACKAGES[@]}"
    echo -e "${GREEN}✅ Установка завершена.${NC}"
fi

echo
echo -e "${BLUE}Список доступных дисков:${NC}"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep "disk"
echo

read -p "Введите имя диска (например, sda, nvme0n1): " DISK
DEVICE="/dev/$DISK"

if [ ! -b "$DEVICE" ]; then
    echo -e "${RED}❌ Устройство $DEVICE не существует!${NC}"
    exit 1
fi

echo
echo -e "${BLUE}=== Проверка S.M.A.R.T. информации для $DEVICE ===${NC}"
sudo smartctl -a "$DEVICE" || {
    echo -e "${RED}❌ Ошибка чтения S.M.A.R.T. (возможно, диск не поддерживает или не подключён правильно)${NC}"
    exit 1
}

echo
echo -e "${YELLOW}Запуск короткого S.M.A.R.T. теста...${NC}"
sudo smartctl -t short "$DEVICE"
echo "Ожидание 2 минут для завершения теста..."
sleep 120

echo
sudo smartctl -l selftest "$DEVICE"

echo
echo -e "${YELLOW}Запуск длинного S.M.A.R.T. теста... (может занять 1-2 часа)${NC}"
echo "Тест запущен в фоне. Проверить статус можно позже: smartctl -l selftest $DEVICE"
sudo smartctl -t long "$DEVICE"

echo
echo -e "${BLUE}=== Анализ состояния диска ===${NC}"

# Проверка на ошибки
FAILING="$(sudo smartctl -H "$DEVICE" | grep "overall-health" | awk '{print $6}')"
REALLOC_SECTORS="$(sudo smartctl -a "$DEVICE" | grep "Reallocated_Sector_Ct" | awk '{print $4}')"
REALLOC_EVENT_COUNT="$(sudo smartctl -a "$DEVICE" | grep "Reallocated_Event_Count" | awk '{print $4}')"

echo "Проверка здоровья: $FAILING"
echo "Переназначенные сектора: ${REALLOC_SECTORS:-N/A}"
echo "События переназначения: ${REALLOC_EVENT_COUNT:-N/A}"

DANGER=0
if [ "$FAILING" != "PASSED" ] && [ "$FAILING" != "Verified" ]; then
    echo -e "${RED}⚠️ Диск НЕ прошёл проверку здоровья!${NC}"
    DANGER=1
fi

if [ -n "$REALLOC_SECTORS" ] && [ "$REALLOC_SECTORS" -gt 0 ]; then
    echo -e "${RED}⚠️ Обнаружены переназначенные сектора: $REALLOC_SECTORS${NC}"
    DANGER=1
fi

if [ -n "$REALLOC_EVENT_COUNT" ] && [ "$REALLOC_EVENT_COUNT" -gt 0 ]; then
    echo -e "${RED}⚠️ Были события переназначения: $REALLOC_EVENT_COUNT${NC}"
    DANGER=1
fi

if [ $DANGER -eq 1 ]; then
    echo
    echo -e "${RED}🔥 ВЫСОКИЙ РИСК ПОТЕРИ ДАННЫХ! Рекомендуется сделать резервную копию и заменить диск.${NC}"
    read -p "Хотите начать клонирование с помощью ddrescue? (y/N): " DO_RESCUE
    if [[ "$DO_RESCUE" =~ ^[Yy]$ ]]; then
        read -p "Введите путь к выходному образу (например, /mnt/backup/disk.img): " IMAGE_PATH
        LOG_PATH="${IMAGE_PATH}.log"

        echo -e "${YELLOW}Запуск ddrescue... Копирование с попытками повтора (до 3 раз)${NC}"
        echo "Лог будет сохранён в: $LOG_PATH"
        sudo ddrescue -r 3 -v "$DEVICE" "$IMAGE_PATH" "$LOG_PATH"

        echo -e "${GREEN}✅ Копирование завершено. Теперь можно анализировать образ с помощью photorec/testdisk.${NC}"
    fi
else
    echo
    echo -e "${GREEN}✅ Диск выглядит здоровым. Рекомендуется периодически проверять S.M.A.R.T.${NC}"
fi

echo
echo -e "${BLUE}Готово. Для просмотра результатов позже используйте:${NC}"
echo "  smartctl -a $DEVICE"
echo "  smartctl -l selftest $DEVICE"
echo "  photorec $IMAGE_PATH   # если создавали образ"