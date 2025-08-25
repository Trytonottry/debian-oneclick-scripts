# 🛠️ Reverse Engineering Toolkit for Debian

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Debian%2011%7C12-blue)](https://www.debian.org)
[![Docker](https://img.shields.io/badge/container-Docker-blue)](https://www.docker.com)
[![Shell Script](https://img.shields.io/badge/script-Bash-green)](https://www.gnu.org/software/bash/)
[![Android](https://img.shields.io/badge/target-Android%20APK-green)](https://developer.android.com)

Универсальный набор инструментов для **реверс-инжиниринга Android-приложений** на Debian. Включает автоматизированные скрипты установки и Docker-образ с полной средой анализа.

---

## 🚀 Возможности

- ✅ Установка 8+ инструментов за один клик
- 🖼️ GUI-интерфейс через `zenity`
- 🐳 Полноценный Docker-образ с веб-интерфейсом
- 🔐 Безопасный анализ в изолированной среде
- 📦 Поддержка JADX, APKTool, Ghidra, Frida, MobSF и других

---

## 📦 Установленные инструменты

| Инструмент       | Назначение |
|------------------|-----------|
| **JADX-GUI**     | Декомпиляция APK → Java |
| **APKTool**      | Работа с `AndroidManifest`, ресурсами, smali |
| **dex2jar**      | Конвертация `.dex` → `.jar` |
| **radare2**      | Анализ бинарников (консольный дисассемблер) |
| **Ghidra**       | Мощный дисассемблер от NSA |
| **Frida**        | Динамический анализ и хуки |
| **Objection**    | Обход SSL-Pinning, рут-детекта |
| **MobSF**        | Автоматизированный аудит безопасности |

---

## 💻 Требования (локальная установка)

- Debian 11/12 или Ubuntu 20.04+
- `sudo` права
- Java 17 (`openjdk-17-jre`)
- ~2 ГБ свободного места

---

## 🖥️ GUI-скрипт (на базе Zenity)

### Установка

```bash
sudo apt install zenity -y
wget https://raw.githubusercontent.com/Trytonottry/debian-pentest-tools/reverse-tools/main/reverse_tools_gui.sh
chmod +x reverse_tools_gui.sh
./reverse_tools_gui.sh
```

Скрипт предложит выбрать нужные инструменты и установит их в ~/tools.

## 🐳 Docker-образ (рекомендуется) 
Сборка образа 
```bash
git clone https://github.com/Trytonottry/debian-pentest-setup/reverse-tools.git
cd reverse-tools
docker build -t reverse-box .
```
 
Запуск веб-интерфейса (MobSF) 
```bash
docker run -d -p 8000:8000 --name reverse reverse-box
```
 

Открой в браузере: http://localhost:8000  
Запуск JADX-GUI (с GUI) 
```bash
xhost +local:docker
docker run -it --rm \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v ./apks:/home/tools/apks \
  reverse-box jadx-gui
```
 

    🔹 На Windows: используй VcXsrv 
    🔹 На macOS: используй XQuartz  
     

Использование docker-compose 
```bash
docker-compose up -d
```
 
 
##🧪 Примеры использования 
```bash
 Декомпиляция APK
jadx-gui app.apk

 Анализ ресурсов
apktool d app.apk

 Запуск динамического анализа
objection -g com.example.app explore

 Анализ бинарника
r2 libnative.so
```
 
 
##📁 Структура проекта 

reverse-tools/
├── reverse_tools_gui.sh    # GUI-установщик
├── Dockerfile              # Docker-образ
├── start.sh                # Скрипт запуска в контейнере
├── docker-compose.yml      # Удобный запуск MobSF
└── README.md               # Этот файл
 
 
 
##📎 Лицензия 

MIT — свободно используй, модифицируй и распространяй.
См. файл LICENSE. 
 
##🤝 Автор 

Создано для сообщества реверс-инжиниров.
Вклад приветствуется! 

    📬 Связь: popovsemyona@gmail.com
    💬 Темы: Android RE, безопасность, автоматизация 