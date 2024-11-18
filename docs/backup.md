# Backup Management Guide

This guide covers the centralized backup system for managing backups across all VMs.

## Overview

The backup system consists of:
- Centralized backup storage
- Backup coordination
- Automated verification
- Secure transfer
- Retention management

## Architecture

```
/var/backups/vms/
├── vm1/
│   ├── daily/
│   ├── weekly/
│   └── monthly/
├── vm2/
│   ├── daily/
│   ├── weekly/
│   └── monthly/
└── shared/
    ├── configs/
    └── ssl/
```

## Prerequisites

- Dedicated backup storage volume
- SSH key authentication
- GPG for encryption
- Sufficient storage space
- Network bandwidth

## Backup Storage Setup

### Storage Preparation

```bash
# Create backup directories
mkdir -p /var/backups/vms/{shared,configs,ssl}

# Set permissions
chmod 700 /var/backups/vms
chown backup:backup /var/backups/vms
```

### Mount Points

```bash
# /etc/fstab
UUID=backup-volume-uuid /var/backups/vms ext4 defaults,noatime 0 2
```

## Backup Coordination

### Configuration

```yaml
# /etc/backup-coordinator/config.yml
global:
  backup_root: /var/backups/vms
  retention:
    daily: 7
    weekly: 4
    monthly: 3
  encryption:
    enabled: true
    key_id: your-gpg-key-id

vms:
  - name: vm1
    type: nextjs
    database: true
    priority: high
  
  - name: vm2
    type: nextjs
    database: true
    priority: medium
```

### Schedule Setup

```bash
# /etc/cron.d/backup-coordinator
# Daily backups at 1 AM
0 1 * * * backup /usr/local/bin/backup-coordinator daily

# Weekly backups on Sunday at 2 AM
0 2 * * 0 backup /usr/local/bin/backup-coordinator weekly

# Monthly backups on 1st at 3 AM
0 3 1 * * backup /usr/local/bin/backup-coordinator monthly
```

## Backup Process

### Pre-backup Checks

```bash
# Check available space
./backup/check-space.sh

# Verify backup targets
./backup/verify-targets.sh

# Test connectivity
./backup/test-connectivity.sh
```

### Backup Execution

```bash
# Full backup process
./backup/coordinator/backup.sh --type=full --vm=vm1

# Database only backup
./backup/coordinator/backup.sh --type=db --vm=vm1

# Configuration backup
./backup/coordinator/backup.sh --type=config --vm=all
```

### Post-backup Tasks

```bash
# Verify backups
./backup/verify-backups.sh

# Clean old backups
./backup/clean-old-backups.sh

# Send notifications
./backup/send-notifications.sh
```

## Encryption

### Key Management

```bash
# Generate backup key
gpg --full-generate-key

# Export public key
gpg --export -a "Backup Key" > backup_pub.key

# Distribute to VMs
./backup/distribute-keys.sh
```

### Encryption Process

```bash
# Encrypt backup
gpg --encrypt --recipient "Backup Key" backup.tar

# Verify encrypted file
gpg --list-packets backup.tar.gpg
```

## Secure Transfer

### SSH Configuration

```bash
# /etc/ssh/sshd_config.d/backup.conf
Match User backup
    PasswordAuthentication no
    PermitRootLogin no
    X11Forwarding no
    AllowTcpForwarding no
    ForceCommand /usr/local/bin/backup-receiver
```

### Transfer Process

```bash
# Secure copy
./backup/secure-copy.sh --source=/path/to/backup --dest=vm1

# Verify transfer
./backup/verify-transfer.sh --backup=backup.tar.gpg
```

## Retention Management

### Retention Rules

```yaml
# /etc/backup-coordinator/retention.yml
rules:
  daily:
    keep_last: 7
    keep_daily: 7
  weekly:
    keep_last: 4
    keep_weekly: 4
  monthly:
    keep_last: 3
    keep_monthly: 3
```

### Cleanup Process

```bash
# Clean old backups
./backup/clean-old.sh --type=daily

# Verify after cleanup
./backup/verify-retention.sh
```

## Recovery Procedures

### Full Recovery

```bash
# Restore full VM
./backup/restore.sh --vm=vm1 --type=full --date=2023-01-01

# Verify restoration
./backup/verify-restore.sh --vm=vm1
```

### Partial Recovery

```bash
# Restore specific files
./backup/restore.sh --vm=vm1 --type=files --path=/etc/nginx

# Restore database
./backup/restore.sh --vm=vm1 --type=db --date=2023-01-01
```

## Monitoring & Reporting

### Backup Status

```bash
# Check backup status
./backup/status.sh --vm=all

# Generate report
./backup/generate-report.sh
```

### Alerts

```yaml
# /etc/prometheus/rules/backup.yml
groups:
  - name: backup
    rules:
      - alert: BackupFailed
        expr: backup_status == 0
        for: 1h
        labels:
          severity: critical
```

## Maintenance

### Regular Tasks

```bash
# Test recovery
./backup/test-recovery.sh --schedule=weekly

# Verify integrity
./backup/verify-integrity.sh --all

# Update configurations
./backup/update-configs.sh
```

### Troubleshooting

Common issues and solutions:

1. **Backup Failed**
   ```bash
   # Check logs
   tail -f /var/log/backup-coordinator/backup.log
   
   # Check space
   df -h /var/backups/vms
   ```

2. **Transfer Issues**
   ```bash
   # Test connectivity
   ./backup/test-connection.sh --vm=vm1
   
   # Check SSH keys
   ./backup/verify-keys.sh
   ```

3. **Encryption Problems**
   ```bash
   # Verify keys
   gpg --list-keys
   
   # Test encryption
   ./backup/test-encryption.sh
   ```

## Support

For backup issues:
1. Check backup logs
2. Review error notifications
3. Contact backup team
