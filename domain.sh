#!/bin/bash

set -e

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
DOMAIN_IP=$(dig +short A "$DOMAIN" | head -1 || getent hosts "$DOMAIN" | awk '{print $1}' | head -1 || echo "")

if [ -z "$DOMAIN_IP" ]; then
    exit_with_error "DNS_NOT_READY: $DOMAIN does not resolve to any IP"
fi

echo "DNS OK: $DOMAIN -> $DOMAIN_IP"

IS_CLOUDFLARE=false
CLOUDFLARE_RANGES=$(curl -s --max-time 5 https://www.cloudflare.com/ips-v4 || echo "")

if [ -n "$CLOUDFLARE_RANGES" ]; then
    while IFS= read -r range; do
        if python3 -c "import ipaddress; exit(0 if ipaddress.ip_address('$DOMAIN_IP') in ipaddress.ip_network('$range') else 1)" 2>/dev/null; then
            IS_CLOUDFLARE=true
            break
        fi
    done <<< "$CLOUDFLARE_RANGES"
fi

echo "Cloudflare proxy: $IS_CLOUDFLARE"

# ── 2. Установка софта ─────────────────────────────────────────────────────
if ! command -v nginx &> /dev/null; then
    apt-get update -qq && apt-get install -y nginx dnsutils -qq > /dev/null 2>&1
fi

if [ "$IS_CLOUDFLARE" = false ] && ! command -v certbot &> /dev/null; then
    apt-get update -qq && apt-get install -y certbot python3-certbot-nginx -qq > /dev/null 2>&1
fi

# ── 3. Настройка Nginx ─────────────────────────────────────────────────────
if [ -f "$NGINX_CONF" ]; then
    # Домен уже есть в конфиге — ничего делать не надо
    if grep -q -w "$DOMAIN" "$NGINX_CONF"; then
        echo "SUCCESS: Domain $DOMAIN already configured"
        exit 0
    fi

    # Добавляем домен к существующему конфигу
    CURRENT_DOMAINS=$(awk '/server_name/{gsub(/server_name /,""); gsub(/;/,""); print; exit}' "$NGINX_CONF" | xargs)
    sed -i "0,/server_name [^;]*;/s/server_name [^;]*;/server_name $CURRENT_DOMAINS $DOMAIN;/" "$NGINX_CONF"
else
    # Создаём новый конфиг
    if [ "$IS_CLOUDFLARE" = true ]; then
        cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate     /etc/nginx/ssl/self.crt;
    ssl_certificate_key /etc/nginx/ssl/self.key;

    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 104.16.0.0/13;
    set_real_ip_from 104.24.0.0/14;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 131.0.72.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 172.64.0.0/13;
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    real_ip_header CF-Connecting-IP;

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
    else
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
    fi

    ln -sf "$NGINX_CONF" "$NGINX_LINK"
    rm -f /etc/nginx/sites-enabled/default || true
fi

# Проверка nginx с выводом ошибки
NGINX_TEST=$(nginx -t 2>&1)
if ! nginx -t > /dev/null 2>&1; then
    echo "$NGINX_TEST" >&2
    exit_with_error "NGINX_CONFIG_INVALID"
fi

systemctl reload nginx

# ── 4. SSL — только для не-Cloudflare доменов ─────────────────────────────
if [ "$IS_CLOUDFLARE" = false ]; then
    echo "Получаем SSL сертификат..."
    FINAL_DOMAINS=$(awk '/server_name/{gsub(/server_name /,""); gsub(/;/,""); print; exit}' "$NGINX_CONF" | xargs | tr ' ' ',')

    if ! certbot --nginx \
        -d "$FINAL_DOMAINS" \
        --email "$EMAIL" \
        --agree-tos \
        --non-interactive \
        --redirect \
        --expand \
        --cert-name "$CONFIG_NAME"; then
        exit_with_error "SSL_ISSUANCE_FAILED"
    fi

    # Убираем сломанные пустые if ($host =) блоки которые certbot иногда добавляет
    perl -i -0pe 's/\s*if \(\$host =\) \{\s*return 301 https:\/\/\$host\$request_uri;\s*\} # managed by Certbot//g' "$NGINX_CONF"

    # Проверяем ещё раз после certbot
    NGINX_TEST=$(nginx -t 2>&1)
    if ! nginx -t > /dev/null 2>&1; then
        echo "$NGINX_TEST" >&2
        exit_with_error "NGINX_CONFIG_INVALID_AFTER_CERTBOT"
    fi

    systemctl reload nginx
else
    echo "Cloudflare домен — certbot пропущен, HTTPS через Cloudflare"
fi

# ── 5. Успех ───────────────────────────────────────────────────────────────
echo "SUCCESS: Domain $DOMAIN -> port $APP_PORT (cloudflare=$IS_CLOUDFLARE)"
exit 0