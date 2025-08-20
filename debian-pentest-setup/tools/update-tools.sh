#!/bin/bash
# Название: update-tools.sh
# Описание: Обновление всех пентест-инструментов

echo "🔄 Обновление пентест-инструментов..."

# Обновление пакетов
echo "📦 Обновление через apt..."
sudo apt update
sudo apt upgrade -y nmap hydra sqlmap john wireshark hashcat

# Обновление Metasploit
if command -v msfupdate &> /dev/null; then
    echo "🔁 Обновляем Metasploit..."
    sudo msfupdate
fi

# Обновление Burp Suite
if command -v burp &> /dev/null; then
    echo "🌐 Проверяем Burp Suite..."
    BURP_NEW="/tmp/burpsuite_new.jar"
    wget -qO "$BURP_NEW" "https://portswigger-cdn.net/burp/releases/download?product=community&version=latest&type=Linux"
    if [ -s "$BURP_NEW" ]; then
        SIZE_NEW=$(stat -c%s "$BURP_NEW")
        SIZE_CUR=$(stat -c%s "/opt/burpsuite/burpsuite_community.jar" 2>/dev/null || echo 0)
        if [ $SIZE_NEW -ne $SIZE_CUR ]; then
            echo "📥 Обновляем Burp Suite..."
            sudo mv "$BURP_NEW" /opt/burpsuite/burpsuite_community.jar
            echo "✅ Burp Suite обновлён"
        else
            echo "✅ Burp Suite уже актуален"
            rm "$BURP_NEW"
        fi
    else
        echo "❌ Не удалось скачать обновление Burp"
    fi
fi

# Проверка системы
echo "✅ Все инструменты обновлены."