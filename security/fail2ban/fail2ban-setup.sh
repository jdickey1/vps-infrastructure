#!/bin/bash

# Fail2ban Setup and Configuration Script
set -e

echo "Starting Fail2ban configuration..."

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

# Install fail2ban if not installed
if ! command -v fail2ban-client >/dev/null 2>&1; then
    apt-get update
    apt-get install -y fail2ban
fi

# Stop fail2ban service to make changes
systemctl stop fail2ban

# Create jail.local configuration
cat > /etc/fail2ban/jail.local << EOL
[DEFAULT]
# Ban hosts for 24 hours
bantime = 86400
# Check for retry attempts over 10 minutes
findtime = 600
# Allow 5 retries before ban
maxretry = 5
# Email notifications
destemail = ${ADMIN_EMAIL:-root@localhost}
sender = ${ADMIN_EMAIL:-root@localhost}
# Action to take when banning
action = %(action_mwl)s

# SSH protection
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

# Web application protection
[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-badbots]
enabled = true
filter = nginx-badbots
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

# Rate limiting for repeated requests
[nginx-req-limit]
enabled = true
filter = nginx-req-limit
port = http,https
logpath = /var/log/nginx/error.log

# Protect against repeated login attempts
[nginx-login]
enabled = true
port = http,https
filter = nginx-login
logpath = /var/log/nginx/error.log
maxretry = 5

# PostgreSQL protection
[postgresql]
enabled = true
port = 5432
filter = postgresql
logpath = /var/log/postgresql/postgresql-*-main.log
EOL

# Create custom filter for login attempts if needed
cat > /etc/fail2ban/filter.d/nginx-login.conf << EOL
[Definition]
failregex = ^<HOST> -.*POST /api/login.*$
ignoreregex =
EOL

# Ensure fail2ban can read log files
chmod 644 /var/log/auth.log

# Start fail2ban service
systemctl start fail2ban
systemctl enable fail2ban

# Show status of all jails
echo "Checking jail status..."
fail2ban-client status

echo "Fail2ban configuration completed successfully"

# Add to system logs
logger "Fail2ban configuration updated by setup script"