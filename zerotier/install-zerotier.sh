#!/bin/bash

# Проверка на root
if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: Запустите скрипт от имени root или с sudo."
    exit 1
fi

# Запрашиваем ID сети ZeroTier
read -p "Введите ID сети ZeroTier: " NETWORK_ID

# Проверка, установлен ли уже ZeroTier
if command -v zerotier-cli &> /dev/null; then
    echo "ZeroTier уже установлен."
else
    echo "Установка ZeroTier..."
    curl -s https://install.zerotier.com | bash
fi

# Запускаем и включаем службу
systemctl enable zerotier-one
systemctl start zerotier-one

# Подключаемся к сети
echo "Подключение к сети: $NETWORK_ID"
zerotier-cli join "$NETWORK_ID"

# Ждём пару секунд для обработки
sleep 3

# Показываем статус
echo ""
echo "=== Статус подключения ZeroTier ==="
zerotier-cli status
echo ""
echo "Сеть: $NETWORK_ID"
echo "Ваш ID узла (Node ID):"
zerotier-cli info | awk '{print $3}'
echo ""
echo "Проверьте статус подключения на портале ZeroTier (https://my.zerotier.com), чтобы одобрить устройство."