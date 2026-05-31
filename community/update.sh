#!/bin/bash

# =========================================================
# update.sh — обновление community
# Использование:
# bash update.sh <GITHUB_TOKEN>
# =========================================================

# Логи
exec > /tmp/community-update.log 2>&1

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
WEB_DIR="/home/community-web"
BOT_DIR="/home/community-bot"
BOT1_DIR="/home/priem-bot"
BOT2_DIR="/home/moder-bot"

# Репозитории
WEB_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/community-web"
BOT_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/community-bot"
BOT1_REPO="https://${GITHUB_TOKEN}@github.com/fantastic12314/priem-bot"
BOT2_REPO="https://${GITHUB_TOKEN}@github.com/Fondyxs/moder-bot"

echo "================================================"
echo "Начинаем обновление community"
echo "================================================"

# Остановка сервисов
echo "==> Останавливаем сервисы..."
/usr/bin/supervisorctl stop community:* || true

# =========================================================
# WEB
# =========================================================

echo "==> Обновляем community-web..."

cd "$WEB_DIR"

/usr/bin/git remote set-url origin "$WEB_REPO"
/usr/bin/git fetch origin
/usr/bin/git reset --hard origin/main


# =========================================================
# BOT
# =========================================================

echo "==> Обновляем community-bot..."

cd "$BOT_DIR"

/usr/bin/git remote set-url origin "$BOT_REPO"
/usr/bin/git fetch origin
/usr/bin/git reset --hard origin/main

# =========================================================
# BOT1
# =========================================================

echo "==> Обновляем priem-bot..."

cd "$BOT1_DIR"

/usr/bin/git remote set-url origin "$BOT1_REPO"
/usr/bin/git fetch origin
/usr/bin/git reset --hard origin/main

# =========================================================
# BOT2
# =========================================================

echo "==> Обновляем moder-bot..."

cd "$BOT2_DIR"

/usr/bin/git remote set-url origin "$BOT2_REPO"
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
    grep -v "pywin32" "$BOT_DIR/requirements.txt" > /tmp/bot1_req.txt

    "$BOT_DIR/venv/bin/pip" install \
        -r /tmp/bot1_req.txt \
        --no-input
fi

if [ -f "$BOT1_DIR/requirements.txt" ]; then
    grep -v "pywin32" "$BOT1_DIR/requirements.txt" > /tmp/bot1_req.txt

    "$BOT1_DIR/venv/bin/pip" install \
        -r /tmp/bot1_req.txt \
        --no-input
fi

if [ -f "$BOT2_DIR/requirements.txt" ]; then
    grep -v "pywin32" "$BOT2_DIR/requirements.txt" > /tmp/bot2_req.txt

    "$BOT2_DIR/venv/bin/pip" install \
        -r /tmp/bot2_req.txt \
        --no-input
fi

# =========================================================
# START
# =========================================================

echo "==> Запускаем сервисы..."
/usr/bin/supervisorctl start community:*

sleep 2

echo ""
echo "================================================"
/usr/bin/supervisorctl status community:*
echo "================================================"
echo ""

echo "✓ community обновлён!"
echo "Лог:"
echo "tail -f /tmp/community-update.log"