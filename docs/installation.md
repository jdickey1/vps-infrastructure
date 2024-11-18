# VPS Infrastructure Installation Guide

This guide covers the complete installation and setup of the VPS infrastructure management system.

## Prerequisites

Before beginning the installation, ensure you have:

- Ubuntu 22.04 LTS VPS with:
  - Minimum 4GB RAM
  - At least 50GB storage
  - Root access
  - Public IP address
- Domain name pointed to the VPS
- SSH access configured
- Basic understanding of Linux administration

## Step-by-Step Installation

### 1. Initial Server Setup

```bash
# Update system
apt update && apt upgrade -y

# Set timezone
timedatectl set-timezone UTC

# Install essential packages
apt install -y curl wget git unzip htop net-tools
```

### 2. Clone Repository

```bash
git clone https://github.com/yourusername/vps-infrastructure.git
cd vps-infrastructure
```

### 3. Configure Environment

```bash
cp .env.example .env
nano .env
```

Required variables:
```env
VPS_HOSTNAME=vps.example.com
ADMIN_EMAIL=admin@example.com
BACKUP_STORAGE=/var/backups/vms
MONITORING_PORT=3000
```

### 4. Security Setup

```bash
# Run security installation
cd security
./firewall/ufw-setup.sh
./ssh/ssh-hardening.sh
./fail2ban/fail2ban-setup.sh
```

### 5. Monitoring Infrastructure

```bash
# Install monitoring stack
cd ../monitoring
./prometheus/prometheus-setup.sh
./grafana/grafana-setup.sh
./alertmanager/setup.sh
```

### 6. Backup System

```bash
# Set up backup infrastructure
cd ../backup
./coordinator/setup.sh
./storage/setup.sh
```

### 7. Maintenance System

```bash
# Configure maintenance tasks
cd ../maintenance
./updates/setup.sh
./resources/setup.sh
```

## Post-Installation Steps

### 1. Verify Services

Check that all services are running:
```bash
systemctl status prometheus
systemctl status grafana-server
systemctl status alertmanager
```

### 2. Access Monitoring

Access your monitoring dashboards:
- Grafana: https://your-vps-ip:3000
- Prometheus: http://your-vps-ip:9090
- AlertManager: http://your-vps-ip:9093

### 3. Configure Firewall

Verify firewall rules:
```bash
ufw status verbose
```

### 4. Test Backup System

Verify backup system:
```bash
cd /var/backups/vms
ls -la
```

## Security Considerations

1. **SSH Access**
   - Use SSH keys only
   - Disable password authentication
   - Configure proper permissions

2. **Firewall Rules**
   - Only necessary ports open
   - Rate limiting enabled
   - DDoS protection configured

3. **Monitoring Access**
   - Set strong admin passwords
   - Configure SSL/TLS
   - Implement access controls

## Troubleshooting

### Common Issues

1. **Service Won't Start**
   ```bash
   # Check service logs
   journalctl -u service-name -f
   ```

2. **Firewall Issues**
   ```bash
   # Check UFW logs
   tail -f /var/log/ufw.log
   ```

3. **Monitoring Access Issues**
   ```bash
   # Check Nginx logs
   tail -f /var/log/nginx/error.log
   ```

## Next Steps

1. Set up individual VMs using the vm-template
2. Configure monitoring for each VM
3. Set up backup schedules
4. Configure alerting rules

## Maintenance Mode

To perform maintenance:
```bash
# Enable maintenance mode
./maintenance/enable-maintenance.sh

# Disable maintenance mode
./maintenance/disable-maintenance.sh
```

## Backup Recovery

Test backup recovery:
```bash
# List available backups
./backup/coordinator/list-backups.sh

# Test recovery
./backup/coordinator/test-recovery.sh
```

## Support

If you encounter issues:
1. Check service logs
2. Review documentation
3. Contact system administrator

## Updates

Keep the system updated:
```bash
# Update infrastructure
./maintenance/updates/update-infrastructure.sh

# Update monitoring
./maintenance/updates/update-monitoring.sh
```
