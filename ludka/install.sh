#!/bin/bash

set -e

echo "==> Установка Ludka Team..."

# --- Токен ---
echo "Access Token:"
read -s GITHUB_TOKEN

WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/ludka-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/ludka-bot"
WEB_DIR="/home/ludka-web"
BOT_DIR="/home/ludka-bot"

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

# --- Supervisor ---
echo "==> Настройка Supervisor..."
mkdir -p /var/log/ludka

cat > /etc/supervisor/conf.d/ludka.conf << EOF
[program:ludka-web-global]
command=$WEB_DIR/venv/bin/gunicorn -w 4 -b 0.0.0.0:5002 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/ludka/web-global.err.log
stdout_logfile=/var/log/ludka/web-global.out.log

[program:ludka-web-local]
command=$WEB_DIR/venv/bin/gunicorn -w 2 -b 127.0.0.1:8000 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/ludka/web-local.err.log
stdout_logfile=/var/log/ludka/web-local.out.log

[program:ludka-bot]
command=$BOT_DIR/venv/bin/python main.py
directory=$BOT_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/ludka/bot.err.log
stdout_logfile=/var/log/ludka/bot.out.log

[group:ludka]
programs=ludka-web-global,ludka-web-local,ludka-bot
EOF

supervisorctl reread
supervisorctl update
supervisorctl start ludka:*

echo ""
echo "✓ Reception установлен!"
echo "  Глобальный веб: 0.0.0.0:5002"
echo "  Локальный веб:  127.0.0.1:8000"
echo "  Статус: supervisorctl status ludka:*"
echo "  Логи:   tail -f /var/log/ludka/*.log"
echo ""
echo "  ! Не забудь заполнить .env файлы"