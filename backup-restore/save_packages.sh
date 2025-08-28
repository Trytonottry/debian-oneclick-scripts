#!/bin/bash

# Имя выходного файла
OUTPUT_FILE="$HOME/installed_packages.txt"

# Очистка предыдущего файла (если существует)
> "$OUTPUT_FILE"

echo "Собираем список установленных пакетов..."
echo "Создано: $(date)" >> "$OUTPUT_FILE"
echo "========================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# === APT / DPKG ===
echo "=== APT (dpkg) ===" >> "$OUTPUT_FILE"
dpkg --get-selections | grep -v 'deinstall' | awk '{print $1}' >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# === FLATPAK ===
if command -v flatpak &> /dev/null; then
    echo "=== FLATPAK ===" >> "$OUTPUT_FILE"
    flatpak list --app --columns=application | tail -n +2 >> "$OUTPUT_FILE" 2>/dev/null || echo "Нет установленных flatpak-приложений." >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
else
    echo "FLATPAK не установлен. Пропускаем." | tee -a "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

# === SNAP ===
if command -v snap &> /dev/null; then
    echo "=== SNAP ===" >> "$OUTPUT_FILE"
    snap list | awk 'NR>1 {print $1}' >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
else
    echo "SNAP не установлен. Пропускаем." | tee -a "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
fi

echo "Готово! Список пакетов сохранён в: $OUTPUT_FILE"