#!/bin/bash
# Название: install_samba.sh
# Описание: One-click установка и настройка Samba с общей папкой
# Поддержка: Debian, Ubuntu (systemd)

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Установка и настройка Samba (One-Click) ===${NC}"

# Проверка на root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Этот скрипт должен запускаться с правами root (sudo)${NC}"
    exec sudo "$0" "$@"
fi

# Переменные
SHARE_NAME="public"
SHARE_PATH="/srv/samba/$SHARE_NAME"
SAMBA_CONF="/etc/samba/smb.conf"
BACKUP_CONF="/etc/samba/smb.conf.bak"

# Обновление пакетов
echo -e "${YELLOW}🔄 Обновление списка пакетов...${NC}"
apt update -qq

# Установка Samba
if ! command -v smbstatus &> /dev/null; then
    echo -e "${YELLOW}📦 Установка Samba...${NC}"
    apt install -y samba samba-common-bin
    echo -e "${GREEN}✅ Samba установлен.${NC}"
else
    echo -e "${GREEN}✅ Samba уже установлен.${NC}"
fi

# Создание папки для общей директории
echo -e "${YELLOW}📁 Создание общей папки: $SHARE_PATH${NC}"
mkdir -p "$SHARE_PATH"
chmod 1777 "$SHARE_PATH"  # rwx для всех + sticky bit
chown nobody:nogroup "$SHARE_PATH"

# Резервная копия конфига
if [ -f "$SAMBA_CONF" ]; then
    cp "$SAMBA_CONF" "$BACKUP_CONF"
    echo -e "${BLUE}📁 Резервная копия конфига: $BACKUP_CONF${NC}"
fi

# Настройка smb.conf
echo -e "${YELLOW}🔧 Настройка Samba (smb.conf)...${NC}"

cat > "$SAMBA_CONF" << EOF
[global]
   workgroup = WORKGROUP
   security = user
   map to guest = bad user
   server role = standalone server
   log file = /var/log/samba/%m.log
   log level = 1

# Общая анонимная папка
[$SHARE_NAME]
   path = $SHARE_PATH
   browsable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0666
   directory mask = 0777
EOF

echo -e "${GREEN}✅ Конфигурация Samba готова.${NC}"

# Перезапуск Samba
echo -e "${YELLOW}🔄 Перезапуск служб Samba...${NC}"
systemctl stop smbd nmbd || true
systemctl start smbd nmbd
systemctl enable smbd nmbd >/dev/null 2>&1

# Открытие портов в ufw (если установлен)
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    echo -e "${YELLOW}🛡️  Открытие портов в ufw...${NC}"
    ufw allow samba >/dev/null 2>&1 || true
    echo -e "${GREEN}✅ Порты Samba разрешены в ufw.${NC}"
fi

# Добавление пользователя (опционально)
echo
echo -e "${BLUE}🔐 Хотите добавить защищённого пользователя Samba? (да/нет)${NC}"
read -r -p "Введите 'yes' для добавления: " ADD_USER

if [[ "$ADD_USER" =~ ^[Yy][Ee][Ss]$ ]]; then
    read -rp "Введите имя пользователя Samba: " SMB_USER
    if id "$SMB_USER" &>/dev/null; then
        echo -e "${GREEN}✅ Пользователь $SMB_USER уже существует в системе.${NC}"
    else
        echo -e "${YELLOW}📝 Создаём системного пользователя $SMB_USER...${NC}"
        adduser --disabled-password --gecos "" "$SMB_USER"
    fi

    echo -e "${YELLOW}🔑 Установка пароля Samba для $SMB_USER${NC}"
    smbpasswd -a "$SMB_USER"
    echo -e "${GREEN}✅ Пользователь $SMB_USER добавлен в Samba.${NC}"

    # Добавляем защищённую папку
    SECURE_PATH="/srv/samba/secure"
    mkdir -p "$SECURE_PATH"
    chown "$SMB_USER:$SMB_USER" "$SECURE_PATH"
    chmod 755 "$SECURE_PATH"

    cat >> "$SAMBA_CONF" << EOF

[secure]
   path = $SECURE_PATH
   valid users = $SMB_USER
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   create mask = 0644
   directory mask = 0755
EOF

    systemctl restart smbd nmbd
    echo -e "${GREEN}✅ Защищённая папка /secure добавлена для пользователя $SMB_USER.${NC}"
fi

# Информация о подключении
IP=$(hostname -I | awk '{print $1}')
echo
echo -e "${GREEN}🎉 Samba успешно настроена!${NC}"
echo
echo -e "${BLUE}📌 Как подключиться:${NC}"
echo "Гостевой доступ (без пароля):"
echo "  smb://$IP/public"
echo "  \\\\$IP\\public"
echo
if [[ "$ADD_USER" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Защищённая папка (с паролем):"
    echo "  smb://$IP/secure"
    echo "  \\\\$IP\\secure"
fi
echo
echo -e "${YELLOW}📁 Общая папка: $SHARE_PATH${NC}"
echo -e "${YELLOW}📄 Конфиг: $SAMBA_CONF${NC}"
echo
echo -e "${GREEN}💡 Готово! Samba работает и доступна в сети.${NC}"