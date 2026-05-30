#!/bin/bash

# =========================================================
# update.sh — обновление Reception
# Использование:
# bash update.sh <GITHUB_TOKEN>
# =========================================================

# Логи
exec > /tmp/reception-update.log 2>&1

# Debug
set -ex

GITHUB_TOKEN="$1"

# Проверка токена
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Использование: bash update.sh <GITHUB_TOKEN>"
    exit 1
fi

# Проверка root
if [ "$EUID" -ne 0 ]; then
    echo "Скрипт должен запускаться от root"
    exit 1
fi

# Пути
WEB_DIR="/home/reception-web"
BOT_DIR="/home/reception-bot"

# Репозитории
WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/reception-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/reception-bot"

echo "================================================"
echo "Начинаем обновление Reception"
echo "================================================"

# Остановка сервисов
echo "==> Останавливаем сервисы..."
/usr/bin/supervisorctl stop reception:* || true

# =========================================================
# WEB
# =========================================================

echo "==> Обновляем reception-web..."

cd "$WEB_DIR"

/usr/bin/git remote set-url origin "$WEB_REPO"
/usr/bin/git fetch origin
/usr/bin/git reset --hard origin/main


# =========================================================
# BOT
# =========================================================

echo "==> Обновляем reception-bot..."

cd "$BOT_DIR"

/usr/bin/git remote set-url origin "$BOT_REPO"
/usr/bin/git fetch origin
/usr/bin/git reset --hard origin/main


# =========================================================
# DEPENDENCIES
# =========================================================

echo "==> Обновляем зависимости..."

if [ -f "$WEB_DIR/requirements.txt" ]; then
    grep -v "pywin32" "$WEB_DIR/requirements.txt" > /tmp/web_req.txt

    "$WEB_DIR/venv/bin/pip" install \
        -r /tmp/web_req.txt \
        --no-input
fi

if [ -f "$BOT_DIR/requirements.txt" ]; then
    grep -v "pywin32" "$BOT_DIR/requirements.txt" > /tmp/bot_req.txt

    "$BOT_DIR/venv/bin/pip" install \
        -r /tmp/bot_req.txt \
        --no-input
fi

# =========================================================
# START
# =========================================================

echo "==> Запускаем сервисы..."
/usr/bin/supervisorctl start reception:*

sleep 2

echo ""
echo "================================================"
/usr/bin/supervisorctl status reception:*
echo "================================================"
echo ""

echo "✓ Reception обновлён!"
echo "Лог:"
echo "tail -f /tmp/reception-update.log"