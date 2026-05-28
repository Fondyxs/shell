#!/bin/bash

set -e

echo "==> Защита сервера..."

# --- Проверка root ---
if [ "$EUID" -ne 0 ]; then
    echo "Запусти от root"
    exit 1
fi

# --- Обновление системы ---
echo "==> Обновление системы..."
apt update -y && apt upgrade -y

# --- Установка нужных пакетов ---
echo "==> Установка пакетов..."
apt install -y ufw fail2ban unattended-upgrades curl wget

# --- Создание пользователя ---
echo "==> Создание пользователя..."
while true; do
    read -p "Введи имя пользователя: " USERNAME
    
    if [ -z "$USERNAME" ]; then
        echo "  Имя не может быть пустым"
        continue
    fi
    
    if id "$USERNAME" &>/dev/null; then
        echo "  Пользователь $USERNAME уже существует, введи другое"
        continue
    fi
    
    useradd -m -s /bin/bash $USERNAME
    break
done

usermod -aG sudo $USERNAME

mkdir -p /home/$USERNAME/.ssh
ssh-keygen -t rsa -b 4096 -f /home/$USERNAME/.ssh/id_rsa -N ""
cat /home/$USERNAME/.ssh/id_rsa.pub >> /home/$USERNAME/.ssh/authorized_keys
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

PRIVATE_KEY=$(cat /home/$USERNAME/.ssh/id_rsa)

# --- SSH защита ---
echo "==> Настройка SSH..."
SSH_PORT=2222

# Полная перезапись конфига вместо sed
cat > /etc/ssh/sshd_config << EOF
Port $SSH_PORT
Protocol 2

PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

MaxAuthTries 3
LoginGraceTime 30
MaxSessions 5

X11Forwarding no
AllowTcpForwarding no
GatewayPorts no
PermitTunnel no

UsePAM yes
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

# Проверить конфиг перед рестартом
sshd -t && systemctl restart ssh || systemctl restart sshd

# --- UFW Firewall ---
echo "==> Настройка UFW..."
ufw default deny incoming
ufw default allow outgoing

ufw allow $SSH_PORT/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 5000/tcp
ufw limit $SSH_PORT/tcp

ufw --force enable

# --- Fail2Ban ---
echo "==> Настройка Fail2Ban..."
cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = systemd

[sshd]
enabled  = true
port     = $SSH_PORT
maxretry = 3
bantime  = 86400

[nginx-http-auth]
enabled = true

[nginx-limit-req]
enabled = true

[nginx-botsearch]
enabled = true
EOF

systemctl enable fail2ban
systemctl restart fail2ban

# --- Защита от SYN флуда ---
echo "==> Настройка sysctl..."
cat >> /etc/sysctl.conf << EOF

# Защита от SYN флуда
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Защита от спуфинга
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Отключить ICMP редиректы
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0

# Защита от ping флуда
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Логировать подозрительные пакеты
net.ipv4.conf.all.log_martians = 1

# Увеличить размер очереди
net.core.somaxconn = 65535
net.ipv4.tcp_max_tw_buckets = 1440000
EOF

sysctl -p

# --- Автоматические обновления ---
echo "==> Настройка автообновлений..."
cat > /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# --- Отключить ненужные сервисы ---
echo "==> Отключение ненужных сервисов..."
systemctl disable bluetooth 2>/dev/null || true
systemctl disable cups 2>/dev/null || true
systemctl disable avahi-daemon 2>/dev/null || true

# --- Защита важных файлов ---
echo "==> Защита файлов..."
chmod 700 /root
chmod 644 /etc/passwd
chmod 640 /etc/shadow

# --- Лимиты системы ---
echo "==> Настройка лимитов..."
cat >> /etc/security/limits.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc  65535
* hard nproc  65535
EOF

# --- Итог ---
SERVER_IP=$(curl -s ifconfig.me)

echo ""
echo "================================================"
echo "  ✓ СЕРВЕР ЗАЩИЩЁН"
echo "================================================"
echo ""
echo "  Хост:   $SERVER_IP"
echo "  Порт:   $SSH_PORT"
echo "  Юзер:   $USERNAME"
echo "  Вход:   По SSH ключу"
echo ""
echo "  Команда для входа:"
echo "  ssh -p $SSH_PORT -i id_rsa $USERNAME@$SERVER_IP"
echo ""
echo "================================================"
echo "  ПРИВАТНЫЙ SSH КЛЮЧ (сохрани его):"
echo "================================================"
echo ""
echo "$PRIVATE_KEY"
echo ""
echo "================================================"
echo "  Сохрани ключ в файл id_rsa и подключайся:"
echo "  chmod 600 id_rsa"
echo "  ssh -p $SSH_PORT -i id_rsa $USERNAME@$SERVER_IP"
echo "================================================"
echo ""
echo "  Что защищено:"
echo "  - SSH порт изменён с 22 на $SSH_PORT"
echo "  - Root логин отключён"
echo "  - Вход только по SSH ключу"
echo "  - UFW firewall включён (80, 443, 5000, $SSH_PORT)"
echo "  - Fail2Ban включён (бан на 24ч после 3 попыток)"
echo "  - Защита от SYN флуда"
echo "  - Автообновления безопасности"
echo "================================================"