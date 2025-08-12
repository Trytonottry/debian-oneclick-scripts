#!/bin/bash
# Название: uninstall.sh
# Описание: Чистое удаление всех пентест-инструментов и меню

echo "⚠️  ВНИМАНИЕ: Это удалит все пентест-инструменты!"
read -p "Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Отменено."
    exit 1
fi

# Удаление пакетов
echo "🗑️  Удаляем пакеты..."
sudo apt remove -y nmap hydra sqlmap john wireshark hashcat

# Удаление Metasploit
if command -m msfconsole &> /dev/null; then
    echo "🧹 Удаляем Metasploit..."
    sudo /opt/metasploit-framework/bin/msfremove
fi

# Удаление Burp
if [ -d "/opt/burpsuite" ]; then
    echo "🧹 Удаляем Burp Suite..."
    sudo rm -rf /opt/burpsuite
    sudo rm -f /usr/local/bin/burp
fi

# Удаление папки в меню
if [ -d "$HOME/.local/share/applications/security-tools" ]; then
    echo "🧹 Удаляем ярлыки..."
    rm -rf "$HOME/.local/share/applications/security-tools"
    rm -f "$HOME/.local/share/applications/security-tools.directory"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

# Удаление из группы
sudo deluser "$USER" wireshark 2>/dev/null || true

# Готово
echo "✅ Удаление завершено. Система очищена."