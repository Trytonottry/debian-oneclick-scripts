#!/bin/bash
# Название: install_samba_full.sh
# Описание: Полная установка Samba с автомонтированием, шифрованием и веб-интерфейсом
# Поддержка: Debian 10+, Ubuntu 20.04+

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Установка Samba с автомонтированием, шифрованием и веб-интерфейсом ===${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Этот скрипт должен запускаться с правами root${NC}"
    exec sudo "$0" "$@"
fi

# Переменные
SHARE_PATH="/srv/samba/public"
SAMBA_CONF="/etc/samba/smb.conf"
BACKUP_CONF="/etc/samba/smb.conf.bak"
MOUNT_BASE="/mnt/disk"

# Обновление
echo -e "${YELLOW}🔄 Обновление системы...${NC}"
apt update -qq
apt upgrade -yqq 2>/dev/null || true

# Установка Samba
if ! command -v smbstatus &> /dev/null; then
    echo -e "${YELLOW}📦 Установка Samba...${NC}"
    apt install -y samba samba-common-bin
    echo -e "${GREEN}✅ Samba установлен.${NC}"
fi

# Установка ntfs-3g для NTFS
if ! dpkg -l | grep -q ntfs-3g; then
    apt install -y ntfs-3g
fi

# Создание общей папки
mkdir -p "$SHARE_PATH"
chmod 1777 "$SHARE_PATH"
chown nobody:nogroup "$SHARE_PATH"

# Резервная копия конфига
if [ -f "$SAMBA_CONF" ]; then
    cp "$SAMBA_CONF" "$BACKUP_CONF"
    echo -e "${BLUE}📁 Резервная копия: $BACKUP_CONF${NC}"
fi

# --- Автомонтирование дисков ---
echo -e "${YELLOW}🔧 Настройка автомонтирования дисков...${NC}"

# Создаём скрипт для монтирования
cat > /usr/local/bin/mount_samba_disks.sh << 'EOF'
#!/bin/bash
# Автомонтирование всех несистемных дисков

MOUNT_BASE="/mnt/disk"
mkdir -p "$MOUNT_BASE"

for device in /dev/sd*[0-9] /dev/nvme* /dev/mmcblk*p[0-9]; do
    [ -b "$device" ] || continue

    # Пропускаем системный диск
    if mount | grep "$device" | grep -q " / "; then
        continue
    fi

    # Пропускаем уже смонтированные
    if mount | grep -q "$device"; then
        continue
    fi

    # Определяем тип ФС
    fs_type=$(blkid -o value -s TYPE "$device" || echo "")

    if [[ "$fs_type" =~ ^(ntfs|vfat|ext4|xfs)$ ]]; then
        uuid=$(blkid -s UUID -o value "$device")
        dir="$MOUNT_BASE/$(basename "$device")"
        mkdir -p "$dir"

        case "$fs_type" in
            ntfs)
                mount -t ntfs-3g -o rw,uid=1000,gid=1000,umask=000 "$device" "$dir" ;;
            vfat|msdos)
                mount -t vfat -o rw,uid=1000,gid=1000,umask=000 "$device" "$dir" ;;
            *)
                mount -t "$fs_type" -o rw "$device" "$dir" ;;
        esac

        if [ $? -eq 0 ]; then
            echo "✅ Смонтировано: $device -> $dir"
        else
            echo "❌ Ошибка монтирования: $device"
        fi
    fi
done
EOF

chmod +x /usr/local/bin/mount_samba_disks.sh

# Добавляем в автозагрузку
cat > /etc/systemd/system/mount-samba-disks.service << 'EOF'
[Unit]
Description=Mount Samba Disks
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/mount_samba_disks.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mount-samba-disks.service
echo -e "${GREEN}✅ Автомонтирование настроено.${NC}"

# --- Основной конфиг Samba с шифрованием ---
echo -e "${YELLOW}🔐 Настройка Samba с шифрованием (SMB3) и общими папками...${NC}"

cat > "$SAMBA_CONF" << EOF
[global]
   workgroup = WORKGROUP
   server string = Samba Server %h
   security = user
   map to guest = bad user
   server role = standalone server
   log file = /var/log/samba/%m.log
   log level = 1

   # 🔐 Шифрование трафика (SMB3)
   server smb encrypt = required

   # Для совместимости (можно убрать, если не нужно)
   # smb encrypt = desired

# Гостевая папка
[public]
   path = $SHARE_PATH
   browsable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0666
   directory mask = 0777
EOF

# Экспорт всех смонтированных дисков через Samba
echo -e "${YELLOW}📁 Добавление дисков в Samba...${NC}"
for mount_point in /mnt/disk/*; do
    if [ -d "$mount_point" ] && [ "$(ls -A "$mount_point")" ]; then
        share_name="disk_$(basename "$mount_point")"
        echo -e "\n[$share_name]\n   path = $mount_point\n   browsable = yes\n   writable = yes\n   guest ok = yes\n   read only = no" >> "$SAMBA_CONF"
        echo "✅ Добавлено: [$share_name] -> $mount_point"
    fi
done

# --- Установка Cockpit (веб-интерфейс) ---
echo -e "${YELLOW}🌐 Установка Cockpit (веб-интерфейс)...${NC}"
if ! command -v cockpit &> /dev/null; then
    apt install -y cockpit cockpit-samba
    systemctl enable --now cockpit.socket
    echo -e "${GREEN}✅ Cockpit установлен. Доступен на https://$(hostname -I | awk '{print $1}'):9090${NC}"
else
    echo -e "${GREEN}✅ Cockpit уже установлен.${NC}"
fi

# --- Пользователь с паролем (опционально) ---
echo
echo -e "${BLUE}🔐 Добавить пользователя Samba? (yes/no)${NC}"
read -r -p "Введите 'yes': " ADD_USER

if [[ "$ADD_USER" =~ ^[Yy][Ee][Ss]$ ]]; then
    read -rp "Имя пользователя: " SMB_USER
    if ! id "$SMB_USER" &>/dev/null; then
        adduser --disabled-password --gecos "" "$SMB_USER"
    fi

    echo -e "${YELLOW}🔑 Установка пароля Samba для $SMB_USER${NC}"
    smbpasswd -a "$SMB_USER"

    mkdir -p "/srv/samba/secure_$SMB_USER"
    chown "$SMB_USER:$SMB_USER" "/srv/samba/secure_$SMB_USER"
    chmod 700 "/srv/samba/secure_$SMB_USER"

    cat >> "$SAMBA_CONF" << EOF

[secure_$SMB_USER]
   path = /srv/samba/secure_$SMB_USER
   valid users = $SMB_USER
   browsable = yes
   writable = yes
   guest ok = no
   read only = no
   create mask = 0600
   directory mask = 0700
EOF

    echo -e "${GREEN}✅ Защищённая папка для $SMB_USER добавлена.${NC}"
fi

# --- ufw ---
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    ufw allow 9090    # cockpit
    ufw allow samba   # 139,445
    echo -e "${GREEN}✅ Порты открыты: 9090 (Cockpit), 139/445 (Samba)${NC}"
fi

# Перезапуск Samba
systemctl restart smbd nmbd
systemctl enable smbd nmbd >/dev/null 2>&1

# --- Финал ---
IP=$(hostname -I | awk '{print $1}')
echo
echo -e "${GREEN}🎉 Установка завершена!${NC}"
echo
echo -e "${BLUE}📌 Подключение:${NC}"
echo "Гостевой доступ: smb://$IP/public"
echo "Диски: smb://$IP/disk_sda1, smb://$IP/disk_nvme0n1p2 и т.д."
if [[ "$ADD_USER" =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "Личная папка: smb://$IP/secure_$SMB_USER"
fi
echo
echo -e "${BLUE}🌐 Веб-интерфейс: https://$IP:9090${NC}"
echo "  - Управление системой, дисками, Samba (через плагин)"
echo
echo -e "${YELLOW}💡 Примечание: SMB3-шифрование включено. Клиенты должны поддерживать SMB 3.0+${NC}"
echo -e "${GREEN}✅ Готово!${NC}"