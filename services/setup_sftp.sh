#!/bin/bash

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Проверка на root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}❌ Этот скрипт должен запускаться с правами root (через sudo).${NC}"
    echo "Используй: sudo $0"
    exit 1
fi

echo -e "${YELLOW}=== Настройка SFTP-сервера на Lubuntu ===${NC}"
echo "Дата: $(date)"
echo ""

# Обновление системы (опционально, но рекомендуется)
echo -e "${GREEN}🔄 Обновляем список пакетов...${NC}"
apt update

# Установка OpenSSH-сервера, если не установлен
if ! dpkg -l | grep -q openssh-server; then
    echo -e "${GREEN}📦 Устанавливаем OpenSSH-сервер...${NC}"
    apt install -y openssh-server
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Ошибка при установке openssh-server${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ OpenSSH-сервер установлен.${NC}"
else
    echo "OpenSSH-сервер уже установлен."
fi

# Включаем автозагрузку и запускаем
systemctl enable ssh
systemctl restart ssh

# === Настройка SFTP ===
SFTP_GROUP="sftpusers"
SFTP_USER=""
SFTP_PASS=""

# Запрос имени пользователя
echo ""
read -p "Введите имя SFTP-пользователя: " SFTP_USER
if [[ -z "$SFTP_USER" ]]; then
    echo -e "${RED}❌ Имя пользователя не может быть пустым.${NC}"
    exit 1
fi

# Проверка, существует ли пользователь
if id "$SFTP_USER" &>/dev/null; then
    echo -e "${YELLOW}⚠️ Пользователь '$SFTP_USER' уже существует. Используем его.${NC}"
else
    # Создаём пользователя без домашней директории — она будет в chroot
    echo -e "${GREEN}➕ Создаём пользователя '$SFTP_USER'...${NC}"
    useradd -m -g sftpusers -s /usr/sbin/nologin "$SFTP_USER"
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}❌ Ошибка при создании пользователя.${NC}"
        exit 1
    fi
fi

# Устанавливаем пароль
echo ""
echo -e "${YELLOW}🔑 Установите пароль для пользователя '$SFTP_USER':${NC}"
passwd "$SFTP_USER"

# Создаём группу, если её нет
if ! getent group "$SFTP_GROUP" > /dev/null 2>&1; then
    groupadd "$SFTP_GROUP"
    echo -e "${GREEN}✅ Группа '$SFTP_GROUP' создана.${NC}"
fi

# Добавляем пользователя в группу
usermod -aG "$SFTP_GROUP" "$SFTP_USER"

# === Настройка chroot в /etc/ssh/sshd_config ===
SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_CONFIG="/etc/ssh/sshd_config.bak.sftp.$(date +%s)"

# Резервная копия
cp "$SSHD_CONFIG" "$BACKUP_CONFIG"
echo -e "${GREEN}💾 Создана резервная копия SSH-конфига: $BACKUP_CONFIG${NC}"

# Удаляем старую секцию SFTP, если есть
sed -i '/# === SFTP Chroot ===/,/# === End SFTP ===/d' "$SSHD_CONFIG"

# Добавляем новую конфигурацию
cat >> "$SSHD_CONFIG" << EOF

# === SFTP Chroot ===
Match Group $SFTP_GROUP
    ChrootDirectory /home/%u
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
# === End SFTP ===
EOF

echo -e "${GREEN}✅ Конфигурация SFTP добавлена в /etc/ssh/sshd_config${NC}"

# Настройка прав: домашняя директория должна быть root:root, а /home/username/upload — пользователю
USER_HOME="/home/$SFTP_USER"

chown root:root "$USER_HOME"
chmod 755 "$USER_HOME"

# Создаём папку для загрузки (можно менять)
UPLOAD_DIR="$USER_HOME/upload"
mkdir -p "$UPLOAD_DIR"
chown "$SFTP_USER":"$SFTP_GROUP" "$UPLOAD_DIR"
chmod 755 "$UPLOAD_DIR"

echo -e "${GREEN}📁 Создана папка для загрузки: $UPLOAD_DIR${NC}"
echo -e "${YELLOW}ℹ️  Пользователь может загружать файлы только в /upload${NC}"

# Перезапуск SSH
echo -e "${GREEN}🔄 Перезапуск SSH-сервиса...${NC}"
systemctl restart ssh

if systemctl is-active --quiet ssh; then
    echo -e "${GREEN}✅ SSH-сервис перезапущен успешно.${NC}"
else
    echo -e "${RED}❌ Ошибка при перезапуске SSH!${NC}"
    exit 1
fi

# === Вывод информации ===
IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${GREEN}🎉 SFTP-сервер настроен!${NC}"
echo "────────────────────────────"
echo "Пользователь: $SFTP_USER"
echo "Пароль: установлен вами"
echo "IP-адрес: $IP"
echo "Порт: 22"
echo "Доступ через SFTP:"
echo "  sftp://$SFTP_USER@$IP"
echo ""
echo "⚠️  Пользователь НЕ имеет shell-доступ (без входа в терминал)"
echo "📁 Загружать файлы можно только в папку /upload"
echo ""
echo -e "${YELLOW}💡 Подключиться можно через FileZilla, WinSCP, или в файловом менеджере (ввести sftp://IP)${NC}"

read -p "Нажмите Enter для выхода..."