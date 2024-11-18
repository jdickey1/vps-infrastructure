#!/bin/bash

# Prometheus Setup Script
set -e

echo "Starting Prometheus setup..."

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

# Create Prometheus user
useradd --no-create-home --shell /bin/false prometheus || true

# Create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# Download and install Prometheus
PROMETHEUS_VERSION="2.44.0"
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
tar xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

# Copy binaries
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus /usr/local/bin/
cp prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool /usr/local/bin/

# Copy config files
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/consoles /etc/prometheus
cp -r prometheus-${PROMETHEUS_VERSION}.linux-amd64/console_libraries /etc/prometheus

# Clean up downloaded files
rm -rf prometheus-${PROMETHEUS_VERSION}.linux-amd64*

# Create Prometheus configuration
cat > /etc/prometheus/prometheus.yml << EOL
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  scrape_timeout: 10s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

rule_files:
  - "alert-rules.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'nginx'
    static_configs:
      - targets: ['localhost:9113']

  - job_name: 'nextjs'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['localhost:3000']
EOL

# Copy alert rules
cp alert-rules.yml /etc/prometheus/

# Create systemd service
cat > /etc/systemd/system/prometheus.service << EOL
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
    --config.file /etc/prometheus/prometheus.yml \
    --storage.tsdb.path /var/lib/prometheus/ \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries \
    --web.listen-address=0.0.0.0:9090 \
    --web.enable-lifecycle

[Install]
WantedBy=multi-user.target
EOL

# Set ownership
chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

# Install node_exporter
echo "Installing node_exporter..."
NODE_EXPORTER_VERSION="1.5.0"
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -rf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64*

# Create node_exporter service
cat > /etc/systemd/system/node_exporter.service << EOL
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOL

# Install nginx-prometheus-exporter
echo "Installing nginx-prometheus-exporter..."
NGINX_EXPORTER_VERSION="0.11.0"
wget https://github.com/nginx/nginx-prometheus-exporter/releases/download/v${NGINX_EXPORTER_VERSION}/nginx-prometheus-exporter-${NGINX_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf nginx-prometheus-exporter-${NGINX_EXPORTER_VERSION}.linux-amd64.tar.gz
cp nginx-prometheus-exporter /usr/local/bin/
rm -rf nginx-prometheus-exporter*

# Create nginx-prometheus-exporter service
cat > /etc/systemd/system/nginx-prometheus-exporter.service << EOL
[Unit]
Description=Nginx Prometheus Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/nginx-prometheus-exporter \
    -nginx.scrape-uri=http://localhost/nginx_status

[Install]
WantedBy=multi-user.target
EOL

# Reload systemd and start services
systemctl daemon-reload
systemctl enable prometheus
systemctl enable node_exporter
systemctl enable nginx-prometheus-exporter
systemctl start prometheus
systemctl start node_exporter
systemctl start nginx-prometheus-exporter

echo "Prometheus setup completed!"

# Record setup in log
logger "Prometheus setup completed"

# Send notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Prometheus setup completed. Access at http://localhost:9090" | \
    mail -s "Prometheus Setup Notification" ${ADMIN_EMAIL}
fi