#!/bin/bash

# Путь к файлу со списком пакетов
INPUT_FILE="$HOME/installed_packages.txt"

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Проверка, существует ли файл
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "${RED}❌ Файл '$INPUT_FILE' не найден!${NC}"
    echo "Помести файл со списком пакетов в домашнюю директорию и переименуй его в 'installed_packages.txt'"
    read -p "Нажми Enter для выхода..." 
    exit 1
fi

echo -e "${YELLOW}=== Восстановление пакетов из $INPUT_FILE ===${NC}"
echo "Дата запуска: $(date)"
echo ""

read -p "Продолжить установку пакетов? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Установка отменена."
    exit 0
fi

# Переменные для сбора пакетов
APT_PACKAGES=()
FLATPAK_PACKAGES=()
SNAP_PACKAGES=()

# Флаги секций
SECTION=""

# Парсинг файла
while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
        "=== APT (dpkg) ===")
            SECTION="apt"
            continue
            ;;
        "=== FLATPAK ===")
            SECTION="flatpak"
            continue
            ;;
        "=== SNAP ===")
            SECTION="snap"
            continue
            ;;
        "")
            continue
            ;;
        *)
            if [[ "$SECTION" == "apt" && "$line" != "deinstall" && -n "$line" ]]; then
                APT_PACKAGES+=("$line")
            elif [[ "$SECTION" == "flatpak" && "$line" != "Нет установленных"* && -n "$line" ]]; then
                FLATPAK_PACKAGES+=("$line")
            elif [[ "$SECTION" == "snap" && "$line" != "Нет установленных"* && -n "$line" ]]; then
                SNAP_PACKAGES+=("$line")
            fi
            ;;
    esac
done < "$INPUT_FILE"

# --- УСТАНОВКА APT-ПАКЕТОВ ---
if [ ${#APT_PACKAGES[@]} -gt 0 ]; then
    echo -e "${GREEN}📦 Устанавливаем APT-пакеты...${NC}"
    sudo apt update
    sudo apt install -y "${APT_PACKAGES[@]}"
else
    echo "Нет APT-пакетов для установки."
fi

# --- УСТАНОВКА И НАСТРОЙКА FLATPAK ---
if [ ${#FLATPAK_PACKAGES[@]} -gt 0 ]; then
    if ! command -v flatpak &> /dev/null; then
        echo -e "${YELLOW}🔄 flatpak не установлен. Устанавливаем...${NC}"
        sudo apt update
        sudo apt install -y flatpak
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Ошибка при установке flatpak.${NC}"
        else
            echo -e "${GREEN}✅ flatpak установлен.${NC}"
        fi
    else
        echo "flatpak уже установлен."
    fi

    # Проверка наличия flathub
    if ! flatpak remotes | grep -q flathub; then
        echo -e "${YELLOW}🔄 Добавляем репозиторий Flathub...${NC}"
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Репозиторий Flathub добавлен.${NC}"
        else
            echo -e "${RED}❌ Не удалось добавить Flathub.${NC}"
        fi
    else
        echo "Репозиторий Flathub уже добавлен."
    fi

    # Установка пакетов
    echo -e "${GREEN}📦 Устанавливаем FLATPAK-приложения...${NC}"
    for pkg in "${FLATPAK_PACKAGES[@]}"; do
        if flatpak install -y flathub "$pkg"; then
            echo -e "✅ Установлен: $pkg"
        else
            echo -e "${RED}⚠️ Не удалось установить: $pkg${NC}"
        fi
    done
else
    echo "Нет FLATPAK-пакетов для установки."
fi

# --- УСТАНОВКА И НАСТРОЙКА SNAP ---
if [ ${#SNAP_PACKAGES[@]} -gt 0 ]; then
    if ! command -v snap &> /dev/null; then
        echo -e "${YELLOW}🔄 snapd не установлен. Устанавливаем...${NC}"
        sudo apt update
        sudo apt install -y snapd
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Ошибка при установке snapd.${NC}"
        else
            echo -e "${GREEN}✅ snapd установлен.${NC}"
            # Перезапуск PATH для текущей сессии
            export PATH=$PATH:/snap/bin
        fi
    else
        echo "snapd уже установлен."
    fi

    # Включение snapd (если используется systemd)
    sudo systemctl enable --now snapd &> /dev/null || true
    sudo systemctl start snapd &> /dev/null || true

    # Установка пакетов
    echo -e "${GREEN}📦 Устанавливаем SNAP-пакеты...${NC}"
    for pkg in "${SNAP_PACKAGES[@]}"; do
        if snap install "$pkg"; then
            echo -e "✅ Установлен: $pkg"
        else
            echo -e "${RED}⚠️ Не удалось установить: $pkg${NC}"
        fi
    done
else
    echo "Нет SNAP-пакетов для установки."
fi

echo -e "${GREEN}✅ Восстановление всех пакетов завершено!${NC}"
read -p "Нажмите Enter для выхода..."