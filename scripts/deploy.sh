#!/bin/bash
set -e

# Configuration
CONFIG_DIR="/etc/vps-infrastructure"
ANSIBLE_DIR="/opt/vps-infrastructure/ansible"
LOG_FILE="/var/log/vps-infrastructure/deploy.log"
INVENTORY_FILE="$CONFIG_DIR/inventory.yml"

# Help message
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -h, --host HOST         Target host (IP or hostname)"
    echo "  -u, --user USER         SSH user"
    echo "  -k, --key KEY          SSH private key path"
    echo "  --help                 Show this help message"
    exit 1
}

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            TARGET_HOST="$2"
            shift 2
            ;;
        -u|--user)
            SSH_USER="$2"
            shift 2
            ;;
        -k|--key)
            SSH_KEY="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$TARGET_HOST" ] || [ -z "$SSH_USER" ] || [ -z "$SSH_KEY" ]; then
    echo "Error: Missing required arguments"
    usage
fi

# Create necessary directories
sudo mkdir -p "$CONFIG_DIR" "/var/log/vps-infrastructure"

# Generate inventory file
log "Generating Ansible inventory..."
cat > "$INVENTORY_FILE" << EOL
all:
  hosts:
    vps_host:
      ansible_host: $TARGET_HOST
      ansible_user: $SSH_USER
      ansible_ssh_private_key_file: $SSH_KEY
      ansible_python_interpreter: /usr/bin/python3
EOL

# Verify SSH connection
log "Verifying SSH connection..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER@$TARGET_HOST" echo "SSH connection successful" > /dev/null 2>&1; then
    log "Error: Unable to establish SSH connection"
    exit 1
fi

# Run Ansible playbooks
log "Running Ansible playbooks..."

# Common setup
log "Running common setup..."
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/playbooks/setup-host.yml" --tags common

# Security setup
log "Configuring security..."
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/playbooks/setup-host.yml" --tags security

# Network setup
log "Configuring networking..."
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/playbooks/setup-host.yml" --tags networking

# Virtualization setup
log "Setting up virtualization..."
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/playbooks/setup-host.yml" --tags virtualization

# Monitoring setup
log "Setting up monitoring..."
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/playbooks/setup-host.yml" --tags monitoring

# Backup setup
log "Configuring backup system..."
ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/playbooks/setup-host.yml" --tags backup

# Verify deployment
log "Verifying deployment..."

# Check system services
services=("libvirtd" "prometheus" "grafana-server" "alertmanager" "nginx")
for service in "${services[@]}"; do
    if ! ssh -i "$SSH_KEY" "$SSH_USER@$TARGET_HOST" "systemctl is-active $service" > /dev/null 2>&1; then
        log "Warning: Service $service is not running"
    fi
done

# Check monitoring endpoints
endpoints=("9090" "3000" "9093" "9100")
for port in "${endpoints[@]}"; do
    if ! nc -z "$TARGET_HOST" "$port"; then
        log "Warning: Port $port is not accessible"
    fi
done

# Check VM management
if ! ssh -i "$SSH_KEY" "$SSH_USER@$TARGET_HOST" "virsh list" > /dev/null 2>&1; then
    log "Warning: Unable to list VMs"
fi

# Final status
log "Deployment completed!"
log "Host: $TARGET_HOST"
log "Next steps:"
log "1. Access Grafana at http://$TARGET_HOST:3000"
log "2. Review monitoring alerts at http://$TARGET_HOST:9093"
log "3. Create VMs using the create-vm.sh script"
log "4. Configure backup schedules"
log "5. Review security settings"
