#!/bin/bash

echo "🚀 Установка инструментов для реверс-инжиниринга на Debian"
echo "Требуются права sudo. Скрипт установит: JADX, APKTool, dex2jar, Ghidra, radare2, Frida, Objection, MobSF"
read -p "Продолжить? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Проверка на Debian/Ubuntu
if ! grep -qi debian /etc/os-release && ! grep -qi ubuntu /etc/os-release; then
    echo "⚠️  Этот скрипт предназначен для Debian/Ubuntu."
    exit 1
fi

# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка базовых зависимостей
sudo apt install -y \
    openjdk-17-jre \
    openjdk-17-jdk \
    wget \
    unzip \
    git \
    p7zip-full \
    python3-pip \
    adb \
    curl

# Создаём папку для инструментов
mkdir -p ~/tools
cd ~/tools || exit

# --------------------------------------------
# 1. Установка JADX
# --------------------------------------------
echo "📦 Установка JADX..."
JADX_VERSION="1.5.0"
wget -O jadx.zip "https://github.com/skylot/jadx/releases/download/v${JADX_VERSION}/jadx-${JADX_VERSION}.zip"
unzip -q jadx.zip && rm jadx.zip
sudo mv jadx /opt/jadx

# Символические ссылки
sudo ln -sf /opt/jadx/bin/jadx /usr/local/bin/jadx
sudo ln -sf /opt/jadx/bin/jadx-gui /usr/local/bin/jadx-gui

# Создаём .desktop файл
cat > ~/.local/share/applications/jadx.desktop <<EOL
[Desktop Entry]
Name=JADX-GUI
Comment=Decompile Android APK files
Exec=/opt/jadx/bin/jadx-gui
Icon=/opt/jadx/bin/jadx-gui.png
Terminal=false
Type=Application
Categories=Development;IDE;ReverseEngineering;
MimeType=application/vnd.android.package-archive;
StartupNotify=true
EOL

# Иконка
wget -O /opt/jadx/bin/jadx-gui.png "https://raw.githubusercontent.com/skylot/jadx/master/jadx-gui/src/main/icons/jadx-gui.png"

chmod +x ~/.local/share/applications/jadx.desktop
echo "✅ JADX установлен. Доступен как jadx и jadx-gui."

# --------------------------------------------
# 2. Установка APKTool
# --------------------------------------------
echo "📦 Установка APKTool..."
APKTOOL_VERSION="2.9.3"
wget -O apktool.jar "https://bitbucket.org/iBotPeaches/apktool/downloads/apktool-${APKTOOL_VERSION}.jar"
sudo cp apktool.jar /usr/local/bin/apktool.jar

cat > /tmp/apktool <<'EOL'
#!/bin/bash
java -jar /usr/local/bin/apktool.jar "$@"
EOL

sudo cp /tmp/apktool /usr/local/bin/apktool
sudo chmod +x /usr/local/bin/apktool
echo "✅ APKTool установлен: apktool"

# --------------------------------------------
# 3. Установка dex2jar
# --------------------------------------------
echo "📦 Установка dex2jar..."
git clone --depth 1 https://github.com/pxb1988/dex2jar.git
cd dex2jar || exit
chmod +x *.sh
cd ..
sudo ln -sf "$PWD/dex2jar/d2j-dex2jar.sh" /usr/local/bin/dex2jar
echo "✅ dex2jar установлен: d2j-dex2jar.sh"

# --------------------------------------------
# 4. Установка radare2
# --------------------------------------------
echo "📦 Установка radare2..."
sudo apt install -y radare2
echo "✅ radare2 установлен: r2"

# --------------------------------------------
# 5. Установка Ghidra
# --------------------------------------------
echo "📦 Установка Ghidra..."
GHIDRA_VERSION="11.0"
wget -O ghidra.zip "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_20230614.zip"
7z x ghidra.zip && rm ghidra.zip
mv ghidra_* ghidra
sudo mv ghidra /opt/
sudo ln -sf /opt/ghidra/ghidraRun /usr/local/bin/ghidra
echo "✅ Ghidra установлен: ghidra"

# --------------------------------------------
# 6. Установка Frida и Objection
# --------------------------------------------
echo "📦 Установка Frida и Objection..."
pip3 install frida-tools objection
echo "✅ Frida и Objection установлены: frida-trace, objection"

# --------------------------------------------
# 7. Установка MobSF
# --------------------------------------------
echo "📦 Установка Mobile Security Framework (MobSF)..."
git clone --depth 1 https://github.com/MobSF/Mobile-Security-Framework-MobSF.git
cd Mobile-Security-Framework-MobSF || exit
./setup.sh
cd ..
echo "✅ MobSF установлен. Запуск: ~/tools/Mobile-Security-Framework-MobSF/run.sh"

# --------------------------------------------
# Финал
# --------------------------------------------
echo "--------------------------------------------------"
echo "🎉 Установка завершена!"
echo "--------------------------------------------------"
echo "Доступные команды:"
echo "  jadx-gui        — графический декомпилятор"
echo "  jadx            — консольный декомпилятор"
echo "  apktool         — работа с ресурсами APK"
echo "  dex2jar         — конвертация .dex в .jar"
echo "  r2              — анализ бинарников"
echo "  ghidra          — мощный дисассемблер"
echo "  frida-trace     — динамический анализ"
echo "  objection       — обход защиты в рантайме"
echo "  MobSF: запуск через ~/tools/Mobile-Security-Framework-MobSF/run.sh"
echo ""
echo "JADX добавлен в меню приложений."
echo "--------------------------------------------------"