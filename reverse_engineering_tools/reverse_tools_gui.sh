#!/bin/bash

# Проверка zenity
if ! command -v zenity &> /dev/null; then
    echo "Установите zenity: sudo apt install zenity"
    exit 1
fi

# Проверка sudo
if ! sudo -v &> /dev/null; then
    zenity --error --text="Требуются права sudo. Запустите от имени пользователя с sudo."
    exit 1
fi

# Выбор инструментов
TOOLS=$(zenity --list --checklist \
    --title="Выбор инструментов" \
    --text="Выберите, что установить:" \
    --column="Выбрать" --column="Инструмент" --column="Описание" \
    TRUE "jadx" "Декомпилятор APK (GUI + CLI)" \
    TRUE "apktool" "APK: ресурсы и smali" \
    TRUE "dex2jar" "Конвертация .dex → .jar" \
    TRUE "radare2" "Дисассемблер (консоль)" \
    TRUE "ghidra" "Мощный дисассемблер от NSA" \
    TRUE "frida" "Frida + Objection (динамический анализ)" \
    TRUE "mobsf" "Mobile Security Framework (веб)" \
    --separator=" " || exit)

if [ -z "$TOOLS" ]; then
    zenity --info --text="Ничего не выбрано. Выход."
    exit 0
fi

# Настройка папки
TOOLS_DIR="$HOME/tools"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR" || exit

# Прогресс-бар
(
    echo "10"
    sleep 1

    for tool in $TOOLS; do
        case $tool in
            "jadx")
                zenity --info --text="Устанавливаем JADX..." --timeout=1 --no-wrap &
                wget -q --show-progress -O jadx.zip "https://github.com/skylot/jadx/releases/download/v1.5.0/jadx-1.5.0.zip"
                unzip -q jadx.zip && rm jadx.zip
                sudo mv jadx /opt/jadx
                sudo ln -sf /opt/jadx/bin/jadx /usr/local/bin/jadx
                sudo ln -sf /opt/jadx/bin/jadx-gui /usr/local/bin/jadx-gui
                # .desktop
                cat > ~/.local/share/applications/jadx.desktop <<EOL
[Desktop Entry]
Name=JADX-GUI
Exec=/opt/jadx/bin/jadx-gui
Icon=/opt/jadx/bin/jadx-gui.png
Terminal=false
Type=Application
Categories=Development;ReverseEngineering;
EOL
                wget -O /opt/jadx/bin/jadx-gui.png "https://raw.githubusercontent.com/skylot/jadx/master/jadx-gui/src/main/icons/jadx-gui.png"
                echo "$(( $(echo $TOOLS | wc -w) * 10 ))"
                ;;

            "apktool")
                zenity --info --text="Устанавливаем APKTool..." --timeout=1 --no-wrap &
                wget -O apktool.jar "https://bitbucket.org/iBotPeaches/apktool/downloads/apktool-2.9.3.jar"
                sudo cp apktool.jar /usr/local/bin/apktool.jar
                echo '#!/bin/bash' | sudo tee /usr/local/bin/apktool > /dev/null
                echo 'java -jar /usr/local/bin/apktool.jar "$@"' | sudo tee -a /usr/local/bin/apktool > /dev/null
                sudo chmod +x /usr/local/bin/apktool
                echo "$(( $(echo $TOOLS | wc -w) * 20 ))"
                ;;

            "dex2jar")
                zenity --info --text="Устанавливаем dex2jar..." --timeout=1 --no-wrap &
                git clone --depth 1 https://github.com/pxb1988/dex2jar.git
                chmod +x dex2jar/*.sh
                sudo ln -sf "$PWD/dex2jar/d2j-dex2jar.sh" /usr/local/bin/dex2jar
                echo "$(( $(echo $TOOLS | wc -w) * 30 ))"
                ;;

            "radare2")
                zenity --info --text="Устанавливаем radare2..." --timeout=1 --no-wrap &
                sudo apt install -y radare2
                echo "$(( $(echo $TOOLS | wc -w) * 40 ))"
                ;;

            "ghidra")
                zenity --info --text="Устанавливаем Ghidra..." --timeout=1 --no-wrap &
                wget -O ghidra.zip "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_11.0_build/ghidra_11.0_PUBLIC_20230614.zip"
                7z x ghidra.zip && rm ghidra.zip
                mv ghidra_* ghidra
                sudo mv ghidra /opt/
                sudo ln -sf /opt/ghidra/ghidraRun /usr/local/bin/ghidra
                echo "$(( $(echo $TOOLS | wc -w) * 50 ))"
                ;;

            "frida")
                zenity --info --text="Устанавливаем Frida и Objection..." --timeout=1 --no-wrap &
                pip3 install frida-tools objection
                echo "$(( $(echo $TOOLS | wc -w) * 60 ))"
                ;;

            "mobsf")
                zenity --info --text="Устанавливаем MobSF..." --timeout=1 --no-wrap &
                git clone --depth 1 https://github.com/MobSF/Mobile-Security-Framework-MobSF.git
                cd Mobile-Security-Framework-MobSF || exit
                ./setup.sh
                cd ..
                echo "$(( $(echo $TOOLS | wc -w) * 70 ))"
                ;;
        esac
    done

    echo "100"
    sleep 2
    zenity --info --text="Установка завершена!\nИнструменты доступны в ~/tools и через командную строку."
) | zenity --progress --title="Установка инструментов" --auto-close --auto-kill --text="Идёт установка..."
