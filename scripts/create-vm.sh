#!/bin/bash
set -e

# Configuration
TEMPLATE_DIR="/var/lib/virt-templates"
TEMPLATE_IMAGE="ubuntu-22.04.qcow2"
VM_DIR="/var/lib/libvirt/images"
NETWORK_CONFIG="/etc/vps-infrastructure/network"
PROJECT_TEMPLATE="/usr/local/share/vm-template"

# Help message
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -n, --name NAME         VM name (required)"
    echo "  -m, --memory SIZE       Memory size in GB (default: 2)"
    echo "  -c, --cpus COUNT        Number of CPUs (default: 2)"
    echo "  -d, --disk SIZE         Disk size in GB (default: 20)"
    echo "  -p, --project NAME      Project name"
    echo "  -t, --type TYPE         Project type (nextjs)"
    echo "  -h, --help             Show this help message"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--name)
            VM_NAME="$2"
            shift 2
            ;;
        -m|--memory)
            MEMORY_GB="$2"
            shift 2
            ;;
        -c|--cpus)
            CPU_COUNT="$2"
            shift 2
            ;;
        -d|--disk)
            DISK_GB="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$VM_NAME" ]; then
    echo "Error: VM name is required"
    usage
fi

# Set defaults
MEMORY_GB=${MEMORY_GB:-2}
CPU_COUNT=${CPU_COUNT:-2}
DISK_GB=${DISK_GB:-20}
PROJECT_TYPE=${PROJECT_TYPE:-"nextjs"}

# Convert memory to MB
MEMORY_MB=$((MEMORY_GB * 1024))

# Create VM directory
VM_PATH="$VM_DIR/$VM_NAME"
mkdir -p "$VM_PATH"

echo "Creating VM: $VM_NAME"
echo "Memory: ${MEMORY_GB}GB"
echo "CPUs: $CPU_COUNT"
echo "Disk: ${DISK_GB}GB"
if [ -n "$PROJECT_NAME" ]; then
    echo "Project: $PROJECT_NAME ($PROJECT_TYPE)"
fi

# Create VM disk
echo "Creating disk image..."
qemu-img create -f qcow2 -o backing_file="$TEMPLATE_DIR/$TEMPLATE_IMAGE" \
    "$VM_PATH/disk.qcow2" "${DISK_GB}G"

# Generate cloud-init config
cat > "$VM_PATH/cloud-init.yml" << EOL
#cloud-config
hostname: $VM_NAME
manage_etc_hosts: true
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - $(cat ~/.ssh/id_rsa.pub)
package_update: true
package_upgrade: true
packages:
  - qemu-guest-agent
  - python3
  - python3-pip
  - git
  - curl
  - wget
  - htop
  - net-tools
power_state:
  mode: reboot
EOL

# Create cloud-init ISO
echo "Generating cloud-init ISO..."
cloud-localds "$VM_PATH/cloud-init.iso" "$VM_PATH/cloud-init.yml"

# Create VM
echo "Creating VM..."
virt-install \
    --name "$VM_NAME" \
    --memory "$MEMORY_MB" \
    --vcpus "$CPU_COUNT" \
    --disk "$VM_PATH/disk.qcow2",format=qcow2,bus=virtio \
    --disk "$VM_PATH/cloud-init.iso",device=cdrom \
    --os-variant ubuntu22.04 \
    --virt-type kvm \
    --graphics none \
    --network bridge=br0,model=virtio \
    --noautoconsole \
    --import

# Wait for VM to boot
echo "Waiting for VM to boot..."
sleep 30

# Get VM IP
VM_IP=$(virsh domifaddr "$VM_NAME" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" || true)
while [ -z "$VM_IP" ]; do
    sleep 5
    VM_IP=$(virsh domifaddr "$VM_NAME" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" || true)
done

echo "VM IP address: $VM_IP"

# Setup project if specified
if [ -n "$PROJECT_NAME" ]; then
    echo "Setting up project: $PROJECT_NAME"
    
    # Wait for SSH to be available
    until ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "ubuntu@$VM_IP" echo ready 2>/dev/null
    do
        echo "Waiting for SSH..."
        sleep 5
    done
    
    # Copy project template
    echo "Copying project template..."
    scp -r "$PROJECT_TEMPLATE" "ubuntu@$VM_IP:/home/ubuntu/$PROJECT_NAME"
    
    # Run project setup
    echo "Running project setup..."
    ssh -t "ubuntu@$VM_IP" "cd /home/ubuntu/$PROJECT_NAME && ./setup.sh \
        --project $PROJECT_NAME \
        --type $PROJECT_TYPE"
fi

# Update monitoring
echo "Updating monitoring configuration..."
/usr/local/bin/update-vm-targets

echo "VM creation completed successfully!"
echo "VM Name: $VM_NAME"
echo "IP Address: $VM_IP"
if [ -n "$PROJECT_NAME" ]; then
    echo "Project: $PROJECT_NAME"
    echo "Type: $PROJECT_TYPE"
fi
