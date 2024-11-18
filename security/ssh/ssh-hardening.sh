#!/bin/bash

# SSH Hardening Script
set -e

echo "Starting SSH hardening configuration..."

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Load environment variables
if [ -f ../.env ]; then
    source ../.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Backup original sshd_config
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cp /etc/ssh/sshd_config "/etc/ssh/sshd_config.backup_${TIMESTAMP}"

# Create new sshd_config
cat > /etc/ssh/sshd_config << EOL
# Security hardened sshd_config

# Basic SSH Protocol Configuration
Protocol 2
Port ${SSH_PORT:-22}

# Authentication
PermitRootLogin no
MaxAuthTries 3
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Key Exchange and Ciphers
KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com

# Login Restrictions
AllowUsers ${SSH_ALLOWED_USERS:-*}
LoginGraceTime 30
MaxStartups 3:50:10
MaxSessions 2

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Idle Timeout
ClientAliveInterval 300
ClientAliveCountMax 2

# Environment
AcceptEnv LANG LC_*
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
PermitTunnel no

# Banner
Banner /etc/ssh/banner
EOL

# Create SSH banner
cat > /etc/ssh/banner << EOL
***************************************************************************
NOTICE TO USERS

This computer system is for authorized use only. By using this system, you
consent to having all of your activities monitored and recorded by system
personnel. Unauthorized access or use may subject you to criminal prosecution.
***************************************************************************
EOL

# Set correct permissions
chmod 600 /etc/ssh/sshd_config
chmod 644 /etc/ssh/banner

# Create SSH key directory if it doesn't exist
if [ ! -d ~/.ssh ]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
fi

# Generate new host keys (optional, uncomment if needed)
# rm /etc/ssh/ssh_host_*
# ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ""
# ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""

# Restart SSH service
echo "Testing new SSH configuration..."
sshd -t || {
    echo "SSH configuration test failed. Rolling back..."
    mv "/etc/ssh/sshd_config.backup_${TIMESTAMP}" /etc/ssh/sshd_config
    exit 1
}

systemctl restart sshd

echo "SSH hardening completed successfully"

# Add to system logs
logger "SSH configuration hardened by setup script"

# Important notice
echo "
IMPORTANT: Make sure you have:
1. A working SSH key pair
2. Access to the server from another terminal
3. Sudo/root privileges

Test the new SSH configuration before closing this session!"