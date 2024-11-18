#!/bin/bash

# System Updates Script
set -e

echo "Starting system updates..."

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

# Load environment variables
if [ -f ../.env ]; then
    source ../.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Configuration
LOG_FILE="/var/log/system-updates.log"
BACKUP_BEFORE_UPDATE=${BACKUP_BEFORE_UPDATE:-true}
REBOOT_IF_REQUIRED=${REBOOT_IF_REQUIRED:-false}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
    echo "$1"
}

# Function to check if reboot is required
check_reboot_required() {
    if [ -f /var/run/reboot-required ]; then
        return 0
    else
        return 1
    fi
}

# Function to create system snapshot
create_snapshot() {
    log_message "Creating system snapshot..."
    
    # Create backup directory
    SNAPSHOT_DIR="/var/backups/system/${PROJECT_NAME}/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "${SNAPSHOT_DIR}"
    
    # Backup important configurations
    cp -r /etc/nginx "${SNAPSHOT_DIR}/"
    cp -r /etc/postgresql "${SNAPSHOT_DIR}/"
    cp -r /etc/systemd/system "${SNAPSHOT_DIR}/"
    cp -r /etc/letsencrypt "${SNAPSHOT_DIR}/"
    
    # Backup package list
    dpkg --get-selections > "${SNAPSHOT_DIR}/package_list.txt"
    
    # Create archive
    tar -czf "${SNAPSHOT_DIR}.tar.gz" "${SNAPSHOT_DIR}"
    rm -rf "${SNAPSHOT_DIR}"
    
    log_message "System snapshot created: ${SNAPSHOT_DIR}.tar.gz"
}

# Function to update package lists
update_packages() {
    log_message "Updating package lists..."
    apt-get update
    
    # Check for errors
    if [ $? -ne 0 ]; then
        log_message "Error updating package lists"
        return 1
    fi
}

# Function to upgrade packages
upgrade_packages() {
    log_message "Upgrading packages..."
    
    # Perform upgrade
    DEBIAN_FRONTEND=noninteractive apt-get \
        -o Dpkg::Options::="--force-confdef" \
        -o Dpkg::Options::="--force-confold" \
        dist-upgrade -y
    
    # Check for errors
    if [ $? -ne 0 ]; then
        log_message "Error upgrading packages"
        return 1
    fi
}

# Function to clean up after update
cleanup() {
    log_message "Cleaning up..."
    apt-get autoremove -y
    apt-get autoclean
}

# Function to update Node.js packages
update_nodejs() {
    if command -v npm &> /dev/null; then
        log_message "Updating Node.js packages..."
        
        # Update npm itself
        npm install -g npm@latest
        
        # Update global packages
        npm update -g
    fi
}

# Function to verify critical services
verify_services() {
    log_message "Verifying critical services..."
    
    services=("nginx" "postgresql" "grafana-server" "prometheus" "fail2ban")
    failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "${service}"; then
            log_message "${service} is running"
        else
            log_message "WARNING: ${service} is not running"
            failed_services+=("${service}")
        fi
    done
    
    return ${#failed_services[@]}
}

# Main update routine
log_message "Starting system update process..."

# Create snapshot if enabled
if [ "${BACKUP_BEFORE_UPDATE}" = "true" ]; then
    create_snapshot
fi

# Perform updates
if update_packages; then
    if upgrade_packages; then
        cleanup
        update_nodejs
        
        # Verify services
        verify_services
        
        # Check if reboot is required
        if check_reboot_required; then
            log_message "System requires a reboot"
            
            if [ "${REBOOT_IF_REQUIRED}" = "true" ]; then
                log_message "Automatic reboot is enabled. Rebooting in 1 minute..."
                
                # Send notification before reboot
                if [ ! -z "${ADMIN_EMAIL}" ]; then
                    echo "System is rebooting after updates. Check ${LOG_FILE} for details." | \
                    mail -s "System Update - Reboot Notification" ${ADMIN_EMAIL}
                fi
                
                # Schedule reboot
                shutdown -r +1
            else
                log_message "Automatic reboot is disabled. Please reboot the system manually."
                
                # Send notification about pending reboot
                if [ ! -z "${ADMIN_EMAIL}" ]; then
                    echo "System update completed. Manual reboot required. Check ${LOG_FILE} for details." | \
                    mail -s "System Update - Reboot Required" ${ADMIN_EMAIL}
                fi
            fi
        else
            log_message "No reboot required"
            
            # Send completion notification
            if [ ! -z "${ADMIN_EMAIL}" ]; then
                echo "System update completed successfully. Check ${LOG_FILE} for details." | \
                mail -s "System Update Completed" ${ADMIN_EMAIL}
            fi
        fi
    else
        log_message "Update failed during package upgrade"
        
        # Send failure notification
        if [ ! -z "${ADMIN_EMAIL}" ]; then
            echo "System update failed during package upgrade. Check ${LOG_FILE} for details." | \
            mail -s "System Update Failed" ${ADMIN_EMAIL}
        fi
        
        exit 1
    fi
else
    log_message "Update failed during package list update"
    
    # Send failure notification
    if [ ! -z "${ADMIN_EMAIL}" ]; then
        echo "System update failed during package list update. Check ${LOG_FILE} for details." | \
        mail -s "System Update Failed" ${ADMIN_EMAIL}
    fi
    
    exit 1
fi

log_message "System update process completed"