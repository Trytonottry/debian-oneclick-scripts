#!/bin/bash

# Имя и заголовок
TITLE="Security Tools Installer"
BANNER="
╔════════════════════════════════════════╗
║     Security Tools for Debian 12       ║
║   Penetration Testing Setup Script     ║
╚════════════════════════════════════════╝
"

# Проверка: не запущен ли от root
if [[ $EUID -eq 0 ]]; then
   echo "❌ Этот скрипт НЕ нужно запускать от root!"
   exit 1
fi

# Функция очистки временных файлов
cleanup() {
    if [ -n "$DIALOGRC" ] && [ -f "$DIALOGRC" ]; then
        rm -f "$DIALOGRC"
    fi
}
trap cleanup EXIT

# Убедимся, что используется bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Этот скрипт нужно запускать через bash: bash install.sh"
    exit 1
fi

# Установка dialog (официальный GNU dialog)
if ! command -v dialog &> /dev/null; then
    echo "📦 Устанавливаю dialog..."
    sudo apt update
    sudo apt install -y dialog
fi

# Удаляем bsdmainutils, если мешает
if dpkg -l | grep -q "bsdmainutils"; then
    echo "⚠️  Удаляю bsdmainutils (конфликтует с dialog)"
    sudo apt remove --purge bsdmainutils -y
    sudo apt install -y dialog
fi

# Проверка версии dialog
if dialog --version 2>&1 | grep -q "BSD"; then
    echo "❌ Найден BSD dialog. Установи GNU dialog вручную:"
    echo "   sudo apt remove bsdmainutils && sudo apt install dialog"
    exit 1
fi

# Создаём временный DIALOGRC с цветами (надёжный способ)
DIALOGRC="$(mktemp)"
export DIALOGRC

# Записываем конфиг построчно — без ошибок
cat > "$DIALOGRC" << 'EOF'
[colors]
screen            = (cyan,blue,ON)
shadow            = (black,black)
dialog            = (white,black)
title             = (yellow,cyan)
border            = (white,black)
button_active     = (black,green)
button_inactive   = (white,black)
button_key_active = (white,black)
button_key_inactive = (yellow,black)
button_label_active = (white,black)
EOF

# Проверка, что файл создан
if [ ! -s "$DIALOGRC" ]; then
    echo "❌ Не удалось создать DIALOGRC"
    exit 1
fi

# Очистка экрана
clear

# Показываем баннер
dialog --colors --title "$TITLE" --msgbox "\Z4$BANNER\Z0" 12 70

# Меню выбора
TOOL_CHOICES=$(dialog --clear --colors \
    --title "\Z4$TITLE\Z0" \
    --checklist "\Z4$BANNER\Z0\n\n\Z2Выбери инструменты:\Z0" 20 75 10 \
    "basic"     "\Z2🔹 Базовые (nmap, hydra, sqlmap)\Z0" on \
    "john"      "\Z6🔓 John the Ripper\Z0" on \
    "wireshark" "\Z2📡 Wireshark\Z0" on \
    "hashcat"   "\Z1🔥 Hashcat\Z0" on \
    "burp"      "\Z4🌐 Burp Suite\Z0" on \
    "metasploit" "\Z5💥 Metasploit\Z0" on \
    "dock"      "\Z3📁 Папка в меню GNOME\Z0" on \
    3>&1 1>&2 2>&3)

# Если отмена
if [ $? -ne 0 ]; then
    dialog --msgbox "\Z1❌ Установка отменена.\Z0" 8 40
    exit 0
fi

# Преобразуем выбор
declare -A SELECTED
for tool in $TOOL_CHOICES; do
    SELECTED[$tool]=1
done

# Обновление
sudo apt update

# Установка инструментов
[[ ${SELECTED[basic]} ]] && sudo apt install -y nmap hydra sqlmap
[[ ${SELECTED[john]} ]] && sudo apt install -y john john-data
[[ ${SELECTED[wireshark]} ]] && {
    sudo apt install -y wireshark;
    sudo usermod -aG wireshark "$USER";
    echo "✅ Ты будешь в группе wireshark после перезахода."
}
[[ ${SELECTED[hashcat]} ]] && sudo apt install -y hashcat

# Burp Suite
if [[ ${SELECTED[burp]} ]]; then
    echo "🌐 Скачиваем Burp Suite..."
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
        echo "✅ Burp Suite установлен: burp"
    else
        echo "❌ Ошибка загрузки Burp Suite"
    fi
fi

# Metasploit
[[ ${SELECTED[metasploit]} ]] && {
    echo "💥 Устанавливаем Metasploit..."
    curl -s https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > /tmp/msfupdate
    if [ -s /tmp/msfupdate ]; then
        sudo chmod +x /tmp/msfupdate
        sudo mv /tmp/msfupdate /usr/local/bin/msfupdate
        sudo msfupdate
    else
        echo "❌ Ошибка загрузки Metasploit"
    fi
}

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

    update-desktop-database ~/.local/share/applications
    echo "✅ Папка 'Security Tools' добавлена в меню"
fi

# Финал
dialog --colors --title "\Z2Готово!\Z0" --msgbox "
\Z2🎉 Установка завершена!\Z0

\Z4💡 Советы:\Z0
• Перезагрузи GNOME: Alt+F2 → r → Enter
• Выйди и зайди снова для Wireshark
• Запускай: \Z3burp\Z0, \Z3msfconsole\Z0

\Z6Скрипт: github.com/ваш-ник/debian-pentest-setup\Z0
" 15 70

# Очистка
clear
echo -e "\e[32m✅ Готово! Открой меню приложений → 'Security Tools'\e[0m"