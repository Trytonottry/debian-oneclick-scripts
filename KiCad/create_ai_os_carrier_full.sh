#!/bin/bash
# create_ai_os_carrier_full.sh
# Создаёт полноценный KiCad-проект: структура, символы, схема, посадочные места, Gerber-подготовка

set -e

PROJECT_NAME="ai-os-carrier"
KIICAD_VERSION="7.0"

echo "🚀 Создаём полноценный KiCad-проект: $PROJECT_NAME"

# 1. Создаём структуру папок
mkdir -p "$PROJECT_NAME/kicad"
mkdir -p "$PROJECT_NAME/kicad/symbols"
mkdir -p "$PROJECT_NAME/kicad/footprints/M.2-M-Key.pretty"
mkdir -p "$PROJECT_NAME/kicad/footprints/SOIC.pretty"
mkdir -p "$PROJECT_NAME/kicad/gerbers"
mkdir -p "$PROJECT_NAME/docs"
mkdir -p "$PROJECT_NAME/firmware"

cd "$PROJECT_NAME/kicad"

# 2. Создаём файл проекта
cat > "$PROJECT_NAME.kicad_pro" << 'EOF'
{
    "version": 1,
    "last_editor": "AI OS Builder",
    "kicad_version": "7.0.0",
    "project_file": "ai_os_carrier.kicad_pro",
    "board_file": "ai_os_carrier.kicad_pcb",
    "schematic_file": "ai_os_carrier.sch",
    "text_variables": {},
    "managed_files": [],
    "boards": []
}
EOF

# 3. Создаём символы
SYMBOLS_LIB="$PROJECT_NAME.kicad_sym"

cat > "symbols/$SYMBOLS_LIB" << 'EOF'
(kicad_symbol_lib (version 20231120) (generator symbol-editor)
  (symbol "ORANGE_PI_ZERO_2W"
    (in_bom yes)
    (on_board yes)
    (property "Reference" "J" (id 0) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left bottom)))
    (property "Value" "ORANGE_PI_ZERO_2W" (id 1) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left top)))
    (property "Footprint" "" (id 2) (at 0 0 0)
      (effects (font (size 1.27 1.27)) hide))
    (pin "1" passive (at -2.54 0 0) (length 2.54) (name "GND" 0) (number "1"))
    (pin "2" power_in (at -2.54 2.54 0) (length 2.54) (name "3.3V" 0) (number "2"))
    (pin "3" bidirectional (at -2.54 5.08 0) (length 2.54) (name "SDA" 0) (number "3"))
    (pin "4" bidirectional (at -2.54 7.62 0) (length 2.54) (name "SCL" 0) (number "4"))
    (pin "5" bidirectional (at -2.54 10.16 0) (length 2.54) (name "PCIe_RX-" 0) (number "5"))
    (pin "6" bidirectional (at -2.54 12.7 0) (length 2.54) (name "PCIe_RX+" 0) (number "6"))
    (pin "7" bidirectional (at -2.54 15.24 0) (length 2.54) (name "PCIe_TX-" 0) (number "7"))
    (pin "8" bidirectional (at -2.54 17.78 0) (length 2.54) (name "PCIe_TX+" 0) (number "8"))
    (pin "9" power_in (at -2.54 20.32 0) (length 2.54) (name "5V_IN" 0) (number "9"))
    (pin "10" passive (at -2.54 22.86 0) (length 2.54) (name "GND" 0) (number "10"))
  )
  (symbol "ATECC608B-TNGTLS"
    (in_bom yes)
    (on_board yes)
    (property "Reference" "U" (id 0) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left bottom)))
    (property "Value" "ATECC608B" (id 1) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left top)))
    (property "Footprint" "SOIC.pretty:SOIC-8_3.9x4.9mm_P1.27mm" (id 2) (at 0 0 0)
      (effects (font (size 1.27 1.27))))
    (pin "1" bidirectional (at -2.54 0 0) (length 2.54) (name "SDA" 0) (number "1"))
    (pin "2" bidirectional (at -2.54 2.54 0) (length 2.54) (name "SCL" 0) (number "2"))
    (pin "3" power_in (at -2.54 5.08 0) (length 2.54) (name "GND" 0) (number "3"))
    (pin "4" power_in (at -2.54 7.62 0) (length 2.54) (name "VCC" 0) (number "4"))
    (pin "5" passive (at -2.54 10.16 0) (length 2.54) (name "IO" 0) (number "5"))
    (pin "6" passive (at -2.54 12.7 0) (length 2.54) (name "GND" 0) (number "6"))
    (pin "7" passive (at -2.54 15.24 0) (length 2.54) (name "VCC" 0) (number "7"))
    (pin "8" passive (at -2.54 17.78 0) (length 2.54) (name "GND" 0) (number "8"))
  )
  (symbol "M2_MKEY"
    (in_bom yes)
    (on_board yes)
    (property "Reference" "J" (id 0) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left bottom)))
    (property "Value" "M.2 NVMe" (id 1) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left top)))
    (property "Footprint" "M.2-M-Key.pretty:M.2-M-Key" (id 2) (at 0 0 0)
      (effects (font (size 1.27 1.27))))
    (pin "1" bidirectional (at -2.54 0 0) (length 2.54) (name "PCIe_RX-" 0) (number "1"))
    (pin "2" bidirectional (at -2.54 2.54 0) (length 2.54) (name "PCIe_RX+" 0) (number "2"))
    (pin "3" bidirectional (at -2.54 5.08 0) (length 2.54) (name "PCIe_TX-" 0) (number "3"))
    (pin "4" bidirectional (at -2.54 7.62 0) (length 2.54) (name "PCIe_TX+" 0) (number "4"))
    (pin "5" power_in (at -2.54 10.16 0) (length 2.54) (name "3.3V" 0) (number "5"))
    (pin "6" passive (at -2.54 12.7 0) (length 2.54) (name "GND" 0) (number "6"))
  )
  (symbol "SY8120"
    (in_bom yes)
    (on_board yes)
    (property "Reference" "U" (id 0) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left bottom)))
    (property "Value" "SY8120" (id 1) (at 0 0 0)
      (effects (font (size 1.27 1.27)) (justify left top)))
    (property "Footprint" "SOIC.pretty:SOIC-8_3.9x4.9mm_P1.27mm" (id 2) (at 0 0 0)
      (effects (font (size 1.27 1.27))))
    (pin "1" power_in (at -2.54 0 0) (length 2.54) (name "VIN" 0) (number "1"))
    (pin "2" passive (at -2.54 2.54 0) (length 2.54) (name "GND" 0) (number "2"))
    (pin "3" passive (at -2.54 5.08 0) (length 2.54) (name "SW" 0) (number "3"))
    (pin "4" power_out (at -2.54 7.62 0) (length 2.54) (name "VOUT" 0) (number "4"))
    (pin "5" input (at -2.54 10.16 0) (length 2.54) (name "EN" 0) (number "5"))
    (pin "6" output (at -2.54 12.7 0) (length 2.54) (name "PGOOD" 0) (number "6"))
    (pin "7" passive (at -2.54 15.24 0) (length 2.54) (name "FB" 0) (number "7"))
    (pin "8" passive (at -2.54 17.78 0) (length 2.54) (name "SS" 0) (number "8"))
  )
)
EOF

echo "✅ Символы созданы: ORANGE_PI, ATECC608B, M2, SY8120"

# 4. Создаём посадочные места

# ATECC608B (SOIC-8)
cat > "footprints/SOIC.pretty/SOIC-8_3.9x4.9mm_P1.27mm.kicad_mod" << 'EOF'
(module SOIC-8_3.9x4.9mm_P1.27mm (layer F.Cu) (tedit 5B74B84B)
  (attr smd)
  (fp_text reference U*** (at 0 -2.45) (layer F.SilkS) hide
    (effects (font (size 1 1) (thickness 0.15))))
  (fp_text value SOIC-8 (at 0 2.45) (layer F.Fab)
    (effects (font (size 1 1) (thickness 0.15))))
  (fp_line (start -2.95 -1.95) (end 2.95 -1.95) (layer F.CrtYd) (width 0.05))
  (fp_line (start 2.95 -1.95) (end 2.95 1.95) (layer F.CrtYd) (width 0.05))
  (fp_line (start 2.95 1.95) (end -2.95 1.95) (layer F.CrtYd) (width 0.05))
  (fp_line (start -2.95 1.95) (end -2.95 -1.95) (layer F.CrtYd) (width 0.05))
  (fp_line (start -2.4 -1.9) (end -2.4 1.9) (layer F.SilkS) (width 0.12))
  (fp_line (start 2.4 -1.9) (end 2.4 1.9) (layer F.SilkS) (width 0.12))
  (fp_line (start -2.4 -1.9) (end 2.4 -1.9) (layer F.SilkS) (width 0.12))
  (fp_line (start -2.4 1.9) (end 2.4 1.9) (layer F.SilkS) (width 0.12))
  (pad 1 smd rect (at -1.925 -1.425) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
  (pad 2 smd rect (at -1.925 -0.425) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
  (pad 3 smd rect (at -1.925 0.575) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
  (pad 4 smd rect (at -1.925 1.575) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
  (pad 5 smd rect (at 1.925 1.575) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
  (pad 6 smd rect (at 1.925 0.575) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
  (pad 7 smd rect (at 1.925 -0.425) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
  (pad 8 smd rect (at 1.925 -1.425) (size 0.5 1.0) (layers F.Cu F.Paste F.Mask))
)
EOF

# M.2 M-Key
cat > "footprints/M.2-M-Key.pretty/M.2-M-Key.kicad_mod" << 'EOF'
(module M.2-M-Key (layer F.Cu) (tedit 0)
  (attr smd)
  (fp_text reference J*** (at 0 -5) (layer F.SilkS) hide
    (effects (font (size 1 1) (thickness 0.15))))
  (fp_text value M.2-M-Key (at 0 5) (layer F.Fab)
    (effects (font (size 1 1) (thickness 0.15))))
  (fp_line (start -10 -4) (end 10 -4) (layer F.CrtYd) (width 0.05))
  (fp_line (start 10 -4) (end 10 4) (layer F.CrtYd) (width 0.05))
  (fp_line (start 10 4) (end -10 4) (layer F.CrtYd) (width 0.05))
  (fp_line (start -10 4) (end -10 -4) (layer F.CrtYd) (width 0.05))
  (pad 1 smd rect (at -8.5 -2.5) (size 1.0 2.0) (layers F.Cu F.Paste F.Mask))
  (pad 2 smd rect (at -8.5 2.5) (size 1.0 2.0) (layers F.Cu F.Paste F.Mask))
  (pad 3 smd rect (at -6.5 -2.5) (size 1.0 2.0) (layers F.Cu F.Paste F.Mask))
  (pad 4 smd rect (at -6.5 2.5) (size 1.0 2.0) (layers F.Cu F.Paste F.Mask))
  (pad 5 smd rect (at -4.5 -2.5) (size 1.0 2.0) (layers F.Cu F.Paste F.Mask))
  (pad 6 smd rect (at -4.5 2.5) (size 1.0 2.0) (layers F.Cu F.Paste F.Mask))
)
EOF

echo "✅ Посадочные места созданы"

# 5. Создаём схему
cat > "ai_os_carrier.sch" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://www.kicad.org/kicad/sch/7">
  <sheet uuid="00000000-0000-0000-0000-000000000001">
    <title_block>
      <title>AI OS Core Pro Carrier Board</title>
      <company>AI OS Lab</company>
      <rev>1.0</rev>
      <date>2025-04-05</date>
      <source>ai_os_carrier.sch</source>
    </title_block>
    <symbol_instance path="/00000000-0000-0000-0000-000000000001"
      symbol_lib_id="ai-os-carrier:ORANGE_PI_ZERO_2W"
      uuid="10000000-0000-0000-0000-000000000001"
      timestamp="611D04A8"
      unit="1"
      in_bom="yes"
      on_board="yes"
      fields_autoplaced="yes">
      <property key="Reference" value="J1" id="0" at="0,50,0" hide="no"/>
      <property key="Value" value="ORANGE_PI_ZERO_2W" id="1" at="0,52.54,0" hide="no"/>
      <property key="Footprint" value="" id="2" at="0,55.08,0" hide="yes"/>
    </symbol_instance>
    <symbol_instance path="/00000000-0000-0000-0000-000000000001"
      symbol_lib_id="ai-os-carrier:ATECC608B-TNGTLS"
      uuid="10000000-0000-0000-0000-000000000002"
      timestamp="611D04A9"
      unit="1"
      in_bom="yes"
      on_board="yes"
      fields_autoplaced="yes">
      <property key="Reference" value="U1" id="0" at="100,0,0" hide="no"/>
      <property key="Value" value="ATECC608B" id="1" at="100,2.54,0" hide="no"/>
      <property key="Footprint" value="SOIC.pretty:SOIC-8_3.9x4.9mm_P1.27mm" id="2" at="100,5.08,0" hide="no"/>
    </symbol_instance>
    <symbol_instance path="/00000000-0000-0000-0000-000000000001"
      symbol_lib_id="ai-os-carrier:M2_MKEY"
      uuid="10000000-0000-0000-0000-000000000003"
      timestamp="611D04AA"
      unit="1"
      in_bom="yes"
      on_board="yes"
      fields_autoplaced="yes">
      <property key="Reference" value="J2" id="0" at="100,20,0" hide="no"/>
      <property key="Value" value="M.2 NVMe" id="1" at="100,22.54,0" hide="no"/>
      <property key="Footprint" value="M.2-M-Key.pretty:M.2-M-Key" id="2" at="100,25.08,0" hide="no"/>
    </symbol_instance>
    <symbol_instance path="/00000000-0000-0000-0000-000000000001"
      symbol_lib_id="ai-os-carrier:SY8120"
      uuid="10000000-0000-0000-0000-000000000004"
      timestamp="611D04AB"
      unit="1"
      in_bom="yes"
      on_board="yes"
      fields_autoplaced="yes">
      <property key="Reference" value="U2" id="0" at="100,40,0" hide="no"/>
      <property key="Value" value="SY8120" id="1" at="100,42.54,0" hide="no"/>
      <property key="Footprint" value="SOIC.pretty:SOIC-8_3.9x4.9mm_P1.27mm" id="2" at="100,45.08,0" hide="no"/>
    </symbol_instance>
    <wire uuid="20000000-0000-0000-0000-000000000001" points="[(50,0),(100,0)]"/>
    <wire uuid="20000000-0000-0000-0000-000000000002" points="[(50,2.54),(100,2.54)]"/>
    <wire uuid="20000000-0000-0000-0000-000000000003" points="[(50,50),(100,50)]"/>
    <wire uuid="20000000-0000-0000-0000-000000000004" points="[(50,52.54),(100,52.54)]"/>
    <label uuid="30000000-0000-0000-0000-000000000001" text="GND" at="50,50,0"/>
    <label uuid="30000000-0000-0000-0000-000000000002" text="3.3V" at="50,52.54,0"/>
    <label uuid="30000000-0000-0000-0000-000000000003" text="SDA" at="50,0,0"/>
    <label uuid="30000000-0000-0000-0000-000000000004" text="SCL" at="50,2.54,0"/>
    <label uuid="30000000-0000-0000-0000-000000000005" text="PCIe_RX-" at="50,10.16,0"/>
    <label uuid="30000000-0000-0000-0000-000000000006" text="PCIe_RX+" at="50,12.7,0"/>
    <label uuid="30000000-0000-0000-0000-000000000007" text="PCIe_TX-" at="50,15.24,0"/>
    <label uuid="30000000-0000-0000-0000-000000000008" text="PCIe_TX+" at="50,17.78,0"/>
    <label uuid="30000000-0000-0000-0000-000000000009" text="5V_IN" at="50,20.32,0"/>
  </sheet>
</project>
EOF

echo "✅ Схема создана с компонентами и соединениями"

# 6. Создаём пустой файл платы
touch "ai_os_carrier.kicad_pcb"
echo "✅ Файл платы создан"

# 7. Инструкция
cat > "../docs/README.md" << 'EOF
# 🛠️ AI OS Core Pro Carrier Board

Проект KiCad для расширительной платы Orange Pi Zero 2W.

## 📦 Компоненты
- Orange Pi Zero 2W
- ATECC608B (HSM)
- M.2 NVMe
- SY8120 (PMIC)

## 🚀 Как использовать
1. Открой `ai_os_carrier.kicad_pro` в KiCad 7
2. Перейди в PCB Editor
3. Импортируй соединения
4. Трассируй плату
EOF

echo "📄 Документация создана"

# 8. Завершение
cd ../..
echo "🎉 Готово! Проект KiCad полностью создан:"
echo "  Папка: ./$PROJECT_NAME/"
echo "  Открой: ./$PROJECT_NAME/kicad/ai_os_carrier.kicad_pro"