#!/bin/bash
set -euo pipefail

echo "🚀 Установка Xray (VLESS + Trojan) сервера с маскировкой под сайт..."

if [[ $EUID -ne 0 ]]; then
   echo "❌ Этот скрипт должен запускаться от root или через sudo"
   exit 1
fi

# Запрос данных
read -p "Введите домен (например, yoursite.com): " DOMAIN
read -p "Введите email для Let's Encrypt: " EMAIL
read -p "Введите путь маскировки (например, video): " MASK_PATH
MASK_PATH=${MASK_PATH:-video}

# Обновление системы
apt update && apt upgrade -y
apt install -y curl wget nginx certbot python3-certbot-nginx uuid-runtime

echo "🔧 Установка Xray..."

# Установка Xray (официальный релиз)
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# Генерация UUID
UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
VLESS_ID=$UUID
TROJAN_PASSWORD=$UUID  # Можно использовать что-то проще, но UUID — безопасно

# Конфиг Xray
cat > /usr/local/etc/xray/config.json <<EOF
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 443,
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$VLESS_ID",
            "flow": "xtls-rprx-vision",  // для Vision (современный обход)
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.microsoft.com:443",
          "privateKey": "$(xray x25519 -i | grep 'Private' | awk '{print $3}')",
          "shortIds": ["", "0123456789abcdef"],
          "spiderX": "/$MASK_PATH"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "port": 8443,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "$TROJAN_PASSWORD",
            "level": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "certificates": [
            {
              "certificateFile": "/etc/letsencrypt/live/$DOMAIN/fullchain.pem",
              "keyFile": "/etc/letsencrypt/live/$DOMAIN/privkey.pem"
            }
          ],
          "alpn": ["http/1.1"]
        },
        "wsSettings": {
          "path": "/trojan"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF

# Настройка Nginx как веб-сайт + маскировка
cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        return 301 https://\$host\$request_uri;
    }
    location ~ ^/$MASK_PATH.* {
        proxy_pass https://www.microsoft.com;
        proxy_ssl_server_name on;
        proxy_set_header Host www.microsoft.com;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# Перезапуск Nginx
systemctl restart nginx

# Получение SSL-сертификата
certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m $EMAIL --redirect

# Проверка, что сертификат создан
if [[ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]]; then
    echo "❌ Ошибка: SSL-сертификат не был получен. Проверь домен и порт 80."
    exit 1
fi

# Включение и запуск Xray
systemctl enable xray
systemctl restart xray

# Формирование ссылок
VLESS_LINK="vless://$VLESS_ID@$DOMAIN:443?security=reality&encryption=none&flow=xtls-rprx-vision&type=tcp&headerType=none&fp=chrome&pbk=$(jq -r '.inbounds[0].streamSettings.realitySettings.publicKey' /usr/local/etc/xray/config.json)&sni=www.bing.com&sid=0123456789abcdef&spx=/$MASK_PATH#VLESS-REALITY-$DOMAIN"

TROJAN_LINK="trojan://$TROJAN_PASSWORD@$DOMAIN:8443?security=tls&alpn=http/1.1&type=ws&path=%2Ftrojan#Trojan-TLS-WS"

# Сохранение ссылок
cat > /root/links.txt <<EOF
✅ VLESS-REALITY ссылка:
$VLESS_LINK

✅ Trojan-WS ссылка:
$TROJAN_LINK

📌 Конфигурация: /usr/local/etc/xray/config.json
🔧 Управление: systemctl {start|stop|restart} xray
🔄 Обновление сертификата: certbot renew (автоматически)
EOF

# Открытие портов
ufw allow 80,443,8443/tcp > /dev/null 2>&1 || true
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT

echo "✅ Установка завершена!"
echo "📁 Ссылки сохранены в /root/links.txt"
echo "💡 Открой файл и скопируй ссылки в клиенты:"
echo "   - VLESS: поддерживается в: v2rayNG, NekoBox, Qv2ray"
echo "   - Trojan: поддерживается в: Shadowrocket, Clash, Nekoray"
echo "🌐 Тестовый сайт: https://$DOMAIN"
echo "🔐 Сертификат обновляется автоматически через certbot"