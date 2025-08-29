#!/bin/bash
# Название: samba_usb.sh
# Описание: Автономная Samba-утилита для флешки
# Особенности: работает без интернета, копирует скрипт и данные

set -euo pipefail

echo "=== Samba USB — автономная версия ==="

if [ "$EUID" -ne 0 ]; then
    echo "Запустите с sudo"
    exec sudo "$0" "$@"
fi

# Папка на флешке
USB_ROOT=$(dirname "$(readlink -f "$0")")
CONFIG_DIR="$USB_ROOT/.samba_usb"
mkdir -p "$CONFIG_DIR"

# Проверка, где запущено
if [[ "$USB_ROOT" =~ ^/home|/tmp ]]; then
    echo "❌ Скрипт должен быть на флешке, а не в /home или /tmp"
    exit 1
fi

# Установка пакетов из кэша (если есть)
CACHE="$USB_ROOT/pkg-cache"
if [ -d "$CACHE" ]; then
    echo "📦 Установка пакетов из кэша..."
    dpkg -i "$CACHE"/*.deb 2>/dev/null || apt -f install -y
fi

# Установка необходимых пакетов (если нет)
PACKAGES=("samba" "ntfs-3g" "systemd")
for pkg in "${PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $pkg "; then
        echo "⚠️ $pkg не установлен. Требуется интернет для установки."
        read -p "Продолжить (y/N)? " -n1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        apt update && apt install -y "$pkg"
    fi
done

# Создание служб и скриптов

cat > /usr/local/bin/samba-usb-start << EOF
#!/bin/bash
# Автозапуск Samba при монтировании флешки

USB_MOUNT="$USB_ROOT"
if [ -f "\$USB_MOUNT/samba_usb.sh" ]; then
    \$USB_MOUNT/mount_samba_disks.sh
    systemctl restart smbd nmbd
fi
EOF

chmod +x /usr/local/bin/samba-usb-start

# Автомонтирование (копируем из предыдущего скрипта)
cat > "$USB_ROOT/mount_samba_disks.sh" << 'EOF'
#!/bin/bash
MOUNT_BASE="/mnt/disk"
mkdir -p "$MOUNT_BASE"
for device in /dev/sd*[0-9] /dev/nvme* /dev/mmcblk*p[0-9]; do
    [ -b "$device" ] || continue
    if mount | grep "$device" | grep -q " / "; then continue; fi
    if mount | grep -q "$device"; then continue; fi
    fs_type=$(blkid -o value -s TYPE "$device" || echo "")
    if [[ "$fs_type" =~ ^(ntfs|vfat|ext4|xfs)$ ]]; then
        dir="$MOUNT_BASE/$(basename "$device")"
        mkdir -p "$dir"
        case "$fs_type" in
            ntfs) mount -t ntfs-3g -o rw,uid=1000,gid=1000,umask=000 "$device" "$dir" ;;
            vfat) mount -t vfat -o rw,uid=1000,gid=1000,umask=000 "$device" "$dir" ;;
            *) mount -t "$fs_type" -o rw "$device" "$dir" ;;
        esac
    fi
done
EOF

chmod +x "$USB_ROOT/mount_samba_disks.sh"

# Пример конфига
cat > "$CONFIG_DIR/smb.conf" << 'EOF'
[global]
   workgroup = WORKGROUP
   security = user
   map to guest = bad user
   server smb encrypt = required
   log file = /var/log/samba/%%m.log

[public]
   path = /srv/samba/public
   browsable = yes
   writable = yes
   guest ok = yes
   read only = no
EOF

mkdir -p /srv/samba/public
chmod 1777 /srv/samba/public

cp "$CONFIG_DIR/smb.conf" /etc/samba/smb.conf

systemctl enable smbd nmbd
systemctl restart smbd nmbd

echo "✅ Автономная Samba-флешка настроена!"
echo "🔹 Подключайте флешку и запускайте $USB_ROOT/mount_samba_disks.sh"
echo "🔹 Или добавьте автозапуск через cron @reboot"