# System Maintenance Guide

This guide covers the maintenance procedures for the VPS infrastructure and its VMs.

## Overview

The maintenance system manages:
- System updates
- Resource management
- Performance optimization
- Security patches
- Health monitoring
- Log management

## Maintenance Schedule

### Daily Tasks
- Health checks
- Log rotation
- Backup verification
- Performance monitoring

### Weekly Tasks
- Security updates
- Resource cleanup
- Service checks
- Backup tests

### Monthly Tasks
- Full system updates
- Performance tuning
- Security audits
- Capacity planning

## System Updates

### Update Configuration

```yaml
# /etc/maintenance/update-config.yml
global:
  update_hour: 3  # 3 AM
  reboot_allowed: true
  notify_email: admin@example.com
  
priorities:
  security: immediate
  system: weekly
  applications: monthly

notifications:
  slack: true
  email: true
  webhook: true
```

### Security Updates

```bash
# Configure unattended upgrades
cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOL
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::Mail "admin@example.com";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOL
```

### Update Process

```bash
# Run system updates
./maintenance/updates/update-system.sh --type=security

# Verify after updates
./maintenance/updates/verify-updates.sh

# Generate update report
./maintenance/updates/generate-report.sh
```

## Resource Management

### Disk Space

```bash
# Configure disk cleanup
cat > /etc/maintenance/disk-cleanup.conf << EOL
paths:
  - path: /var/log
    max_age: 30
    exclude: ['*.gz']
  
  - path: /tmp
    max_age: 7
    exclude: []
  
  - path: /var/cache/apt
    action: clean
EOL
```

### Memory Management

```bash
# Configure memory limits
cat > /etc/maintenance/memory-limits.conf << EOL
services:
  nginx:
    max_memory: 2G
    restart_on_exceed: true
  
  prometheus:
    max_memory: 4G
    restart_on_exceed: false
EOL
```

### Process Management

```bash
# Configure process limits
cat > /etc/maintenance/process-limits.conf << EOL
limits:
  nginx:
    nofile: 65535
    nproc: 65535
  
  postgres:
    nofile: 65535
    nproc: 65535
EOL
```

## Performance Optimization

### System Tuning

```bash
# Configure system limits
cat > /etc/sysctl.d/99-performance.conf << EOL
# Network optimization
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_keepalive_time = 300

# File system
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288

# VM settings
vm.swappiness = 10
vm.dirty_ratio = 60
vm.dirty_background_ratio = 2
EOL
```

### Service Optimization

```bash
# Nginx optimization
cat > /etc/nginx/conf.d/performance.conf << EOL
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 65535;
    multi_accept on;
    use epoll;
}

http {
    keepalive_timeout 65;
    keepalive_requests 100;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
}
EOL
```

## Health Monitoring

### System Health Checks

```bash
# Configure health checks
cat > /etc/maintenance/health-checks.yml << EOL
checks:
  - name: disk_space
    threshold: 80
    action: cleanup
  
  - name: memory_usage
    threshold: 85
    action: notify
  
  - name: cpu_load
    threshold: 90
    action: throttle
EOL
```

### Service Health Checks

```bash
# Configure service checks
cat > /etc/maintenance/service-checks.yml << EOL
services:
  - name: nginx
    port: 80
    timeout: 5
    retry: 3
  
  - name: postgresql
    port: 5432
    timeout: 5
    retry: 3
EOL
```

## Log Management

### Log Rotation

```bash
# Configure log rotation
cat > /etc/logrotate.d/maintenance << EOL
/var/log/maintenance/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 syslog adm
    sharedscripts
    postrotate
        systemctl reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOL
```

### Log Aggregation

```bash
# Configure log shipping
cat > /etc/filebeat/filebeat.yml << EOL
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/maintenance/*.log
    - /var/log/system/*.log

output.elasticsearch:
  hosts: ["localhost:9200"]
  index: "maintenance-%{+yyyy.MM.dd}"
EOL
```

## Automation

### Cron Jobs

```bash
# Configure maintenance schedule
cat > /etc/cron.d/maintenance << EOL
# Daily health check
0 * * * * root /usr/local/bin/maintenance-check health

# Daily cleanup
0 2 * * * root /usr/local/bin/maintenance-cleanup

# Weekly updates
0 3 * * 0 root /usr/local/bin/maintenance-update

# Monthly optimization
0 4 1 * * root /usr/local/bin/maintenance-optimize
EOL
```

### Automation Scripts

```bash
# Create maintenance wrapper
cat > /usr/local/bin/maintenance << EOL
#!/bin/bash
set -e

case "\$1" in
    check)
        ./maintenance/health-check.sh
        ;;
    cleanup)
        ./maintenance/cleanup.sh
        ;;
    update)
        ./maintenance/update.sh
        ;;
    optimize)
        ./maintenance/optimize.sh
        ;;
    *)
        echo "Usage: \$0 {check|cleanup|update|optimize}"
        exit 1
        ;;
esac
EOL
chmod +x /usr/local/bin/maintenance
```

## Troubleshooting

### Common Issues

1. **High Resource Usage**
   ```bash
   # Check system resources
   ./maintenance/check-resources.sh
   
   # Identify top processes
   ./maintenance/top-processes.sh
   ```

2. **Service Failures**
   ```bash
   # Check service status
   ./maintenance/check-services.sh
   
   # View service logs
   ./maintenance/view-logs.sh --service=nginx
   ```

3. **Update Failures**
   ```bash
   # Check update logs
   ./maintenance/check-update-logs.sh
   
   # Retry updates
   ./maintenance/retry-updates.sh
   ```

## Reporting

### System Reports

```bash
# Generate system report
./maintenance/generate-report.sh --type=system

# Generate performance report
./maintenance/generate-report.sh --type=performance
```

### Maintenance Reports

```bash
# Generate maintenance summary
./maintenance/generate-summary.sh

# Generate detailed report
./maintenance/generate-report.sh --detailed
```

## Support

For maintenance issues:
1. Check maintenance logs
2. Review system status
3. Contact maintenance team
