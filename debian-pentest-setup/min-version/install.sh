#!/bin/bash

# Заголовок
TITLE="Security Tools Installer"
BANNER="
╔════════════════════════════════════════╗
║     Security Tools for Debian 12       ║
║   Penetration Testing Setup Script     ║
╚════════════════════════════════════════╝
"

# Проверка: не от root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Этот скрипт НЕ нужно запускать от root!"
   exit 1
fi

# Убедимся, что используется bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Запускай через: bash install.sh"
    exit 1
fi

# Установка dialog (GNU)
if ! command -v dialog &> /dev/null; then
    echo "📦 Устанавливаю dialog..."
    sudo apt update && sudo apt install -y dialog
fi

# Удаляем bsdmainutils, если есть
if dpkg -l | grep -q "bsdmainutils"; then
    echo "⚠️ Удаляю bsdmainutils (конфликтует с dialog)"
    sudo apt remove --purge bsdmainutils -y
    sudo apt install -y dialog
fi

# Проверка, что dialog — не BSD
if dialog --version 2>&1 | grep -qi "bsd"; then
    echo "❌ Обнаружен BSD dialog. Выполни:"
    echo "   sudo apt remove bsdmainutils"
    echo "   sudo apt install dialog"
    exit 1
fi

# Очистка
clear

# Показываем баннер (без цветов)
dialog --title "$TITLE" --msgbox "$BANNER" 12 70

# Меню выбора (без --colors, без DIALOGRC)
TOOL_CHOICES=$(dialog --clear \
    --title "$TITLE" \
    --checklist "Выбери инструменты для установки:\n\n$BANNER" 20 75 10 \
    "basic"     "🔹 Базовые (nmap, hydra, sqlmap)" on \
    "john"      "🔓 John the Ripper" on \
    "wireshark" "📡 Wireshark" on \
    "hashcat"   "🔥 Hashcat" on \
    "burp"      "🌐 Burp Suite Community" on \
    "metasploit" "💥 Metasploit Framework" on \
    "dock"      "📁 Папка в GNOME меню" on \
    3>&1 1>&2 2>&3)

# Если отмена
if [ $? -ne 0 ]; then
    dialog --msgbox "❌ Установка отменена." 8 40
    exit 0
fi

# Преобразуем выбор
declare -A SELECTED
for tool in $TOOL_CHOICES; do
    SELECTED[$tool]=1
done

# Обновление
sudo apt update

# Установка выбранных инструментов
[[ ${SELECTED[basic]} ]] && sudo apt install -y nmap hydra sqlmap
[[ ${SELECTED[john]} ]] && sudo apt install -y john john-data
[[ ${SELECTED[wireshark]} ]] && {
    sudo apt install -y wireshark
    sudo usermod -aG wireshark "$USER"
    echo "✅ Ты будешь в группе wireshark после перезахода."
}
[[ ${SELECTED[hashcat]} ]] && sudo apt install -y hashcat

# Burp Suite
if [[ ${SELECTED[burp]} ]]; then
    echo "🌐 Скачиваем Burp Suite Community..."
    BURP_DIR="/opt/burpsuite"
    sudo mkdir -p "$BURP_DIR"
    wget -qO "$BURP_DIR/burpsuite_community.jar" \
        "https://portswigger-cdn.net/burp/releases/download?product=community&version=2024.4.3&type=Linux"
    if [ -s "$BURP_DIR/burpsuite_community.jar" ]; then
        sudo tee /usr/local/bin/burp > /dev/null << 'EOF'
#!/bin/bash
java -jar /opt/burpsuite/burpsuite_community.jar
EOF
        sudo chmod +x /usr/local/bin/burp
        echo "✅ Burp Suite установлен. Запускай: burp"
    else
        echo "❌ Ошибка загрузки Burp Suite"
    fi
fi

# Metasploit
if [[ ${SELECTED[metasploit]} ]]; then
    echo "💥 Устанавливаем Metasploit Framework..."
    curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfupdate
    if [ -s /tmp/msfupdate ]; then
        sudo chmod +x /tmp/msfupdate
        sudo mv /tmp/msfupdate /usr/local/bin/msfupdate
        sudo msfupdate
    else
        echo "❌ Ошибка загрузки Metasploit"
    fi
fi

# Папка в GNOME
if [[ ${SELECTED[dock]} ]]; then
    mkdir -p ~/.local/share/applications/security-tools

    cat > ~/.local/share/applications/security-tools.directory << 'EOF'
[Desktop Entry]
Name=Security Tools
Comment=Penetration Testing Tools
Icon=applications-security
Type=Directory
EOF

    # Пример ярлыков
    cat > ~/.local/share/applications/security-tools/john.desktop << 'EOF'
[Desktop Entry]
Name=John the Ripper
Exec=gnome-terminal --title="John" -- bash -c "echo 'Usage: john hash.txt'; exec bash"
Icon=dialog-password
Terminal=true
Type=Application
Categories=SecurityTools;
EOF

    cat > ~/.local/share/applications/security-tools/nmap.desktop << 'EOF'
[Desktop Entry]
Name=Nmap
Exec=gnome-terminal --title="Nmap" -- bash -c "echo 'Usage: nmap target'; exec bash"
Icon=network-wired
Terminal=true
Type=Application
Categories=SecurityTools;
EOF

    cat > ~/.local/share/applications/security-tools/wireshark.desktop << 'EOF'
[Desktop Entry]
Name=Wireshark
Exec=wireshark
Icon=wireshark
Terminal=false
Type=Application
Categories=SecurityTools;
EOF

    update-desktop-database ~/.local/share/applications
    echo "✅ Папка 'Security Tools' добавлена в меню GNOME"
fi

# Финальное сообщение
dialog --title "Готово!" --msgbox "
🎉 Установка завершена!

💡 Советы:
• Перезагрузи GNOME: Alt+F2 → r → Enter
• Выйди и зайди снова для Wireshark
• Запускай: burp, msfconsole

Скрипт: github.com/ваш-ник/debian-pentest-setup
" 15 70

# Финиш
clear
echo "✅ Готово! Открой меню приложений → 'Security Tools'"