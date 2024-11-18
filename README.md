# VPS Infrastructure

A comprehensive, provider-neutral infrastructure for managing multiple virtual machines and web applications.

## Overview

This project provides a complete infrastructure setup for hosting multiple web applications in isolated virtual machines. It's designed to work with any VPS provider or bare metal server, using KVM/libvirt for virtualization.

## Features

### Infrastructure Management
- Provider-neutral deployment using Ansible
- KVM/libvirt-based virtualization
- Automated VM creation and management
- Centralized monitoring and alerting
- Automated backup system
- Comprehensive security configuration

### Security
- Firewall configuration with fail2ban
- SELinux/AppArmor profiles
- Security auditing with auditd
- SSL/TLS management
- Network isolation
- Intrusion detection

### Monitoring
- Prometheus metrics collection
- Grafana dashboards
- AlertManager notifications
- Node exporter for system metrics
- Custom alert rules
- Performance monitoring

### VM Management
- Template-based VM creation
- Resource allocation control
- Network configuration
- Storage management
- Backup coordination
- Health monitoring

## Prerequisites

- Ubuntu 22.04 LTS host system
- KVM/libvirt support
- Ansible 2.9+
- Terraform 1.0+
- Python 3.8+

## Directory Structure

```
.
├── ansible/                    # Ansible configuration
│   ├── playbooks/             # Main playbooks
│   └── roles/                 # Role definitions
├── docs/                      # Documentation
│   ├── security.md           # Security guide
│   ├── monitoring.md         # Monitoring guide
│   ├── backup.md            # Backup guide
│   └── maintenance.md       # Maintenance procedures
├── monitoring/                # Monitoring configuration
│   ├── prometheus/          # Prometheus setup
│   ├── grafana/            # Grafana dashboards
│   └── alertmanager/       # AlertManager config
├── scripts/                   # Management scripts
│   ├── create-vm.sh        # VM creation
│   └── deploy.sh           # Deployment script
├── security/                  # Security configuration
│   ├── fail2ban/           # Fail2ban rules
│   └── audit/              # Audit rules
└── terraform/                 # Infrastructure as Code
    ├── modules/            # Terraform modules
    ├── main.tf            # Main configuration
    └── variables.tf       # Variable definitions
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/vps-infrastructure.git
cd vps-infrastructure
```

2. Configure the environment:
```bash
cp .env.example .env
# Edit .env with your settings
```

3. Deploy the infrastructure:
```bash
./scripts/deploy.sh -h HOST -u USER -k /path/to/ssh/key
```

## VM Creation

Create a new VM with the template:

```bash
./scripts/create-vm.sh -n vm-name -m 2 -c 2 -d 20 -p project-name -t nextjs
```

Options:
- `-n, --name`: VM name (required)
- `-m, --memory`: Memory size in GB (default: 2)
- `-c, --cpus`: Number of CPUs (default: 2)
- `-d, --disk`: Disk size in GB (default: 20)
- `-p, --project`: Project name
- `-t, --type`: Project type (nextjs)

## Security

The infrastructure implements multiple layers of security:

1. Network Security
   - Firewall rules
   - Network isolation
   - Rate limiting
   - DDoS protection

2. System Security
   - SELinux/AppArmor
   - Fail2ban
   - Security auditing
   - Regular updates

3. Application Security
   - SSL/TLS encryption
   - Secure headers
   - Access control
   - Input validation

## Monitoring

The monitoring stack includes:

1. Metrics Collection
   - System metrics
   - Application metrics
   - Network metrics
   - Custom metrics

2. Visualization
   - System dashboards
   - Application dashboards
   - Network dashboards
   - Custom dashboards

3. Alerting
   - System alerts
   - Application alerts
   - Custom alert rules
   - Multiple notification channels

## Maintenance

Regular maintenance tasks are automated:

1. System Updates
   - Security updates
   - Package updates
   - Kernel updates

2. Backups
   - System backups
   - VM backups
   - Database backups
   - Configuration backups

3. Monitoring
   - Health checks
   - Performance monitoring
   - Security monitoring
   - Log monitoring

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.
