#!/bin/bash

# Настройки под твою систему — измени на свои
HOSTS=(
  "debian-laptop moriarty@192.168.192.10"
  "lubuntu-mini kali@10.147.19.210"
  "orangepi maya@10.147.19.180"
)

# Путь к локальным бэкапам
BACKUP_DIR="$HOME/backups"

# Функция: выполнить команду на всех хостах
run_on_all() {
  local cmd="$1"
  local title="$2"
  OUTPUT=""
  for entry in "${HOSTS[@]}"; do
    name=$(echo "$entry" | awk '{print $1}')
    addr=$(echo "$entry" | awk '{print $2}')
    echo "Выполняется на $name ($addr): $title"
    result=$(ssh -o ConnectTimeout=10 "$addr" "$cmd" 2>&1)
    OUTPUT+="$name:\n$result\n---\n"
  done
  echo -e "$OUTPUT"
}

# Функция: выполнить команду на одном хосте
run_on_host() {
  local host_entry="$1"
  local cmd="$2"
  local name=$(echo "$host_entry" | awk '{print $1}')
  local addr=$(echo "$host_entry" | awk '{print $2}')
  ssh -t "$addr" "$cmd"
}

# Главное меню
while true; do
  CHOICE=$(zenity --width=500 --height=400 \
    --list \
    --title="🔧 Центр управления сетью" \
    --text="Выберите действие:" \
    --column="Действие" \
    --column="Описание" \
    "status" "Показать статус всех узлов (CPU, RAM, диск, температура)" \
    "update" "Обновить все системы (apt update && upgrade)" \
    "zt-restart" "Перезапустить ZeroTier на всех узлах" \
    "sync-to-backup" "Синхронизировать ~/Documents и ~/Scripts в бэкап" \
    "backup-from-nodes" "Забрать данные с узлов в локальные бэкапы" \
    "reboot-orange" "Перезагрузить Orange Pi 3 Zero" \
    "start-jellyfin" "Запустить Jellyfin на Lubuntu Mini" \
    "shell-debian" "Открыть терминал на Debian ноутбуке" \
    "shell-lubuntu" "Открыть терминал на Lubuntu Mini" \
    "shell-orangepi" "Открыть терминал на Orange Pi" \
    "quit" "Выйти")

  case "$CHOICE" in

    "status")
      STATUS_OUTPUT=$(run_on_all '
        echo "Host: $(hostname)"
        echo "Uptime: $(uptime -p)"
        echo "RAM: $(free -h | awk "/^Mem:/ {print \$3}"/) used / $(free -h | awk "/^Mem:/ {print \$2}"/) total"
        echo "Disk: $(df -h / | tail -1 | awk "{print \$5}" | tr -d "%")% used"
        TEMP=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1 | awk "{print \$1/1000}" 2>/dev/null || echo "N/A")
        echo "Temp: $TEMP °C"
        echo "ZT: $(zerotier-cli listnetworks 2>/dev/null | grep \"JOINING\\|OK\" || echo \"ZeroTier не запущен\")"
        echo ""
      ' "Сбор статуса")
      zenity --text-info --title="📊 Статус всех узлов" --width=600 --height=400 --text="$STATUS_OUTPUT"
      ;;

    "update")
      if zenity --question --text="Обновить все системы? Это может занять время."; then
        UPDATE_OUTPUT=$(run_on_all 'sudo apt update && sudo apt upgrade -y' "Обновление системы")
        zenity --text-info --title="📦 Результат обновления" --width=600 --height=400 --text="$UPDATE_OUTPUT"
      fi
      ;;

    "zt-restart")
      if zenity --question --text="Перезапустить ZeroTier на всех узлах?"; then
        ZT_OUTPUT=$(run_on_all '
          sudo systemctl restart zerotier-one && echo "OK" || echo "Ошибка"
        ' "Перезапуск ZeroTier")
        zenity --info --text="ZeroTier перезапущен на всех узлах."
      fi
      ;;

    "sync-to-backup")
      rsync -avz "$HOME/Documents/" "${HOSTS[1]#* }:/home/user/backup/docs/" 2>&1
      rsync -avz "$HOME/Scripts/" "${HOSTS[2]#* }:/home/user/scripts/" 2>&1
      zenity --info --text="Документы и скрипты синхронизированы на Lubuntu и Orange Pi."
      ;;

    "backup-from-nodes")
      mkdir -p "$BACKUP_DIR/lubuntu" "$BACKUP_DIR/orangepi"
      rsync -avz "${HOSTS[1]#* }:~/important/" "$BACKUP_DIR/lubuntu/" 2>&1
      rsync -avz "${HOSTS[2]#* }:~/data/" "$BACKUP_DIR/orangepi/" 2>&1
      zenity --info --text="Бэкапы получены и сохранены в $BACKUP_DIR"
      ;;

    "reboot-orange")
      if zenity --question --text="Перезагрузить Orange Pi 3 Zero?"; then
        ssh "${HOSTS[2]#* }" 'sudo reboot' &
        zenity --info --text="Orange Pi перезагружается..."
      fi
      ;;

    "start-jellyfin")
      ssh "${HOSTS[1]#* }" 'systemctl --user start jellyfin' 2>&1
      zenity --info --text="Jellyfin запущен на Lubuntu Mini."
      ;;

    "shell-debian")
      run_on_host "${HOSTS[0]}" 'exec $SHELL'
      ;;

    "shell-lubuntu")
      run_on_host "${HOSTS[1]}" 'exec $SHELL'
      ;;

    "shell-orangepi")
      run_on_host "${HOSTS[2]}" 'exec $SHELL'
      ;;

    "quit")
      zenity --info --text="До встречи!"
      break
      ;;

    *)
      zenity --error --text="Неизвестное действие."
      ;;

  esac
done