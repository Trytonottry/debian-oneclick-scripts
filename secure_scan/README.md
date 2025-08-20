# 🔐 SecureScan — Автоматизированный сканер безопасности

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/status-active-success)](README.md)
[![Docker](https://img.shields.io/badge/Docker-Supported-blue)](#)
[![ELK](https://img.shields.io/badge/ELK-Kibana%20Dashboard-blue)](#)

**SecureScan** — это one-click скрипт для комплексного сканирования сайтов и сетей с сохранением результатов в JSON, HTML, SQLite, PostgreSQL и Elasticsearch. Поддерживает визуализацию через Kibana, Web UI и автоматическую проверку безопасности.

---

## 🚀 Функции

- ✅ **Сканирование**: `nmap`, `arp`, `netstat`
- 🔍 **Уязвимости**: `nmap --script=vuln`
- 🌐 **DNS, WHOIS, SSL, HTTP Headers**
- 🛡️ **Проверка безопасности** (HSTS, CSP, X-Frame и др.)
- 📡 **Passive Recon**: Shodan, Censys, SecurityTrails
- 📂 **Active Directory / LDAP**
- 📊 **Визуализация**: Kibana Dashboard
- 🖥️ **Web UI на Flask**
- 📎 **Отчёты в HTML и PDF**
- 🐳 **Docker & Docker Compose**
- 📧 **Telegram-уведомления (опционально)**

---

## 📦 Установка

```bash
git clone https://github.com/Trytonottry/debian-pentest-setup/secure-scan.git
cd secure-scan
chmod +x secure_scan.sh
```

Установка зависимостей 
```bash
sudo apt install nmap net-tools jq whois dnsutils curl openssl ldap-utils sqlite3 -y
pip3 install weasyprint flask gunicorn
```
 
 
▶️ Запуск 
1. Через CLI 
```bash
./secure_scan.sh example.com
```
 
2. Массовое сканирование 
```bash
echo -e "example.com\ngoogle.com" > targets.txt
./secure_scan.sh batch targets.txt
```
 
3. Через Docker 
```bash
docker-compose up --build
```
 

Открой: 

    Web UI: http://localhost:5000 
    Kibana: http://localhost:5601 
     

 
📊 Kibana Dashboard 

    Импортируй kibana_dashboard.json в Kibana → Stack Management → Saved Objects
    Убедись, что индекс security-scans существует
    Открой дашборд "🔐 Security Scans Dashboard"
     
📄 Лицензия 

MIT      