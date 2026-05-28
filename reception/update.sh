#!/bin/bash

set -e

echo "==> Обновление Reception..."

# --- Проверка root ---
if [ "$EUID" -ne 0 ]; then
    echo "Запусти от root"
    exit 1
fi

WEB_DIR="/home/reception-web"
BOT_DIR="/home/reception-bot"

# --- Токен ---
echo "Access Token:"
read -s GITHUB_TOKEN

WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/reception-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/reception-bot"

# --- Остановка ---
echo "==> Остановка сервисов..."
supervisorctl stop reception:* || true

# --- Обновление кода ---
echo "==> Обновление reception-web..."
cd $WEB_DIR
git remote set-url origin $WEB_REPO
git fetch origin
git reset --hard origin/main

echo "==> Обновление reception-bot..."
cd $BOT_DIR
git remote set-url origin $BOT_REPO
git fetch origin
git reset --hard origin/main

# --- Обновление зависимостей ---
echo "==> Обновление зависимостей..."
grep -v "pywin32" $WEB_DIR/requirements.txt > /tmp/web_req.txt
$WEB_DIR/venv/bin/pip install -r /tmp/web_req.txt --quiet

grep -v "pywin32" $BOT_DIR/requirements.txt > /tmp/bot_req.txt
$BOT_DIR/venv/bin/pip install -r /tmp/bot_req.txt --quiet

# --- Запуск ---
echo "==> Запуск сервисов..."
supervisorctl start reception:*

sleep 2
echo ""
echo "================================================"
supervisorctl status reception:*
echo "================================================"
echo ""
echo "✓ Reception обновлён!"
echo "  Логи: tail -f /var/log/reception/*.log"