#!/bin/bash

# Скрипт для обновления Debian 12 (Bookworm) → Debian 13 (Trixie) [testing]
# Внимание: Trixie — это testing, не стабильная версия!
# Автор: безопасное обновление с бэкапом и подтверждением

set -euo pipefail

echo "⚠️ ВНИМАНИЕ: Этот скрипт обновит Debian 12 (Bookworm) до Debian 13 (Trixie)"
echo "Trixie — это ветка 'testing', что может привести к нестабильности."
echo "Рекомендуется использовать только в тестовых средах."
echo

read -p "Продолжить? (да/нет): " -r
echo
if [[ ! "$REPLY" =~ ^[ДдYy][АаEe][Аа]$ ]]; then
    echo "❌ Отменено пользователем."
    exit 1
fi

# Проверка, что система — Debian 12
if ! grep -q "bookworm" /etc/os-release 2>/dev/null; then
    echo "❌ Этот скрипт предназначен только для Debian 12 (bookworm)."
    echo "Текущая ОС:"
    cat /etc/os-release | grep "PRETTY_NAME"
    exit 1
fi

# Обновление текущей системы
echo "🔄 Обновляем текущую систему (Debian 12)..."
apt update && apt upgrade -y && apt full-upgrade -y
apt autoremove -y

# Создание резервной копии sources.list
echo "📁 Создаём резервную копию /etc/apt/sources.list..."
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak-$(date +%F_%H-%M)

# Обновление sources.list до trixie (testing)
echo "🔧 Меняем репозитории на Debian 13 (trixie)..."
cat << 'EOF' | sudo tee /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security/ trixie-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
EOF

# Обновление списка пакетов
echo "🔄 Обновляем список пакетов для trixie..."
apt update

# Обновление системы до trixie
echo "🚀 Начинаем обновление до Debian 13 (trixie)..."
apt full-upgrade -y

# Удаление ненужных пакетов
apt autoremove -y

# Завершение
echo
echo "✅ Готово! Система обновлена до Debian 13 (trixie)."
echo "❗ ВНИМАНИЕ: Это ветка 'testing', система может быть нестабильной."
echo "Рекомендуется перезагрузка:"
echo "  sudo reboot"
echo
echo "📄 Бэкап старого sources.list: /etc/apt/sources.list.bak-*"

# Проверка версии
echo
cat /etc/os-release | grep "PRETTY_NAME"