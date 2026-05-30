#!/bin/bash

set -e

echo "==> Установка Scribe..."

# --- Токен ---
echo "Access Token:"
read -s GITHUB_TOKEN

WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/scribe-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/scribe-bot"
BOT1_REPO="https://${GITHUB_TOKEN}@github.com/fantastic12314/jetterlink-bot"
WEB_DIR="/home/scribe-web"
BOT_DIR="/home/scribe-bot"
BOT1_DIR="/home/jetterlink-bot"

# --- Зависимости ---
echo "==> Установка зависимостей..."
apt update -y
apt install -y python3 python3-venv python3-pip git supervisor

# --- Клонирование ---
echo "==> Клонирование репозиториев..."
[ -d "$WEB_DIR" ] && rm -rf "$WEB_DIR"
[ -d "$BOT_DIR" ] && rm -rf "$BOT_DIR"
[ -d "$BOT1_DIR" ] && rm -rf "$BOT1_DIR"

git clone $WEB_REPO $WEB_DIR
git clone $BOT_REPO $BOT_DIR
git clone $BOT1_REPO $BOT1_DIR
# --- Виртуальное окружение ---
echo "==> Установка библиотек..."
python3 -m venv $WEB_DIR/venv
$WEB_DIR/venv/bin/pip install -r $WEB_DIR/requirements.txt

python3 -m venv $BOT_DIR/venv
$BOT_DIR/venv/bin/pip install -r $BOT_DIR/requirements.txt

python3 -m venv $BOT1_DIR/venv
$BOT1_DIR/venv/bin/pip install -r $BOT1_DIR/requirements.txt

# --- .env ---
echo "==> Настройка .env..."
if [ ! -f "$WEB_DIR/.env" ]; then
    cp $WEB_DIR/.env.example $WEB_DIR/.env
    echo "  ! Заполни $WEB_DIR/.env"
fi
if [ ! -f "$BOT_DIR/.env" ]; then
    cp $BOT_DIR/.env.example $BOT_DIR/.env
    echo "  ! Заполни $BOT_DIR/.env"
fi
if [ ! -f "$BOT1_DIR/.env" ]; then
    cp $BOT1_DIR/.env.example $BOT1_DIR/.env
    echo "  ! Заполни $BOT1_DIR/.env"
fi

# --- Supervisor ---
echo "==> Настройка Supervisor..."
mkdir -p /var/log/scribe

cat > /etc/supervisor/conf.d/scribe.conf << EOF
[program:scribe-web-global]
command=$WEB_DIR/venv/bin/gunicorn -w 4 -b 0.0.0.0:5004 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/scribe/web-global.err.log
stdout_logfile=/var/log/scribe/web-global.out.log

[program:scribe-web-local]
command=$WEB_DIR/venv/bin/gunicorn -w 2 -b 127.0.0.1:6500 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/scribe/web-local.err.log
stdout_logfile=/var/log/scribe/web-local.out.log

[program:scribe-bot]
command=$BOT_DIR/venv/bin/python main.py
directory=$BOT_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/scribe/bot.err.log
stdout_logfile=/var/log/scribe/bot.out.log

[program:jetterlink-bot]
command=$BOT1_DIR/venv/bin/python main.py
directory=$BOT1_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/scribe/bot.err.log
stdout_logfile=/var/log/scribe/bot.out.log

[group:scribe]
programs=scribe-web-global,scribe-web-local,scribe-bot,jetterlink-bot
EOF

supervisorctl reread
supervisorctl update
supervisorctl start scribe:*

echo ""
echo "✓ Scribe установлен!"
echo "  Глобальный веб: 0.0.0.0:5004"
echo "  Локальный веб:  127.0.0.1:6500"
echo "  Статус: supervisorctl status scribe:*"
echo "  Логи:   tail -f /var/log/scribe/*.log"
echo ""
echo "  ! Не забудь заполнить .env файлы"