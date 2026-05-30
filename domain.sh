#!/bin/bash

set -e

# Функция для вывода ошибки и выхода
exit_with_error() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- Проверка аргументов ---
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    exit_with_error "MISSING_ARGUMENTS"
fi

DOMAIN=$(echo "$1" | tr '[:upper:]' '[:lower:]')
APP_PORT="$2"
EMAIL="$3"
CONFIG_NAME="app_port_$APP_PORT"
NGINX_CONF="/etc/nginx/sites-available/$CONFIG_NAME"
NGINX_LINK="/etc/nginx/sites-enabled/$CONFIG_NAME"

# ── 1. Проверка DNS ────────────────────────────────────────────────────────
SERVER_IP=$(curl -s https://ifconfig.me || echo "")
DOMAIN_IP=$(getent hosts "$DOMAIN" | awk '{ print $1 }' || echo "")

if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
    exit_with_error "DNS_NOT_READY: $DOMAIN points to $DOMAIN_IP, server is $SERVER_IP"
fi

# ── 2. Установка софта ─────────────────────────────────────────────────────
if ! command -v nginx &> /dev/null || ! command -v certbot &> /dev/null; then
    apt-get update -qq && apt-get install -y nginx certbot python3-certbot-nginx -qq > /dev/null 2>&1
fi

# ── 3. Настройка Nginx ─────────────────────────────────────────────────────
if [ -f "$NGINX_CONF" ]; then
    # Если файл есть, проверяем нет ли уже этого домена
    if ! grep -q -w "$DOMAIN" "$NGINX_CONF"; then
        # Читаем текущие домены, добавляем новый, убираем лишние пробелы
        CURRENT_DOMAINS=$(grep "server_name" "$NGINX_CONF" | sed 's/.*server_name \(.*\);/\1/')
        NEW_DOMAINS_LINE="$CURRENT_DOMAINS $DOMAIN"
        # Перезаписываем строку server_name на чистую
        sed -i "s/server_name .*;/server_name $NEW_DOMAINS_LINE;/" "$NGINX_CONF"
    fi
else
    # Создаем новый конфиг
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    ln -sf "$NGINX_CONF" "$NGINX_LINK"
    rm -f /etc/nginx/sites-enabled/default || true
fi

# ПЕРЕЗАГРУЗКА NGINX (Обязательно до запуска Certbot)
nginx -t > /dev/null 2>&1 || exit_with_error "NGINX_CONFIG_INVALID"
systemctl reload nginx

# ── 4. SSL через Certbot ───────────────────────────────────────────────────
# Получаем список доменов в формате dom1.com,dom2.com для Certbot
# xargs уберет лишние пробелы по краям
FINAL_DOMAINS=$(grep "server_name" "$NGINX_CONF" | sed 's/.*server_name \(.*\);/\1/' | xargs | tr ' ' ',')

# Запускаем Certbot
# Мы убрали > /dev/null, чтобы в случае ошибки Python мог прочитать причину
if ! certbot --nginx -d "$FINAL_DOMAINS" --email "$EMAIL" --agree-tos --non-interactive --redirect --expand --cert-name "$CONFIG_NAME"; then
    exit_with_error "SSL_ISSUANCE_FAILED"
fi

# ── 5. Успех ───────────────────────────────────────────────────────────────
echo "SUCCESS: Domain $DOMAIN added to port $APP_PORT"
exit 0
