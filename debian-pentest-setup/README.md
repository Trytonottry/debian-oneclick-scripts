<p align="center">
  <img src="https://img.icons8.com/color/96/000000/shield.png" alt="Logo" width="80">
  <h1 align="center">debian-pentest-setup</h1>
  <p align="center">
    Automated pentest tools installer for Debian 12 (Bookworm) with GNOME.
  </p>
</p>

<p align="center">
  <a href="https://github.com/Trytonottry/debian-pentest-setup/stargazers">
    <img src="https://img.shields.io/github/stars/Trytonottry/debian-pentest-setup?style=social" alt="Stars">
  </a>
  <a href="https://github.com/Trytonottry/debian-pentest-setup/issues">
    <img src="https://img.shields.io/github/issues/Trytonottry/debian-pentest-setup" alt="Issues">
  </a>
  <a href="https://github.com/Trytonottry/debian-pentest-setup/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/Trytonottry/debian-pentest-setup" alt="License">
  </a>
  <img src="https://img.shields.io/badge/Debian-12-blue?logo=debian" alt="Debian 12">
  <img src="https://img.shields.io/badge/GNOME-43+-green?logo=gnome" alt="GNOME">
  <img src="https://img.shields.io/badge/Security-Tools-purple" alt="Security Tools">
</p>

---
## 🖼 Скриншот

![Интерактивное меню установки](screenshots/menu-packages.png)

> Меню с выбором инструментов: Burp, John, Metasploit и другие.

### 🚀 Описание
Автоматический установщик инструментов для тестирования на проникновение на **Debian 12 (Bookworm)**.  
Устанавливает: `Burp Suite`, `John the Ripper`, `Metasploit`, `Nmap`, `Wireshark`, `Hashcat`, `Hydra`, `Sqlmap`  
и создаёт удобную папку **"Security Tools"** в меню GNOME.

Идеально подходит для:
- Этического хакинга
- Подготовки лабораторий
- Red Team / Pentest рабочих станций

### 🛠 Дополнительные утилиты

| Скрипт | Описание |
|-------|---------|
| `tools/pentest-profile.sh` | Запускает режим пентеста |
| `tools/demo-mode.sh` | Демо с фейковыми данными |
| `tools/uninstall.sh` | Полное удаление |
| `tools/update-tools.sh` | Обновление всех инструментов |

---

### 📦 Установка
```bash
git clone https://github.com/Trytonottry/debian-pentest-setup.git
cd debian-pentest-setup
chmod +x install.sh
./install.sh
```
 
    💡 Скрипт запустит интерактивное меню, где можно выбрать нужные инструменты. 
     
### ⚠️ Предупреждение 

Этот проект предназначен только для обучения и авторизованного тестирования.
Не используй для несанкционированного доступа. 
 
### 🤝 Вклад 

Любые улучшения приветствуются!
Открой Issue или Pull Request. 
 
### 📄 Лицензия 

MIT © Trytonottry
