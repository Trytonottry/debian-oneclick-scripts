#!/bin/bash
# 04-notify.sh — отправка email с данными установки

source config.sh
source lib/functions.sh

# Установка sendmail, если нет
if ! command -v sendmail &> /dev/null; then
    log "📧 Устанавливаем sendmail для уведомлений..."
    apt install -y sendmail mailutils
fi

# Формируем письмо
EMAIL_TEMP="/tmp/nextcloud-welcome-$(date +%s).txt"
cat > "$EMAIL_TEMP" << EOF
To: $ADMIN_EMAIL
From: no-reply@$DOMAIN
Subject: ✅ Nextcloud установлен: $DOMAIN
Content-Type: text/plain; charset=UTF-8

🚀 УСТАНОВКА NEXTCLOUD ЗАВЕРШЕНА
==================================
Дата: $(date)
Сервер: $(hostname)
Домен: $DOMAIN

🌐 ДОСТУП
   URL: https://$DOMAIN

🔐 УЧЁТНЫЕ ДАННЫЕ АДМИНИСТРАТОРА
   Логин: $ADMIN_USER
   Пароль: $ADMIN_PASS

🗄️  ДАННЫЕ БАЗЫ ДАННЫХ
   Пользователь: $DB_USER
   Пароль: $DB_PASS
   База: $DB_NAME
   Хост: localhost

💾 РЕЗЕРВНОЕ КОПИРОВАНИЕ
   Папка: $BACKUP_DIR
   Расписание: 0 2 * * * (ежедневно 02:00)
   Хранение: 7 дней

🔧 РЕКОМЕНДАЦИИ
   - Сохраните это письмо.
   - Включите 2FA в настройках безопасности.
   - Проверяйте /var/log/nextcloud-backup.log

📄 Лог установки прикреплён.
EOF

# Отправляем
if cat "$EMAIL_TEMP" | sendmail "$ADMIN_EMAIL"; then
    log "📧 Уведомление отправлено на: $ADMIN_EMAIL"
else
    log "⚠️  Не удалось отправить email. Проверьте sendmail."
    log "   Совет: запустите 'sudo sendmail admin@your-domain.com' и введите тестовое письмо."
fi

# Чистим
rm -f "$EMAIL_TEMP"