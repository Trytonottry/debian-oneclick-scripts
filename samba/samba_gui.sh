#!/bin/bash
# Название: samba_gui.sh
# Описание: Полная настройка Samba с GUI (zenity), автомонтированием, шифрованием, Cockpit
# Поддержка: Debian, Ubuntu

if [ "$EUID" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

# Установка zenity, если нет
if ! command -v zenity &> /dev/null; then
    apt update -qq
    apt install -y zenity
fi

export PATH="/usr/local/sbin:/usr/sbin:/sbin:$PATH"

# Цвета (для терминала, если запускается вручную)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# Показ сообщения
show_info() {
    zenity --info --title="$1" --text="$2" --width=400
}

# Задать вопрос (yes/no)
ask_yes_no() {
    zenity --question --title="$1" --text="$2" --width=400
}

# Ввод текста
input_text() {
    zenity --entry --title="$1" --text="$2" --entry-text="$3"
}

# Выбор из списка
choose_option() {
    local title="$1"; shift
    local text="$1"; shift
    zenity --list --title="$title" --text="$text" --column="Выбор" --width=400 --height=300 "$@"
}

show_info "Samba GUI" "Запуск установки Samba с графическим интерфейсом."

# Переменные
SHARE_PATH="/srv/samba/public"
SAMBA_CONF="/etc/samba/smb.conf"
BACKUP_CONF="/etc/samba/smb.conf.bak"
MOUNT_BASE="/mnt/disk"

# Установка пакетов
apt update -qq >/dev/null 2>&1 || true

PACKAGES=("samba" "samba-common-bin" "ntfs-3g")
MISSING=($(comm -13 <(dpkg-query -f '%n\n' -W 2>/dev/null | sort) <(printf '%s\n' "${PACKAGES[@]}" | sort)))
if [ ${#MISSING[@]} -gt 0 ]; then
    apt install -y "${MISSING[@]}"
    show_info "Установка" "Установлены: ${MISSING[*]}"
fi

# Включить шифрование?
ENCRYPT="no"
if ask_yes_no "Шифрование" "Включить шифрование SMB3 (требует поддержки клиентом)?"; then
    ENCRYPT="yes"
fi

# Гостевой доступ?
GUEST="yes"
if ! ask_yes_no "Гостевой доступ" "Разрешить анонимный доступ (без пароля) в папку 'public'?"; then
    GUEST="no"
fi

# Добавить пользователя?
ADD_USER="no"
if ask_yes_no "Пользователь" "Добавить защищённого пользователя с паролем?"; then
    ADD_USER="yes"
    SMB_USER=$(input_text "Пользователь" "Имя пользователя Samba" "user")
    while [ -z "$SMB_USER" ]; do
        SMB_USER=$(input_text "Ошибка" "Имя не может быть пустым" "user")
    done
fi

# Установить Cockpit?
INSTALL_COCKPIT="no"
if ask_yes_no "Cockpit" "Установить веб-интерфейс Cockpit (порт 9090)?"; then
    INSTALL_COCKPIT="yes"
fi

# --- Автомонтирование ---
cat > /usr/local/bin/mount_samba_disks.sh << 'EOF'
#!/bin/bash
MOUNT_BASE="/mnt/disk"
mkdir -p "$MOUNT_BASE"
for device in /dev/sd*[0-9] /dev/nvme* /dev/mmcblk*p[0-9]; do
    [ -b "$device" ] || continue
    if mount | grep "$device" | grep -q " / "; then continue; fi
    if mount | grep -q "$device"; then continue; fi
    fs_type=$(blkid -o value -s TYPE "$device" || echo "")
    if [[ "$fs_type" =~ ^(ntfs|vfat|ext4|xfs)$ ]]; then
        uuid=$(blkid -s UUID -o value "$device")
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

chmod +x /usr/local/bin/mount_samba_disks.sh

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

# --- Samba config ---
mkdir -p "$SHARE_PATH"
chmod 1777 "$SHARE_PATH"
chown nobody:nogroup "$SHARE_PATH"

[ -f "$SAMBA_CONF" ] && cp "$SAMBA_CONF" "$BACKUP_CONF"

cat > "$SAMBA_CONF" << EOF
[global]
   workgroup = WORKGROUP
   security = user
   map to guest = bad user
   server role = standalone server
   log file = /var/log/samba/%%m.log
   log level = 1
EOF

if [ "$ENCRYPT" = "yes" ]; then
    echo "   server smb encrypt = required" >> "$SAMBA_CONF"
fi

# Гостевая папка
if [ "$GUEST" = "yes" ]; then
cat >> "$SAMBA_CONF" << EOF
[public]
   path = $SHARE_PATH
   browsable = yes
   writable = yes
   guest ok = yes
   read only = no
   create mask = 0666
   directory mask = 0777
EOF
fi

# Экспорт дисков
for mp in /mnt/disk/*; do
    if [ -d "$mp" ] && [ "$(ls -A "$mp")" ]; then
        name="disk_$(basename "$mp")"
        echo -e "\n[$name]\n   path = $mp\n   browsable = yes\n   writable = yes\n   guest ok = yes\n   read only = no" >> "$SAMBA_CONF"
    fi
done

# Пользователь
if [ "$ADD_USER" = "yes" ]; then
    if ! id "$SMB_USER" &>/dev/null; then
        adduser --disabled-password --gecos "" "$SMB_USER"
    fi
    smbpasswd -a "$SMB_USER" << EOF
password
password
EOF
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
EOF
fi

# Cockpit
if [ "$INSTALL_COCKPIT" = "yes" ]; then
    apt install -y cockpit cockpit-samba
    systemctl enable --now cockpit.socket
fi

# ufw
if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
    ufw allow samba >/dev/null 2>&1 || true
    [ "$INSTALL_COCKPIT" = "yes" ] && ufw allow 9090 >/dev/null 2>&1
fi

systemctl restart smbd nmbd
systemctl enable smbd nmbd >/dev/null 2>&1

# --- Финал ---
IP=$(hostname -I | awk '{print $1}')
TEXT="✅ Samba настроена!\n\n"
[ "$GUEST" = "yes" ] && TEXT+="🔸 Гость: smb://$IP/public\n"
TEXT+="🔸 Диски: smb://$IP/disk_*\n"
[ "$ADD_USER" = "yes" ] && TEXT+="🔸 Личная: smb://$IP/secure_$SMB_USER\n"
[ "$INSTALL_COCKPIT" = "yes" ] && TEXT+="🌐 Cockpit: https://$IP:9090\n"
[ "$ENCRYPT" = "yes" ] && TEXT+="🔐 Шифрование SMB3 включено\n"

show_info "Готово!" "$TEXT"