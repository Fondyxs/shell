#!/bin/bash

# ═══════════════════════════════════════════════════════════════
# domain.sh — установка домена + SSL на Nginx (Ubuntu/Debian)
# Использование: sudo bash domain.sh <DOMAIN> <APP_PORT> <EMAIL>
# ═══════════════════════════════════════════════════════════════

set -e

# --- Проверка аргументов ---
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "Использование: sudo bash domain.sh <DOMAIN> <APP_PORT> <EMAIL>"
    exit 1
fi

DOMAIN="$1"
APP_PORT="$2"
EMAIL="$3"

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

echo ""
echo "▶ Домен:     $DOMAIN"
echo "▶ Порт:      $APP_PORT"
echo "▶ Email:     $EMAIL"
echo ""

# ── 1. Установка зависимостей ───────────────────────────────────
echo "[1/5] Установка Nginx и Certbot..."
apt-get update -q
apt-get install -y nginx certbot python3-certbot-nginx

# ── 2. Nginx конфиг ─────────────────────────────────────────────
echo "[2/5] Создание конфига Nginx..."
cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

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

# ── 3. Активация конфига ────────────────────────────────────────
echo "[3/5] Активация конфига..."
ln -sf "$NGINX_CONF" "/etc/nginx/sites-enabled/$DOMAIN"

rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl reload nginx

# ── 4. SSL через Certbot ─────────────────────────────────────────
echo "[4/5] Выпуск SSL сертификата..."
certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --email "$EMAIL" --agree-tos --non-interactive --redirect

# ── 5. Автообновление ────────────────────────────────────────────
echo "[5/5] Проверка автообновления сертификата..."
systemctl enable certbot.timer 2>/dev/null || true
certbot renew --dry-run

echo ""
echo "✅ Готово! Сайт доступен по адресу: https://$DOMAIN"