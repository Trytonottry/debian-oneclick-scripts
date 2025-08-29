#!/bin/bash
set -euo pipefail

echo "💀 ЗАПУСК 'СУДНОГО ДНЯ' С USB-ФЛЕШКИ 💀"
echo "🔐 Оффлайн-режим. Все компоненты локальные."

# === Режим ===
echo
echo "Выберите режим:"
echo "  [1] 🔐 Только шифрование (ключ сохраняется)"
echo "  [2] 💣 Полное затирание (необратимо)"
read -p "Выбор (1/2): " MODE
case "$MODE" in
    1) EXEC_MODE="encrypt-only" ;;
    2) EXEC_MODE="shred-full" ;;
    *) echo "❌ Отмена."; exit 1 ;;
esac

# === Сеть ===
echo "🔄 Включение сети..."
rc-service networking restart
rc-service openntpd restart
sleep 5

# === ZeroTier ===
echo "🚀 Запуск ZeroTier..."
rc-service zerotier-one start
sleep 3

# Присоединение к сети (замените на вашу)
read -p "Введите ID сети ZeroTier: " ZT_NETWORK
zerotier-cli join "$ZT_NETWORK"
echo "✅ Присоединились к сети. Подождите 10 секунд..."
sleep 10

# Получение своего ZT IP
ZT_IP=$(ip addr show zt+ | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
echo "🌐 Ваш ZeroTier IP: $ZT_IP"

# === Сканирование и выбор узлов ===
echo "🔍 Поиск активных агентов..."

declare -A TARGETS
COUNTER=1

for ip in $(arp -a | grep zt | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+'); do
    if timeout 1 bash -c "echo 'PING' | nc $ip 12345" | grep -q "READY"; then
        NAME=$(timeout 3 ssh -o BatchMode=yes -o ConnectTimeout=3 $ip hostname 2>/dev/null || echo "device-$COUNTER")
        TARGETS[$COUNTER]="$ip:$NAME"
        echo "[$COUNTER] $NAME ($ip)"
        ((COUNTER++))
    fi
done

[[ ${#TARGETS[@]} -eq 0 ]] && { echo "❌ Агенты не найдены."; exit 1; }

# === Выбор устройств ===
echo
echo "Выберите:"
echo "  [A] Все"
echo "  [L] Указать номера"
read -p "Выбор: " TARGET_MODE

TARGET_LIST=()

if [[ "$TARGET_MODE" == "A" ]]; then
    for val in "${TARGETS[@]}"; do
        TARGET_LIST+=("${val%%:*}")
    done
elif [[ "$TARGET_MODE" == "L" ]]; then
    read -p "Номера: " INPUT
    IFS=',' read -ra IDS <<< "$INPUT"
    for id in "${IDS[@]}"; do
        [[ -n "${TARGETS[$id]+isset}" ]] && TARGET_LIST+=("${TARGETS[$id]%%:*}")
    done
fi

# === Аутентификация ===
echo
read -s -p "Введите токен агентов: " AGENT_TOKEN
echo

# === Запуск ===
for IP in "${TARGET_LIST[@]}"; do
    echo "🧨 Атака на $IP..."
    (
        sleep 1
        echo "$AGENT_TOKEN"
        sleep 0.5
        echo "$EXEC_MODE"
    ) | timeout 10 nc "$IP" 12345 || echo "❌ Ошибка: $IP"
done

echo "💀 Судный день завершён. Все выбранные системы уничтожены."
echo "🛑 Вы можете выключить устройство."

# Блокировка флешки (опционально)
echo "🔒 Самоуничтожение флешки через 60 секунд..."
sleep 60
# dd if=/dev/urandom of=/dev/sdX bs=1M count=1000  # ⚠️ ОПАСНО: стирает саму флешку