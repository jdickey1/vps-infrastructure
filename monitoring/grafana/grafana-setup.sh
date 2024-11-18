#!/bin/bash

# Grafana Setup Script
set -e

echo "Starting Grafana setup..."

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found"
    exit 1
fi

# Install Grafana
echo "Installing Grafana..."
apt-get install -y apt-transport-https software-properties-common
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" | tee /etc/apt/sources.list.d/grafana.list
apt-get update
apt-get install -y grafana

# Create Grafana configuration
cat > /etc/grafana/grafana.ini << EOL
[server]
protocol = http
http_addr = localhost
http_port = 3000

[security]
admin_user = admin
admin_password = ${GRAFANA_ADMIN_PASSWORD:-admin}
allow_embedding = true

[auth.anonymous]
enabled = false

[smtp]
enabled = ${SMTP_ENABLED:-false}
host = ${SMTP_HOST:-localhost:25}
user = ${SMTP_USER}
password = ${SMTP_PASSWORD}
from_address = ${ADMIN_EMAIL}

[alerting]
enabled = true
execute_alerts = true

[unified_alerting]
enabled = true
EOL

# Create Grafana provisioning directories
mkdir -p /etc/grafana/provisioning/{datasources,dashboards}

# Configure Prometheus datasource
cat > /etc/grafana/provisioning/datasources/prometheus.yml << EOL
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: false
EOL

# Configure dashboard provider
cat > /etc/grafana/provisioning/dashboards/default.yml << EOL
apiVersion: 1

providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: true
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOL

# Create dashboards directory
mkdir -p /var/lib/grafana/dashboards

# Copy dashboard files
cp dashboards/*.json /var/lib/grafana/dashboards/

# Set permissions
chown -R grafana:grafana /var/lib/grafana/dashboards

# Start and enable Grafana
systemctl enable grafana-server
systemctl start grafana-server

# Wait for Grafana to start
echo "Waiting for Grafana to start..."
sleep 10

# Create API key for automated operations
GRAFANA_API_KEY=$(curl -X POST -H "Content-Type: application/json" \
    -d '{"name":"automation", "role": "Admin"}' \
    http://admin:${GRAFANA_ADMIN_PASSWORD:-admin}@localhost:3000/api/auth/keys | jq -r '.key')

# Save API key to environment file
if [ ! -z "$GRAFANA_API_KEY" ]; then
    echo "GRAFANA_API_KEY=${GRAFANA_API_KEY}" >> .env
fi

echo "Grafana setup completed!"

# Configure basic auth if enabled
if [ "${GRAFANA_BASIC_AUTH:-false}" = "true" ]; then
    echo "Configuring basic auth..."
    htpasswd -c /etc/nginx/grafana.htpasswd ${GRAFANA_USER:-admin}
fi

# Record setup in log
logger "Grafana setup completed"

# Send notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Grafana setup completed. Access at https://${DOMAIN}:3000" | \
    mail -s "Grafana Setup Notification" ${ADMIN_EMAIL}
fi