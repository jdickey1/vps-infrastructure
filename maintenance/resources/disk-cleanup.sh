#!/bin/bash

# Disk Cleanup Script
set -e

echo "Starting disk cleanup..."

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
DISK_THRESHOLD=${DISK_THRESHOLD:-85}  # Cleanup when disk usage is above this percentage
LOG_FILE="/var/log/disk-cleanup.log"
BACKUP_DIR="/var/backups"
DEPLOY_DIR="/var/www/${PROJECT_NAME}/releases"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
    echo "$1"
}

# Function to check disk usage
check_disk_usage() {
    local partition=$1
    df -h "$partition" | awk 'NR==2 {print $5}' | sed 's/%//'
}

# Function to get disk usage in human-readable format
get_disk_info() {
    log_message "Current disk usage:"
    df -h / | awk 'NR==2 {print "Total: " $2 ", Used: " $3 ", Available: " $4 ", Usage: " $5}'
}

# Function to clean package manager cache
clean_package_cache() {
    log_message "Cleaning package manager cache..."
    apt-get clean
    apt-get autoremove -y
    apt-get autoclean
}

# Function to clean old log files
clean_logs() {
    log_message "Cleaning old log files..."
    
    # Find and remove log files older than 30 days
    find /var/log -type f -name "*.log.*" -mtime +30 -delete
    find /var/log -type f -name "*.gz" -mtime +30 -delete
    
    # Clean empty log files
    find /var/log -type f -empty -delete
}

# Function to clean temporary files
clean_temp_files() {
    log_message "Cleaning temporary files..."
    
    # Clean /tmp directory (files older than 7 days)
    find /tmp -type f -atime +7 -delete
    
    # Clean /var/tmp directory (files older than 30 days)
    find /var/tmp -type f -atime +30 -delete
}

# Function to clean old deployment releases
clean_old_releases() {
    log_message "Cleaning old deployment releases..."
    
    if [ -d "${DEPLOY_DIR}" ]; then
        # Keep only the last 5 releases
        cd "${DEPLOY_DIR}"
        ls -t | tail -n +6 | xargs -r rm -rf
    fi
}

# Function to clean old backups
clean_old_backups() {
    log_message "Cleaning old backups..."
    
    if [ -d "${BACKUP_DIR}" ]; then
        # Remove database backups older than 90 days
        find "${BACKUP_DIR}/postgresql" -type f -mtime +90 -delete
        
        # Remove application backups older than 30 days
        find "${BACKUP_DIR}/${PROJECT_NAME}" -type f -mtime +30 -delete
    fi
}

# Function to clean Docker resources (if Docker is installed)
clean_docker() {
    if command -v docker &> /dev/null; then
        log_message "Cleaning Docker resources..."
        
        # Remove unused containers, networks, images, and volumes
        docker system prune -af --volumes
        
        # Remove dangling images
        docker image prune -f
        
        # Remove unused volumes
        docker volume prune -f
    fi
}

# Function to clean npm cache (if Node.js is installed)
clean_npm_cache() {
    if command -v npm &> /dev/null; then
        log_message "Cleaning npm cache..."
        npm cache clean --force
    fi
}

# Main cleanup routine
log_message "Starting disk cleanup process..."

# Get initial disk usage
get_disk_info

# Check if cleanup is needed
CURRENT_USAGE=$(check_disk_usage "/")
if [ "${CURRENT_USAGE}" -gt "${DISK_THRESHOLD}" ]; then
    log_message "Disk usage is above threshold (${CURRENT_USAGE}% > ${DISK_THRESHOLD}%)"
    
    # Perform cleanup tasks
    clean_package_cache
    clean_logs
    clean_temp_files
    clean_old_releases
    clean_old_backups
    clean_docker
    clean_npm_cache
    
    # Get final disk usage
    get_disk_info
    
    # Send notification if disk usage is still high
    FINAL_USAGE=$(check_disk_usage "/")
    if [ "${FINAL_USAGE}" -gt "${DISK_THRESHOLD}" ]; then
        if [ ! -z "${ADMIN_EMAIL}" ]; then
            echo "WARNING: Disk usage is still high (${FINAL_USAGE}%) after cleanup" | \
            mail -s "High Disk Usage Warning" ${ADMIN_EMAIL}
        fi
    fi
else
    log_message "Disk usage is within acceptable limits (${CURRENT_USAGE}% <= ${DISK_THRESHOLD}%)"
fi

log_message "Disk cleanup completed"

# Send completion notification
if [ ! -z "${ADMIN_EMAIL}" ]; then
    echo "Disk cleanup completed. Check ${LOG_FILE} for details." | \
    mail -s "Disk Cleanup Notification" ${ADMIN_EMAIL}
fi