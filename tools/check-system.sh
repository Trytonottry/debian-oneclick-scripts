#!/bin/bash
echo "🔍 Проверка системы..."

if [ "$(lsb_release -is)" != "Debian" ]; then
    echo "❌ Не Debian"
    exit 1
fi

if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ] && [ "$XDG_CURRENT_DESKTOP" != "ubuntu:GNOME" ]; then
    echo "⚠️  Не GNOME. Папка в меню может не отобразиться."
fi

echo "✅ Система поддерживается"