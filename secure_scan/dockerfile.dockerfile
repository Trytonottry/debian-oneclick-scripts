FROM ubuntu:22.04

# Установка зависимостей
RUN apt update && DEBIAN_FRONTEND=noninteractive apt install -y \
    nmap \
    net-tools \
    jq \
    whois \
    dnsutils \
    curl \
    openssl \
    ldap-utils \
    sqlite3 \
    postgresql-client \
    python3 \
    python3-pip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Установка WeasyPrint для PDF
RUN pip3 install weasyprint flask gunicorn

# Настройка рабочей директории
WORKDIR /app
COPY . .

# Сделать скрипт исполняемым
RUN chmod +x secure_scan.sh

# Порт Flask
EXPOSE 5000

# Запуск Web UI по умолчанию
CMD ["python3", "app.py"]