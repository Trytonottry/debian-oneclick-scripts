#!/bin/bash
# export_gerbers.sh
# Автоматически экспортирует Gerber-файлы из KiCad проекта

set -euo pipefail

# Настройки
PROJECT_NAME="ai-os-carrier"
KICAD_PROJECT_DIR="./$PROJECT_NAME/kicad"
PCB_FILE="$KICAD_PROJECT_DIR/$PROJECT_NAME.kicad_pcb"
GERBER_DIR="$KICAD_PROJECT_DIR/gerbers"
DATE=$(date +%Y%m%d)
ZIP_NAME="$PROJECT_NAME-gerber-$DATE.zip"

# Проверка наличия файла
if [ ! -f "$PCB_FILE" ]; then
    echo "❌ Ошибка: Файл платы не найден: $PCB_FILE"
    echo "Убедитесь, что проект сохранён и файл существует."
    exit 1
fi

echo "🚀 Экспорт Gerber для: $PROJECT_NAME"
echo "📄 Плата: $PCB_FILE"

# 1. Создаём папку для Gerber
mkdir -p "$GERBER_DIR"
rm -rf "$GERBER_DIR"/*  # Очистка старых файлов
echo "📁 Папка для Gerber: $GERBER_DIR"

# 2. Экспорт Gerber через командную строку KiCad (kicad-cli)
#    (Требуется KiCad 7+)
if ! command -v kicad-cli &> /dev/null; then
    echo "❌ kicad-cli не найден. Установите KiCad 7+"
    echo "Или экспортируйте вручную через GUI: File → Plot"
    exit 1
fi

echo "🔧 Экспортируем Gerber-файлы..."

kicad-cli pcb export gerbers \
    --output "$GERBER_DIR" \
    --layers "F.Cu,B.Cu,F.SilkS,B.SilkS,F.Mask,B.Mask,Edge.Cuts" \
    --subtract-soldermask \
    --exclude-edge-layer \
    --use-drill-origin \
    --precision 6 \
    --skip-artifacts \
    "$PCB_FILE"

# 3. Экспорт сверловки (Drill)
echo "🔧 Экспортируем файл сверловки..."

kicad-cli pcb export drill \
    --output "$GERBER_DIR" \
    --format excellect \
    --drill-origin \
    --excellon-zeros-format suppressleading \
    --excellon-units mm \
    --generate-map \
    --map-format pdf \
    "$PCB_FILE"

# 4. Дополнительно: зеркальный Gerber для F.Cu (для тонер-трансфера)
echo "🔧 Создаём зеркальный Gerber для тонер-трансфера..."

# Копируем F.Cu и зеркально отражаем
cp "$GERBER_DIR/${PROJECT_NAME}-F_Cu.gbr" "$GERBER_DIR/${PROJECT_NAME}-F_Cu_Mirror.gbr"
# Зеркалирование делается вручную при печати, но можно добавить в имя

# 5. Переименовываем для ясности
mv "$GERBER_DIR/${PROJECT_NAME}-B_Cu.gbr" "$GERBER_DIR/${PROJECT_NAME}-Back_Copper.gbr" 2>/dev/null || true
mv "$GERBER_DIR/${PROJECT_NAME}-F_Cu.gbr" "$GERBER_DIR/${PROJECT_NAME}-Front_Copper.gbr" 2>/dev/null || true
mv "$GERBER_DIR/${PROJECT_NAME}-Edge_Cuts.gbr" "$GERBER_DIR/${PROJECT_NAME}-Outline.gbr" 2>/dev/null || true

# 6. Генерируем сводку
cat > "$GERBER_DIR/README.txt" << EOF
Gerber-файлы для $PROJECT_NAME
Дата: $DATE

Слои:
- Front_Copper.gbr       — Верхний слой (Top Copper)
- Back_Copper.gbr        — Нижний слой (Bottom Copper)
- Front_Silkscreen.gbr   — Верхняя шелкография
- Back_Silkscreen.gbr    — Нижняя шелкография
- Soldermask_Top.gbr     — Верхняя паяльная маска
- Soldermask_Bottom.gbr  — Нижняя паяльная маска
- Outline.gbr            — Контур платы
- ${PROJECT_NAME}.drl      — Файл сверловки (Excellon)

Для ручного изготовления:
1. Распечатайте Front_Copper.gbr на глянцевой бумаге
2. Перенесите тонер на медную плату (утюг)
3. Протравите в FeCl₃ или H₂O₂ + лимонная кислота
4. Просверлите отверстия
EOF

# 7. Архивируем
cd "$GERBER_DIR"
zip -r "../$ZIP_NAME" ./*
cd - > /dev/null

# 8. Готово
echo "✅ Gerber-файлы экспортированы:"
ls -la "$GERBER_DIR"
echo ""
echo "📦 Архив создан: ./$ZIP_NAME"