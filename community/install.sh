#!/bin/bash

set -e

echo "==> Установка Community..."

# --- Токен ---
echo "Access Token:"
read -s GITHUB_TOKEN

WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/community-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/community-bot"
BOT1_REPO="https://${GITHUB_TOKEN}@github.com/fantastic12314/priem-bot"
WEB_DIR="/home/community-web"
BOT_DIR="/home/community-bot"
BOT1_DIR="/home/priem-bot"

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
    cp $BOT_DIR1/.env.example $BOT_DIR1/.env
    echo "  ! Заполни $BOT_DIR1/.env"
fi

# --- Supervisor ---
echo "==> Настройка Supervisor..."
mkdir -p /var/log/community

cat > /etc/supervisor/conf.d/community.conf << EOF
[program:community-web-global]
command=$WEB_DIR/venv/bin/gunicorn -w 4 -b 0.0.0.0:5003 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/community/web-global.err.log
stdout_logfile=/var/log/community/web-global.out.log

[program:community-web-local]
command=$WEB_DIR/venv/bin/gunicorn -w 2 -b 127.0.0.1:7000 main:app
directory=$WEB_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/community/web-local.err.log
stdout_logfile=/var/log/community/web-local.out.log

[program:community-bot]
command=$BOT_DIR/venv/bin/python main.py
directory=$BOT_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/community/bot.err.log
stdout_logfile=/var/log/community/bot.out.log

[program:priem-bot]
command=$BOT1_DIR/venv/bin/python main.py
directory=$BOT1_DIR
autostart=true
autorestart=true
stderr_logfile=/var/log/community/priem-bot.err.log
stdout_logfile=/var/log/community/priem-bot.out.log

[group:community]
programs=community-web-global,community-web-local,community-bot,priem-bot
EOF

supervisorctl reread
supervisorctl update
supervisorctl start community:*

echo ""
echo "✓ community установлен!"
echo "  Глобальный веб: 0.0.0.0:5002"
echo "  Локальный веб:  127.0.0.1:8000"
echo "  Статус: supervisorctl status community:*"
echo "  Логи:   tail -f /var/log/community/*.log"
echo ""
echo "  ! Не забудь заполнить .env файлы"