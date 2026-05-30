#!/bin/bash

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${CYAN}[*] $1${NC}"; }
ok()   { echo -e "${GREEN}[✓] $1${NC}"; }
err()  { echo -e "${RED}[✗] $1${NC}"; exit 1; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }

# --- Токен (один раз) ---
echo ""
echo -e "${CYAN}===============================${NC}"
echo -e "${CYAN}   Установка всех проектов${NC}"
echo -e "${CYAN}===============================${NC}"
echo ""
echo -n "Access Token: "
read -s GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    err "Токен не введён"
fi

export GITHUB_TOKEN

install_project() {
    local name=$1
    local path=$2

    log "Устанавливаю $name..."

    curl -sSL "https://raw.githubusercontent.com/Fondyxs/shell/main/${path}/install.sh" -o "${name}-install.sh" \
        || err "Не удалось скачать install.sh для $name"

    chmod +x "${name}-install.sh"

    # Патчим read -s GITHUB_TOKEN — берём из окружения если уже есть
    sed -i 's|echo "Access Token:"\nread -s GITHUB_TOKEN||g' "${name}-install.sh"
    sed -i 's|echo "Access Token:"||g' "${name}-install.sh"
    sed -i 's|read -s GITHUB_TOKEN|GITHUB_TOKEN="${GITHUB_TOKEN:-}"|g' "${name}-install.sh"

    bash "${name}-install.sh" || err "Ошибка при установке $name"
    rm -f "${name}-install.sh"

    ok "$name установлен"
    echo ""
}

install_project "reception" "reception"
install_project "community" "community"
install_project "ludka"     "ludka"
install_project "scribe"    "scribe"

echo -e "${CYAN}===============================${NC}"
ok "Все проекты успешно установлены!"
echo -e "${CYAN}===============================${NC}"
echo ""
warn "Не забудь заполнить .env файлы в каждом проекте!"
echo ""