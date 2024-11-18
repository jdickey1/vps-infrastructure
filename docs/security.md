# Security Configuration Guide

This guide covers the security configuration and best practices for the VPS infrastructure.

## Overview

The security system consists of multiple layers:
- Host-level firewall (UFW)
- Intrusion prevention (Fail2ban)
- SSH hardening
- Network security
- Access control
- Monitoring and alerts

## Firewall Configuration

### UFW Setup

The firewall is configured with a default deny policy:

```bash
# Check current rules
ufw status verbose

# Default rules
ufw default deny incoming
ufw default allow outgoing
```

### Standard Allowed Ports

```bash
# SSH (rate-limited)
ufw limit 22/tcp

# HTTP/HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Monitoring
ufw allow 3000/tcp  # Grafana
ufw allow 9090/tcp  # Prometheus (internal only)
ufw allow 9093/tcp  # AlertManager (internal only)
```

### Rate Limiting

```bash
# Configure rate limiting
ufw limit ssh comment 'Rate limit SSH'
ufw limit 80/tcp comment 'Rate limit HTTP'
ufw limit 443/tcp comment 'Rate limit HTTPS'
```

## Fail2ban Configuration

### Jail Configuration

```ini
# /etc/fail2ban/jail.local
[DEFAULT]
bantime = 86400        # 24 hours
findtime = 600         # 10 minutes
maxretry = 3          # 3 retries

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
```

### Custom Filters

```ini
# /etc/fail2ban/filter.d/nginx-custom.conf
[Definition]
failregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" 444 0 ".*"
ignoreregex =
```

## SSH Hardening

### SSH Configuration

```ini
# /etc/ssh/sshd_config
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

### Key Management

```bash
# Generate new host keys
cd /etc/ssh/
rm ssh_host_*
ssh-keygen -t rsa -b 4096 -f ssh_host_rsa_key
ssh-keygen -t ed25519 -f ssh_host_ed25519_key
```

## Network Security

### TCP Wrappers

```bash
# /etc/hosts.allow
sshd: 10.0.0.0/8, 192.168.0.0/16

# /etc/hosts.deny
ALL: ALL
```

### System Hardening

```bash
# Kernel parameters (/etc/sysctl.conf)
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
```

## Access Control

### User Management

```bash
# Create admin group
groupadd admins

# Add user to admin group
usermod -aG admins username

# Configure sudo access
visudo
%admins ALL=(ALL) ALL
```

### File Permissions

```bash
# Secure important directories
chmod 750 /etc/ssh
chmod 600 /etc/ssh/*_key
chmod 644 /etc/ssh/*.pub
```

## Monitoring & Alerts

### Security Monitoring

```yaml
# /etc/prometheus/rules/security.yml
groups:
  - name: security
    rules:
      - alert: HighFailedLogins
        expr: rate(failed_logins_total[5m]) > 10
        for: 5m
        labels:
          severity: critical
```

### Log Monitoring

```bash
# Configure log monitoring
./monitoring/setup-log-monitoring.sh

# Test alerts
./monitoring/test-security-alerts.sh
```

## Regular Security Tasks

### Daily Tasks
- Review auth logs
- Check failed login attempts
- Monitor system resources

### Weekly Tasks
- Review firewall rules
- Check Fail2ban status
- Update security patches

### Monthly Tasks
- Full security audit
- Review user access
- Update security policies

## Incident Response

### Security Incident Procedure

1. **Detect**
   ```bash
   # Check for suspicious activity
   ./security/check-suspicious.sh
   ```

2. **Contain**
   ```bash
   # Block suspicious IPs
   ./security/block-ip.sh [IP_ADDRESS]
   ```

3. **Investigate**
   ```bash
   # Gather forensics
   ./security/collect-forensics.sh
   ```

4. **Recover**
   ```bash
   # Restore from clean backup
   ./backup/restore-clean.sh
   ```

## Security Updates

### Automated Updates

```bash
# Configure unattended upgrades
apt install unattended-upgrades
dpkg-reconfigure unattended-upgrades

# Test update system
unattended-upgrade --dry-run
```

### Manual Updates

```bash
# Update security components
./security/update-security.sh

# Verify after updates
./security/verify-security.sh
```

## Backup Security

### Backup Encryption

```bash
# Generate backup key
gpg --full-generate-key

# Configure backup encryption
./backup/configure-encryption.sh
```

### Secure Transfer

```bash
# Configure secure transfer
./backup/configure-transfer.sh

# Test secure transfer
./backup/test-transfer.sh
```

## Documentation

Keep security documentation updated:
```bash
# Generate security report
./security/generate-report.sh

# Update documentation
./security/update-docs.sh
```

## Support

For security issues:
1. Check security logs
2. Review incident playbooks
3. Contact security team

## Host Security

### Firewall Configuration
- Provider-neutral firewall using libvirt
- Default deny-all policy
- Explicit allow rules for required services
- Rate limiting on critical services
- DDoS protection configuration
- Logging of suspicious activities

### System Hardening
- SELinux/AppArmor mandatory access control
- System service isolation
- Resource limits and quotas
- Regular security updates
- Kernel hardening parameters
- File system security

### Access Control
- SSH key-based authentication only
- Fail2ban for brute force protection
- IP allowlisting for critical services
- Strong password policies
- Regular access auditing
- Session management

## Network Security

### Network Isolation
- Separate network bridges for VMs
- VLAN segregation
- Network access control lists
- Traffic monitoring
- Intrusion detection
- Secure DNS configuration

### SSL/TLS Configuration
- Automated certificate management
- Strong cipher configuration
- Perfect forward secrecy
- HSTS implementation
- OCSP stapling
- Certificate pinning

### Traffic Management
- Rate limiting
- Load balancing
- Traffic monitoring
- Anomaly detection
- DDoS mitigation
- Bandwidth control

## VM Security

### VM Isolation
- Resource isolation
- Network isolation
- Storage isolation
- Process isolation
- Memory protection
- Secure boot

### Application Security
- Secure deployment process
- Regular dependency updates
- Security headers configuration
- Input validation
- Output encoding
- Error handling

### Data Security
- Encrypted storage
- Secure backup system
- Data access controls
- Audit logging
- Data retention policies
- Secure deletion

## Monitoring and Auditing

### Security Monitoring
- Real-time threat detection
- Log analysis
- Performance monitoring
- Resource monitoring
- Network monitoring
- Access monitoring

### Audit System
- System call auditing
- File system monitoring
- Network activity logging
- User action tracking
- Configuration changes
- Security events

### Alert System
- Real-time security alerts
- Incident response triggers
- Escalation procedures
- Alert prioritization
- False positive handling
- Alert aggregation

## Maintenance and Updates

### Update Management
- Security patch management
- Dependency updates
- System updates
- Application updates
- Configuration updates
- Rollback procedures

### Security Testing
- Regular security scans
- Vulnerability assessments
- Penetration testing
- Configuration review
- Access control testing
- Update verification

### Incident Response
- Response procedures
- Containment strategies
- Investigation process
- Recovery procedures
- Documentation requirements
- Post-incident review

## Implementation

### Initial Setup
```bash
# Deploy security configuration
./scripts/deploy.sh -h HOST -u USER -k /path/to/ssh/key --tags security

# Verify security settings
./scripts/security-check.sh
```

### Security Updates
```bash
# Update security configurations
./scripts/update-security.sh

# Apply security patches
./scripts/apply-patches.sh
```

### Monitoring Setup
```bash
# Configure security monitoring
./scripts/setup-monitoring.sh --security

# Verify monitoring
./scripts/verify-monitoring.sh
```

## Best Practices

1. Regular Security Reviews
   - Weekly security updates
   - Monthly configuration review
   - Quarterly security assessment
   - Annual penetration testing

2. Access Management
   - Regular access review
   - Key rotation
   - Password updates
   - Permission audit

3. Monitoring and Alerts
   - 24/7 monitoring
   - Alert verification
   - Response procedures
   - Escalation paths

4. Documentation
   - Configuration documentation
   - Change management
   - Incident response
   - Recovery procedures

## Security Checklist

- [ ] Firewall configuration
- [ ] SSH hardening
- [ ] SELinux/AppArmor setup
- [ ] Fail2ban configuration
- [ ] SSL/TLS configuration
- [ ] Network isolation
- [ ] Monitoring setup
- [ ] Backup configuration
- [ ] Update management
- [ ] Audit system

## Troubleshooting

### Common Issues
1. Firewall blocks legitimate traffic
2. SSL certificate issues
3. Access control problems
4. Monitoring alerts
5. Update failures

### Resolution Steps
1. Check security logs
2. Verify configurations
3. Test connectivity
4. Review permissions
5. Validate updates
