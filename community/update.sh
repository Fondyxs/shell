#!/bin/bash

set -e

echo "==> Обновление community..."

# --- Проверка аргументов ---
if [ -z "$1" ]; then
    echo "Использование: sudo bash update.sh <GITHUB_TOKEN>"
    exit 1
fi

GITHUB_TOKEN="$1"

# --- Проверка root ---
if [ "$EUID" -ne 0 ]; then
    echo "Запусти от root"
    exit 1
fi

WEB_DIR="/home/community-web"
BOT_DIR="/home/community-bot"

WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/community-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/community-bot"

# --- Остановка ---
echo "==> Остановка сервисов..."
supervisorctl stop community:* || true

# --- Обновление кода ---
echo "==> Обновление community-web..."
cd $WEB_DIR
git remote set-url origin $WEB_REPO
git fetch origin
git reset --hard origin/main

echo "==> Обновление community-bot..."
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
supervisorctl start community:*

sleep 2
echo ""
echo "================================================"
supervisorctl status community:*
echo "================================================"
echo ""
echo "✓ community обновлён!"
echo "  Логи: tail -f /var/log/community/*.log"