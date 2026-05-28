#!/bin/bash

set -e

echo "==> Установка Reception..."

# --- Токен ---
echo "Access Token:"
read -s GITHUB_TOKEN

WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/reception-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/reception-bot"
WEB_DIR="/home/reception-web"
BOT_DIR="/home/reception-bot"

# --- Зависимости ---
echo "==> Установка зависимостей..."
apt update -y
apt install -y python3 python3-venv python3-pip git supervisor

# --- Клонирование ---
echo "==> Клонирование репозиториев..."
[ -d "$WEB_DIR" ] && rm -rf "$WEB_DIR"
[ -d "$BOT_DIR" ] && rm -rf "$BOT_DIR"

git clone $WEB_REPO $WEB_DIR
git clone $BOT_REPO $BOT_DIR

# --- Виртуальное окружение ---
echo "==> Установка библиотек..."
python3 -m venv $WEB_DIR/venv
$WEB_DIR/venv/bin/pip install -r $WEB_DIR/requirements.txt

python3 -m venv $BOT_DIR/venv
$BOT_DIR/venv/bin/pip install -r $BOT_DIR/requirements.txt

# # --- .env ---
# echo "==> Настройка .env..."
# if [ ! -f "$WEB_DIR/.env" ]; then
#     cp $WEB_DIR/.env.example $WEB_DIR/.env
#     echo "  ! Заполни $WEB_DIR/.env"
# fi
# if [ ! -f "$BOT_DIR/.env" ]; then
#     cp $BOT_DIR/.env.example $BOT_DIR/.env
#     echo "  ! Заполни $BOT_DIR/.env"
# fi

# --- Supervisor ---
echo "==> Настройка Supervisor..."
mkdir -p /var/log/reception

cat > /etc/supervisor/conf.d/reception.conf << EOF
[program:reception-web-global]
command=$WEB_DIR/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/reception/web-global.err.log
stdout_logfile=/var/log/reception/web-global.out.log

[program:reception-web-local]
command=$WEB_DIR/venv/bin/gunicorn -w 2 -b 127.0.0.1:5001 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/reception/web-local.err.log
stdout_logfile=/var/log/reception/web-local.out.log

[program:reception-bot]
command=$BOT_DIR/venv/bin/python main.py
directory=$BOT_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/reception/bot.err.log
stdout_logfile=/var/log/reception/bot.out.log

[group:reception]
programs=reception-web-global,reception-web-local,reception-bot
EOF

supervisorctl reread
supervisorctl update
supervisorctl start reception:*

echo ""
echo "✓ Reception установлен!"
echo "  Глобальный веб: 0.0.0.0:5000"
echo "  Локальный веб:  127.0.0.1:5001"
echo "  Статус: supervisorctl status reception:*"
echo "  Логи:   tail -f /var/log/reception/*.log"
echo ""
echo "  ! Не забудь заполнить .env файлы"