#!/bin/bash

# UFW Setup and Configuration Script
set -e

echo "Starting UFW configuration..."

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

# Install UFW if not installed
if ! command -v ufw >/dev/null 2>&1; then
    apt-get update
    apt-get install -y ufw
fi

# Reset UFW to default state
echo "Resetting UFW to default state..."
ufw --force reset

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Allow SSH (port 22)
ufw allow ssh

# Allow HTTP and HTTPS
ufw allow http
ufw allow https

# Allow Grafana if monitoring is enabled (default port 3000)
if [ "${ENABLE_MONITORING:-true}" = "true" ]; then
    ufw allow 3000/tcp comment 'Grafana'
fi

# Allow PostgreSQL from specific IPs if defined
if [ ! -z "${POSTGRES_ALLOWED_IPS}" ]; then
    IFS=',' read -ra IPS <<< "${POSTGRES_ALLOWED_IPS}"
    for ip in "${IPS[@]}"; do
        ufw allow from $ip to any port 5432 proto tcp comment 'PostgreSQL'
    done
fi

# Additional custom ports if defined
if [ ! -z "${ADDITIONAL_PORTS}" ]; then
    IFS=',' read -ra PORTS <<< "${ADDITIONAL_PORTS}"
    for port in "${PORTS[@]}"; do
        ufw allow $port comment 'Custom port'
    done
fi

# Rate limiting for SSH
ufw limit ssh comment 'Rate limit SSH'

# Enable UFW
echo "Enabling UFW..."
ufw --force enable

# Show status
ufw status verbose

echo "UFW configuration completed successfully"

# Add to system logs
logger "UFW configuration updated by setup script"