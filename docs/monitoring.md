# Monitoring Setup Guide

This guide covers the setup and configuration of the centralized monitoring infrastructure.

## Overview

The monitoring stack consists of:
- Prometheus (Metrics collection)
- Grafana (Visualization)
- AlertManager (Alerting)
- Node Exporter (System metrics)
- Various exporters for services

## Prerequisites

- Ubuntu 22.04 LTS
- At least 2GB RAM for monitoring stack
- 20GB available disk space
- Port 3000 (Grafana)
- Port 9090 (Prometheus)
- Port 9093 (AlertManager)

## Prometheus Setup

### Installation

```bash
# Create prometheus user
useradd --no-create-home --shell /bin/false prometheus

# Create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# Download and install Prometheus
cd /tmp
curl -LO https://github.com/prometheus/prometheus/releases/download/v2.40.0/prometheus-2.40.0.linux-amd64.tar.gz
tar xvf prometheus-*.tar.gz

# Copy binaries
cp prometheus-*/prometheus /usr/local/bin/
cp prometheus-*/promtool /usr/local/bin/

# Copy config files
cp -r prometheus-*/consoles /etc/prometheus
cp -r prometheus-*/console_libraries /etc/prometheus
```

### Configuration

```yaml
# /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['localhost:9093']

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
```

### Systemd Service

```ini
# /etc/systemd/system/prometheus.service
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
    --storage.tsdb.path /var/lib/prometheus \
    --web.console.templates=/etc/prometheus/consoles \
    --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
```

## Grafana Setup

### Installation

```bash
# Add Grafana repository
apt-get install -y software-properties-common
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | apt-key add -

# Install Grafana
apt-get update
apt-get install -y grafana
```

### Configuration

```ini
# /etc/grafana/grafana.ini
[server]
http_port = 3000
domain = your-domain.com
root_url = https://your-domain.com/grafana/

[security]
admin_user = admin
disable_gravatar = true
cookie_secure = true

[auth.anonymous]
enabled = false

[smtp]
enabled = true
host = smtp.gmail.com:587
user = your-email@gmail.com
password = your-app-specific-password
```

### Dashboards

```bash
# Import dashboards
cd /var/lib/grafana/dashboards
cp /path/to/infrastructure/monitoring/grafana/dashboards/*.json .

# Set permissions
chown -R grafana:grafana /var/lib/grafana/dashboards
```

## AlertManager Setup

### Installation

```bash
# Create alertmanager user
useradd --no-create-home --shell /bin/false alertmanager

# Create directories
mkdir -p /etc/alertmanager
mkdir -p /var/lib/alertmanager

# Download and install AlertManager
cd /tmp
curl -LO https://github.com/prometheus/alertmanager/releases/download/v0.24.0/alertmanager-0.24.0.linux-amd64.tar.gz
tar xvf alertmanager-*.tar.gz

# Copy binary
cp alertmanager-*/alertmanager /usr/local/bin/
```

### Configuration

```yaml
# /etc/alertmanager/alertmanager.yml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alertmanager@your-domain.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-specific-password'

route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'email-notifications'

receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'admin@your-domain.com'
    send_resolved: true
```

### Alert Rules

```yaml
# /etc/prometheus/rules/alerts.yml
groups:
- name: host
  rules:
  - alert: HighCPULoad
    expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100) > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High CPU load

  - alert: HighMemoryUsage
    expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: High memory usage
```

## Node Exporter Setup

### Installation

```bash
# Create node_exporter user
useradd --no-create-home --shell /bin/false node_exporter

# Download and install Node Exporter
cd /tmp
curl -LO https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz
tar xvf node_exporter-*.tar.gz

# Copy binary
cp node_exporter-*/node_exporter /usr/local/bin/
```

### Systemd Service

```ini
# /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
```

## Integration Tests

### Test Prometheus

```bash
# Test configuration
promtool check config /etc/prometheus/prometheus.yml

# Test rules
promtool check rules /etc/prometheus/rules/*.yml
```

### Test AlertManager

```bash
# Test configuration
amtool check-config /etc/alertmanager/alertmanager.yml

# Test alerts
amtool alert add alertname=TestAlert severity=warning
```

### Test Grafana

```bash
# Test datasource
curl -H "Content-Type: application/json" \
     -H "Authorization: Bearer your-api-key" \
     http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up

# Test dashboard access
curl -H "Authorization: Bearer your-api-key" \
     http://localhost:3000/api/dashboards/home
```

## Maintenance

### Backup Configuration

```bash
# Backup monitoring configuration
./monitoring/backup-config.sh

# Verify backup
./monitoring/verify-backup.sh
```

### Update Procedures

```bash
# Update monitoring stack
./monitoring/update-stack.sh

# Verify after update
./monitoring/verify-stack.sh
```

## Troubleshooting

### Common Issues

1. **Prometheus not scraping targets**
   ```bash
   # Check targets
   curl localhost:9090/api/v1/targets
   ```

2. **AlertManager not sending alerts**
   ```bash
   # Check config
   amtool config show
   ```

3. **Grafana can't connect to Prometheus**
   ```bash
   # Check datasource
   curl -H "Authorization: Bearer your-api-key" \
        http://localhost:3000/api/datasources
   ```

## Support

For monitoring issues:
1. Check service logs
2. Review metrics
3. Contact monitoring team
