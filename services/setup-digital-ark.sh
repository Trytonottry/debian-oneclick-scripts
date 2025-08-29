#!/bin/bash
# setup-digital-ark.sh — One-Click Digital Sovereignty Setup
# Поддержка: Debian 12, Ubuntu 22.04+
# Устанавливает: ZFS, age, restic, Prometheus, Telegram-бот

set -euo pipefail

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[+] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}" >&2; exit 1; }

# Проверка sudo
if ! command -v sudo &> /dev/null; then
    error "Требуется sudo"
fi

# Проверка ОС
if ! grep -qi "debian\|ubuntu" /etc/os-release; then
    warn "Скрипт протестирован на Debian/Ubuntu. Продолжить? (y/N)"
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]] || error "Отменено пользователем"
fi

# Путь установки
INSTALL_DIR="/opt/digital-ark"
SECRETS_DIR="/secrets"
RESTIC_REPO="$INSTALL_DIR/restic-repo"
RESTIC_PASSWORD_FILE="$SECRETS_DIR/restic-pass.txt"

# Создание директорий
log "Создание структуры"
sudo mkdir -p "$INSTALL_DIR" "$SECRETS_DIR" "$RESTIC_REPO"
sudo chmod 700 "$SECRETS_DIR"

# 1. Установка ZFS
install_zfs() {
    log "Установка ZFS"
    sudo apt update
    sudo apt install -y zfsutils-linux

    log "Создание пула ZFS (mirror)"
    # ПОМЕНЯЙТЕ /dev/sdb /dev/sdc на ваши диски!
    sudo zpool create -f -O encryption=aes-256-gcm \
                      -O keylocation=prompt \
                      -O keyformat=passphrase \
                      -O atime=off \
                      -O compression=lz4 \
                      tank mirror /dev/sdb /dev/sdc

    sudo zfs create tank/backups
    sudo zfs create tank/system
    log "ZFS готов. Пароль будет запрошен при импорте."
}

# 2. Установка age
install_age() {
    log "Установка age"
    wget -qO /tmp/age.tar.gz https://github.com/FiloSottile/age/releases/latest/download/age-v1.1.1-linux-amd64.tar.gz
    sudo tar -C /usr/local/bin -xzf /tmp/age.tar.gz age age-keygen
    chmod +x /usr/local/bin/age*
}

# 3. Генерация age-ключа
setup_age_key() {
    log "Генерация age-ключа"
    if [[ ! -f "$SECRETS_DIR/recovery-key.age" ]]; then
        age-keygen -o "$SECRETS_DIR/recovery-key.age"
        log "Публичный ключ: $(head -1 "$SECRETS_DIR/recovery-key.age" | grep age)"
    else
        log "Ключ age уже существует"
    fi
}

# 4. Установка restic
install_restic() {
    log "Установка restic"
    sudo apt install -y restic

    if [[ ! -d "$RESTIC_REPO" || ! -f "$RESTIC_REPO/config" ]]; then
        RESTIC_PASS=$(openssl rand -base64 32)
        echo "$RESTIC_PASS" > "$RESTIC_PASSWORD_FILE"
        age -r "$(head -1 "$SECRETS_DIR/recovery-key.age")" -o "$RESTIC_PASSWORD_FILE.age" "$RESTIC_PASSWORD_FILE"
        rm "$RESTIC_PASSWORD_FILE"

        export RESTIC_REPOSITORY="$RESTIC_REPO"
        export RESTIC_PASSWORD="$RESTIC_PASS"
        restic init
        log "restic репозиторий инициализирован"
    fi
}

# 5. Cron для restic
setup_restic_cron() {
    log "Настройка cron для restic"
    cat > /tmp/restic-backup << 'EOF'
#!/bin/bash
export RESTIC_REPOSITORY=/opt/digital-ark/restic-repo
export RESTIC_PASSWORD=$(age -d -i /secrets/recovery-key.age -o - /secrets/restic-pass.txt.age)
restic backup --quiet /home /etc /root /opt/digital-ark
EOF

    sudo cp /tmp/restic-backup /etc/cron.daily/restic-backup
    sudo chmod +x /etc/cron.daily/restic-backup
}

# 6. Установка Prometheus + Alertmanager + Node Exporter
install_monitoring() {
    log "Установка Prometheus, Alertmanager, Node Exporter"

    cd "$INSTALL_DIR"

    # Node Exporter
    wget -q https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
    tar -xzf node_exporter-*.tar.gz --strip-components=1
    rm node_exporter-*.tar.gz

    # Prometheus
    wget -q https://github.com/prometheus/prometheus/releases/download/v2.48.0/prometheus-2.48.0.linux-amd64.tar.gz
    tar -xzf prometheus-*.tar.gz --strip-components=1
    rm prometheus-*.tar.gz

    # Alertmanager
    wget -q https://github.com/prometheus/alertmanager/releases/download/v0.27.0/alertmanager-0.27.0.linux-amd64.tar.gz
    tar -xzf alertmanager-*.tar.gz --strip-components=1
    rm alertmanager-*.tar.gz

    # Конфиги
    cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
EOF

    cat > alertmanager.yml << 'EOF'
route:
  receiver: 'telegram'

receivers:
  - name: 'telegram'
    webhook_configs:
      - url: 'http://localhost:9087/alert'
EOF

    # Telegram-бот
    cat > telegram-alert.py << 'EOF'
from telegram import Bot
from http.server import HTTPServer, BaseHTTPRequestHandler
import json, os

TELEGRAM_TOKEN = os.getenv("TELEGRAM_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")
bot = Bot(token=TELEGRAM_TOKEN)

class AlertHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_len = int(self.headers.get('Content-Length'))
        post_body = self.rfile.read(content_len)
        data = json.loads(post_body)
        for alert in data['alerts']:
            msg = f"🚨 {alert['status'].upper()}: {alert['labels']['alertname']}\n{alert['annotations']['description']}"
            bot.send_message(chat_id=CHAT_ID, text=msg)
        self.send_response(200)
        self.end_headers()

if __name__ == "__main__":
    server = HTTPServer(('localhost', 9087), AlertHandler)
    server.serve_forever()
EOF
}

# 7. Создание сервисов systemd
setup_services() {
    log "Настройка systemd сервисов"

    # Node Exporter
    sudo tee /etc/systemd/system/node-exporter.service > /dev/null << 'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=root
ExecStart=/opt/digital-ark/node_exporter

[Install]
WantedBy=multi-user.target
EOF

    # Prometheus
    sudo tee /etc/systemd/system/prometheus.service > /dev/null << 'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
User=root
ExecStart=/opt/digital-ark/prometheus --config.file=/opt/digital-ark/prometheus.yml --storage.tsdb.path=/opt/digital-ark/data

[Install]
WantedBy=multi-user.target
EOF

    # Alertmanager
    sudo tee /etc/systemd/system/alertmanager.service > /dev/null << 'EOF'
[Unit]
Description=Alertmanager
After=network.target

[Service]
User=root
ExecStart=/opt/digital-ark/alertmanager --config.file=/opt/digital-ark/alertmanager.yml

[Install]
WantedBy=multi-user.target
EOF

    # Telegram-бот
    sudo tee /etc/systemd/system/telegram-alert.service > /dev/null << 'EOF'
[Unit]
Description=Telegram Alert Bot
After=network.target

[Service]
User=root
Environment="TELEGRAM_TOKEN=ВАШ_ТОКЕН"
Environment="TELEGRAM_CHAT_ID=ВАШ_CHAT_ID"
ExecStart=/usr/bin/python3 /opt/digital-ark/telegram-alert.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable node-exporter prometheus alertmanager telegram-alert
    sudo systemctl start node-exporter prometheus alertmanager telegram-alert
}

# 8. Финал
finish() {
    log "✅ Установка завершена!"
    echo
    echo "ZFS:         tank (mirror /dev/sdb /dev/sdc)"
    echo "restic:      $RESTIC_REPO"
    echo "Prometheus:  http://localhost:9090"
    echo "Alerts:      Telegram (настроить токен в /etc/systemd/system/telegram-alert.service)"
    echo
    log "Перезагрузите систему, чтобы ZFS загрузился автоматически."
}

# Запуск
main() {
    install_zfs
    install_age
    setup_age_key
    install_restic
    setup_restic_cron
    install_monitoring
    setup_services
    finish
}

main "$@"