#!/bin/bash

echo "🚀 Запуск среды реверс-инжиниринга"
echo "Доступные команды: jadx, jadx-gui, apktool, r2, ghidra, frida-trace, objection"
echo "MobSF запускается автоматически на порту 8000"

# Запуск MobSF в фоне
cd /home/tools/Mobile-Security-Framework-MobSF || exit
python3 manage.py runserver 0.0.0.0:8000 &

# Если аргумент — запускаем его
if [ $# -gt 0 ]; then
    exec "$@"
else
    # Иначе — интерактивный режим
    echo "Запущен интерактивный режим. MobSF: http://localhost:8000"
    exec /bin/bash
fi