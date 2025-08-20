#!/bin/bash

# ===========================================
#   🔐 SecureScan — Полный сканер безопасности
#   Поддержка: CLI, Web, Docker, ELK, Telegram
#   Вывод: JSON, HTML, PDF, SQLite, ES
# ===========================================

set -euo pipefail

# === Настройки ===
TARGET=""
INPUT_FILE=""
OUTPUT_DIR="./scan_results"
DB_TYPE="sqlite"  # sqlite | postgres | elasticsearch
SEND_TELEGRAM=false
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
ES_HOST="${ES_HOST:-http://localhost:9200}"
ES_INDEX="security-scans"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_FILE="$OUTPUT_DIR/scan.log"

# === Обработка аргументов ===
if [ "$#" -eq 0 ]; then
    echo "🎯 Цель не указана. Введите домен или IP:"
    read -r TARGET
elif [ "$1" = "batch" ] && [ -n "$2" ] && [ -f "$2" ]; then
    INPUT_FILE="$2"
else
    TARGET="$1"
fi

# === Массовое сканирование ===
if [ -n "$INPUT_FILE" ]; then
    echo "📚 Массовое сканирование из $INPUT_FILE"
    while IFS= read -r domain; do
        domain=$(echo "$domain" | xargs)
        [ -z "$domain" ] && continue
        echo "=== Сканирование: $domain ==="
        ./secure_scan.sh "$domain"
    done < "$INPUT_FILE"
    exit 0
fi

# === Проверка цели ===
if [ -z "$TARGET" ]; then
    echo "❌ Цель не может быть пустой."
    exit 1
fi

# === Подготовка ===
mkdir -p "$OUTPUT_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=== 🔍 Сканирование: $TARGET | $TIMESTAMP ==="

JSON_FILE="$OUTPUT_DIR/${TARGET//\//_}_$TIMESTAMP.json"
HTML_REPORT="$OUTPUT_DIR/report_${TARGET//\//_}.html"
PDF_REPORT="${HTML_REPORT%.html}.pdf"

# === Инициализация JSON ===
cat << EOF > "$JSON_FILE"
{
  "target": "$TARGET",
  "timestamp": "$TIMESTAMP",
  "nmap": "",
  "nmap_vuln": [],
  "arp": [],
  "netstat": [],
  "whois": [],
  "dns": {},
  "passive": {},
  "ldap": {},
  "http": {
    "headers": {},
    "security_issues": [],
    "security_score": 100,
    "ssl": {}
  },
  "scan_metadata": {
    "risk_level": "low"
  }
}
EOF

# === 1. Nmap (базовое) ===
echo "[*] 🔎 Nmap: базовое сканирование..."
NMAP_STD=$(nmap -A -T4 -vv -oN /dev/stdout "$TARGET" 2>&1 | sed 's/"/\\"/g')
jq --arg nmap "$NMAP_STD" '.nmap = $nmap' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"

# === 2. Nmap --script=vuln ===
echo "[*] ⚠️ Nmap: проверка уязвимостей..."
NMAP_VULN=$(nmap --script=vuln -oN /dev/stdout "$TARGET" 2>&1 | grep -iE "VULNERABLE|exploit|CVE" | sed 's/"/\\"/g')
echo "$NMAP_VULN" | jq -R . | jq -s '.' > tmp_vuln.$$.json
jq --slurpfile vuln tmp_vuln.$$.json '.nmap_vuln = $vuln' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
rm -f tmp_vuln.$$.json

# === 3. ARP ===
echo "[*] 🌐 ARP таблица..."
arp -a 2>/dev/null | tail -n +2 | while read line; do
    ip=$(echo "$line" | awk '{print $2}' | sed 's/(//' | sed 's/)//')
    mac=$(echo "$line" | awk '{print $4}')
    iface=$(echo "$line" | awk '{print $5}')
    jq -n --arg ip "$ip" --arg mac "$mac" --arg iface "$iface" '{ip: $ip, mac: $mac, interface: $iface}' >> tmp_arp.$$.json
done
jq --slurpfile arp 'tmp_arp.$$.json' '.arp = $arp' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
rm -f tmp_arp.$$.json

# === 4. Netstat ===
echo "[*] 📡 Netstat (локальные соединения)..."
netstat -tulnp 2>/dev/null | tail -n +3 | while read line; do
    proto=$(echo "$line" | awk '{print $1}')
    local=$(echo "$line" | awk '{print $4}')
    state=$(echo "$line" | awk '{print $6}')
    program=$(echo "$line" | awk '{print $7}' | cut -d'/' -f2)
    jq -n --arg proto "$proto" --arg local "$local" --arg state "$state" --arg program "$program" \
      '{proto: $proto, local: $local, state: $state, program: $program}' >> tmp_net.$$.json
done
jq --slurpfile netstat 'tmp_net.$$.json' '.netstat = $netstat' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
rm -f tmp_net.$$.json

# === 5. WHOIS ===
echo "[*] 📄 WHOIS информация..."
whois "$TARGET" 2>/dev/null | grep -iE "Domain|Organization|Registrant|Name Server|Creation|Expiry|Status" | \
    sed 's/^\s*//;s/\s*$//' | grep -v "^$" | jq -R . >> tmp_whois.$$.json
jq --slurpfile whois 'tmp_whois.$$.json' '.whois = $whois' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
rm -f tmp_whois.$$.json

# === 6. DNS (dig) ===
echo "[*] 🌍 DNS записи..."
declare -A RECORDS=( ["A"]="A" ["MX"]="MX" ["TXT"]="TXT" ["NS"]="NS" ["CNAME"]="CNAME" )
DNS_JSON="{}"
for rec in "${!RECORDS[@]}"; do
    result=$(dig +short "$TARGET" "$rec" | paste -s -d ',' -)
    DNS_JSON=$(echo "$DNS_JSON" | jq --arg k "$rec" --arg v "$result" '. + {($k): $v}')
done
jq --argjson dns "$DNS_JSON" '.dns = $dns' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"

# === 7. HTTP Headers + Безопасность ===
check_http_headers() {
    if [[ ! "$TARGET" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then return; fi

    echo "[*] 🛡️ Проверка HTTP безопасности..."
    SECURITY_ISSUES=()
    SCORE=100

    for proto in https http; do
        STATUS=$(curl -I -m 10 -s -o /dev/null -w "%{http_code}" "$proto://$TARGET" 2>/dev/null)
        if [ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 500 ]; then
            HEADERS=$(curl -I -m 10 -s "$proto://$TARGET" | grep -iE "^(HTTP/|Server:|X-Powered-By:|Strict-Transport-Security:|Content-Security-Policy:|X-Content-Type-Options:|X-Frame-Options:|Referrer-Policy:)")

            echo "$HEADERS" | jq -R . | jq -s 'map(split(": ") | .[0] as $k | .[1] as $v | {($k): $v}) | add' > tmp_hdr.$$.json

            # Анализ
            [ -z "$(echo "$HEADERS" | grep -i "Strict-Transport-Security")" ] && SECURITY_ISSUES+=("HSTS отсутствует") && SCORE=$((SCORE-20))
            [ -z "$(echo "$HEADERS" | grep -i "Content-Security-Policy")" ] && SECURITY_ISSUES+=("CSP отсутствует") && SCORE=$((SCORE-15))
            [ -z "$(echo "$HEADERS" | grep -i "X-Content-Type-Options.*nosniff")" ] && SECURITY_ISSUES+=("X-Content-Type-Options: missing") && SCORE=$((SCORE-10))
            [ -z "$(echo "$HEADERS" | grep -i "X-Frame-Options")" ] && SECURITY_ISSUES+=("X-Frame-Options: missing") && SCORE=$((SCORE-10))

            ISSUE_JSON=$(printf '%s\n' "${SECURITY_ISSUES[@]}" | jq -R . | jq -s '.')
            jq --slurpfile hdr 'tmp_hdr.$$.json' --arg proto "$proto" --argjson issues "$ISSUE_JSON" --argjson score "$SCORE" \
               '.http.headers = ($hdr[0] // {}) | .http.security_issues = $issues | .http.security_score = $score' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
            rm -f tmp_hdr.$$.json
            break
        fi
    done
}
check_http_headers

# === 8. SSL Certificate ===
check_ssl() {
    if [[ ! "$TARGET" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then return; fi
    echo "[*] 🔐 Проверка SSL сертификата..."
    local data=$(echo | timeout 10 openssl s_client -connect "$TARGET:443" -servername "$TARGET" 2>/dev/null)
    if [ -z "$data" ]; then
        jq '.http.ssl.error = "Не удалось подключиться к 443 порту"' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
        return
    fi

    local cert=$(echo "$data" | openssl x509 -noout -text)
    local subject=$(echo "$cert" | grep "Subject:" | head -1 | cut -d':' -f2-)
    local issuer=$(echo "$cert" | grep "Issuer:" | head -1 | cut -d':' -f2-)
    local valid_to=$(echo "$cert" | grep "Not After :" | cut -d':' -f2-)
    local sig_alg=$(echo "$cert" | grep "Signature Algorithm:" | cut -d':' -f2-)
    local expiry=$(echo "$cert" | grep "Not After :" | xargs -I{} date -d "{}" +%s 2>/dev/null || echo 0)
    local days_left=$(( (expiry - $(date +%s)) / 86400 ))

    local issues=()
    [ $days_left -lt 30 ] && issues+=("SSL истекает через $days_left дней")
    [[ "$sig_alg" == *"md5"* || "$sig_alg" == *"sha1"* ]] && issues+=("Слабый алгоритм: $sig_alg")

    jq -n \
      --arg subject "$subject" --arg issuer "$issuer" --arg to "$valid_to" \
      --arg alg "$sig_alg" --argjson days "$days_left" \
      --argjson issues "$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s '.')" \
      '{subject: $subject, issuer: $issuer, valid_to: $to, signature_algorithm: $alg, days_until_expiry: $days, security_issues: $issues}' > tmp_ssl.$$.json

    jq --slurpfile ssl tmp_ssl.$$.json '.http.ssl += $ssl[0]' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
    rm -f tmp_ssl.$$.json

    # Обновить оценку
    for issue in "${issues[@]}"; do
        jq --argjson score 10 '.http.security_score -= $score' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
    done
}
check_ssl

# === 9. Passive Recon (Shodan, Censys, SecurityTrails) ===
passive_recon() {
    local ip=$(dig +short "$TARGET" | grep -E "^[0-9]{1,3}(\.[0-9]{1,3}){3}$" | head -1)
    [ -z "$ip" ] && return

    echo "[*] 🔍 Passive Recon для $ip..."

    # Shodan (если установлен)
    if command -v shodan &>/dev/null; then
        shodan host "$ip" --fields ip_str,os,ports,hostnames,vulns > tmp_shodan.$$.json 2>/dev/null || echo "{}" > tmp_shodan.$$.json
        jq --slurpfile shodan tmp_shodan.$$.json '.passive.shodan = $shodan[0]' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
    fi

    # Censys (пример)
    # curl -s -u "$CENSYS_API_ID:$CENSYS_SECRET" "https://search.censys.io/api/v2/hosts/$ip"

    # SecurityTrails
    # curl -s "https://api.securitytrails.com/v1/domain/$TARGET" -H "APIKEY: $ST_KEY"

    rm -f tmp_*.json
}
passive_recon

# === 10. LDAP/AD ===
ldap_scan() {
    echo "[*] 📂 Проверка LDAP (389/636)..."
    local ports=$(nmap -p 389,636 -oN /dev/stdout "$TARGET" 2>&1 | grep -E "389|636" | grep open)
    if [ -z "$ports" ]; then
        jq '.ldap.status = "closed"' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
        return
    fi

    local anon=$(ldapwhoami -H ldap://"$TARGET" -x -LLL -N 2>/dev/null || echo "error")
    local base_dn="dc=$(echo "$TARGET" | sed 's/\./,dc=/g')"

    jq -n --arg anon "$anon" --arg base "$base_dn" \
       '{status: "open", anonymous_bind: $anon, base_dn: $base}' > tmp_ldap.$$.json
    jq --slurpfile ldap tmp_ldap.$$.json '.ldap += $ldap[0]' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"
    rm -f tmp_ldap.$$.json
}
ldap_scan

# === 11. Risk Level ===
SCORE=$(jq '.http.security_score // 100' "$JSON_FILE")
if [ $SCORE -lt 50 ]; then
    RISK="high"
elif [ $SCORE -lt 80 ]; then
    RISK="medium"
else
    RISK="low"
fi
jq --arg risk "$RISK" '.scan_metadata.risk_level = $risk' "$JSON_FILE" > tmp.$$.json && mv tmp.$$.json "$JSON_FILE"

# === 12. Сохранение в БД ===
save_to_sqlite() {
    sqlite3 "$OUTPUT_DIR/scans.db" << EOF
CREATE TABLE IF NOT EXISTS scans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    target TEXT,
    timestamp TEXT,
    risk_level TEXT,
    json_dump TEXT
);
INSERT INTO scans (target, timestamp, risk_level, json_dump)
VALUES ('$TARGET', '$TIMESTAMP', '$RISK', '$(jq -c '.' "$JSON_FILE" | sed "s/'/''/g")');
EOF
}

save_to_elasticsearch() {
    curl -s -X POST "$ES_HOST/$ES_INDEX/_doc" \
         -H "Content-Type: application/json" \
         -d @"$JSON_FILE" > /dev/null && echo "[+] Отправлено в Elasticsearch"
}

case "$DB_TYPE" in
    "elasticsearch") save_to_elasticsearch ;;
    *) save_to_sqlite ;;
esac

# === 13. HTML Отчёт ===
cat << EOF > "$HTML_REPORT"
<!DOCTYPE html>
<html><head>
  <title>🔐 Отчёт: $TARGET</title>
  <link rel="stylesheet" href="style.css">
</head><body>
  <div class="header">
    <h1>🔐 Отчёт: $TARGET</h1>
    <p>📅 $TIMESTAMP | Риск: <strong class="risk-$RISK">$RISK</strong> | Оценка: <strong>$(jq -r '.http.security_score // 100' "$JSON_FILE")/100</strong></p>
  </div>
  <div class="section"><h2>⚠️ Проблемы безопасности</h2><ul>
$(jq -r '.http.security_issues[] | "<li>\(.)</li>"' "$JSON_FILE" || echo "<li>Нет</li>")
  </ul></div>
  <div class="section"><h2>🔍 Уязвимости</h2><pre>$(jq -r '.nmap_vuln[]' "$JSON_FILE")</pre></div>
  <div class="section"><h2>🔐 SSL</h2><pre>$(jq -r '.http.ssl | to_entries[] | "\(.key): \(.value)"' "$JSON_FILE")</pre></div>
  <div class="section"><h2>🌐 DNS</h2><pre>$(jq -r '.dns | to_entries[] | "\(.key): \(.value)"' "$JSON_FILE")</pre></div>
  <footer><hr><p><em>Сгенерировано: secure_scan.sh</em></p></footer>
</body></html>
EOF

# === 14. PDF (если установлен weasyprint) ===
if command -v weasyprint &>/dev/null; then
    weasyprint "$HTML_REPORT" "$PDF_REPORT" 2>/dev/null && echo "[✅] PDF: $PDF_REPORT"
fi

# === 15. Telegram (опционально) ===
if [ "$SEND_TELEGRAM" = true ] && [ -n "$TELEGRAM_BOT_TOKEN" ]; then
    MSG="✅ Сканирование $TARGET завершено\nРиск: *$RISK*\nОценка: $(jq -r '.http.security_score // 100' "$JSON_FILE")/100"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
         -d chat_id="$TELEGRAM_CHAT_ID" \
         -d text="$MSG" \
         -d parse_mode="Markdown" > /dev/null
fi

# === Финал ===
echo ""
echo "✅ Сканирование завершено!"
echo "📄 JSON:   file://$(realpath "$JSON_FILE")"
echo "📊 HTML:   file://$(realpath "$HTML_REPORT")"
[ -f "$PDF_REPORT" ] && echo "📑 PDF:    file://$(realpath "$PDF_REPORT")"
echo "💾 БД:     $DB_TYPE"
echo "🔍 Риск:   $RISK"