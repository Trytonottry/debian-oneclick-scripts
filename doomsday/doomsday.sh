#!/bin/bash
set -euo pipefail

echo "💀 ЗАПУСК СКРИПТА 'СУДНЫЙ ДЕНЬ' 💀"
echo "⚠️  ВСЁ БУДЕТ УНИЧТОЖЕНО БЕЗВОЗВРАТНО"

# === Выбор режима ===
echo
echo "Выберите режим уничтожения:"
echo "  [1] 🔐 Только шифрование (обратимо, ключ сохраняется)"
echo "  [2] 💣 Полное затирание (необратимо, по DoD)"
read -p "Выбор (1/2): " MODE_CHOICE

case "$MODE_CHOICE" in
    1)
        EXEC_MODE="encrypt-only"
        echo "✅ Режим: Только шифрование"
        ;;
    2)
        EXEC_MODE="shred-full"
        echo "✅ Режим: Полное затирание"
        ;;
    *)
        echo "❌ Неверный выбор."
        exit 1
        ;;
esac

# === Сканирование сети ===
read -p "Введите подсеть ZeroTier (например, 192.168.192): " ZT_SUBNET
read -p "Введите свой ZeroTier IP (например, 192.168.192.10): " LOCAL_IP

declare -A TARGETS
COUNTER=1

echo "🔍 Сканирование сети $ZT_SUBNET.0/24..."

for i in $(seq 1 254); do
    IP="$ZT_SUBNET.$i"
    [[ "$IP" == "$LOCAL_IP" ]] && continue

    timeout 0.5 ping -c1 -W1 "$IP" &>/dev/null || continue

    # Проверка агента (порт 12345)
    if timeout 1 bash -c "echo 'PING' | nc $IP 12345" | grep -q "READY"; then
        NAME=$(ssh -o BatchMode=yes -o ConnectTimeout=2 $IP hostname 2>/dev/null || echo "device-$i")
        TARGETS[$COUNTER]="$IP:$NAME"
        echo "[$COUNTER] $NAME ($IP)"
        ((COUNTER++))
    fi
done

[[ ${#TARGETS[@]} -eq 0 ]] && { echo "❌ Не найдено ни одного агента."; exit 1; }

# === Выбор устройств ===
echo
echo "Выберите устройства:"
echo "  [A] Все"
echo "  [L] Указать номера (1,3,5)"
read -p "Выбор: " TARGET_MODE

TARGET_LIST=()

if [[ "$TARGET_MODE" == "A" ]]; then
    for val in "${TARGETS[@]}"; do
        TARGET_LIST+=("${val%%:*}")
    done
elif [[ "$TARGET_MODE" == "L" ]]; then
    read -p "Номера через запятую: " INPUT
    IFS=',' read -ra IDS <<< "$INPUT"
    for id in "${IDS[@]}"; do
        if [[ -n "${TARGETS[$id]+isset}" ]]; then
            TARGET_LIST+=("${TARGETS[$id]%%:*}")
        else
            echo "⚠️ Неверный ID: $id"
        fi
    done
else
    echo "❌ Отмена."
    exit 1
fi

# === Аутентификация ===
echo
read -s -p "Введите общий токен аутентификации: " AGENT_TOKEN
echo

# === Запуск на выбранных устройствах ===
for IP in "${TARGET_LIST[@]}"; do
    echo "🧨 Запуск на $IP (режим: $EXEC_MODE)..."
    (
        sleep 1
        echo "$AGENT_TOKEN"
        sleep 0.5
        echo "$EXEC_MODE"
    ) | timeout 10 nc "$IP" 12345 || echo "❌ Ошибка подключения к $IP"
done

echo
echo "💀 Судный день запущен в режиме: $EXEC_MODE"
echo "📡 Устройства начнут выполнение в течение 10 секунд."
echo "🔒 Связь с ними будет потеряна навсегда (в случае shred-full)."