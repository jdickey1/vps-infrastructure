#!/bin/bash

# System Health Check Script
set -e

echo "Starting system health check..."

# Load environment variables
if [ -f ../.env ]; then
    source ../.env
else
    echo "Error: .env file not found"
    exit 1
fi

# Configuration
LOG_FILE="/var/log/health-check.log"
HEALTH_STATUS="/var/log/health-status.json"
CPU_THRESHOLD=${CPU_THRESHOLD:-80}
MEMORY_THRESHOLD=${MEMORY_THRESHOLD:-80}
DISK_THRESHOLD=${DISK_THRESHOLD:-80}

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
    echo "$1"
}

# Function to update health status
update_status() {
    local component=$1
    local status=$2
    local details=$3
    
    # Create or update status file
    if [ ! -f "${HEALTH_STATUS}" ]; then
        echo "{}" > "${HEALTH_STATUS}"
    fi
    
    # Update status using temporary file
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local temp_file=$(mktemp)
    
    jq --arg comp "$component" \
       --arg stat "$status" \
       --arg det "$details" \
       --arg ts "$timestamp" \
       '.[$comp] = {"status": $stat, "details": $det, "timestamp": $ts}' \
       "${HEALTH_STATUS}" > "$temp_file"
    
    mv "$temp_file" "${HEALTH_STATUS}"
}

# Function to check CPU usage
check_cpu() {
    log_message "Checking CPU usage..."
    
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
    
    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        update_status "cpu" "warning" "High CPU usage: ${cpu_usage}%"
        return 1
    else
        update_status "cpu" "healthy" "CPU usage: ${cpu_usage}%"
        return 0
    fi
}

# Function to check memory usage
check_memory() {
    log_message "Checking memory usage..."
    
    local memory_usage=$(free | grep Mem | awk '{print ($3/$2) * 100}' | cut -d. -f1)
    
    if [ "$memory_usage" -gt "$MEMORY_THRESHOLD" ]; then
        update_status "memory" "warning" "High memory usage: ${memory_usage}%"
        return 1
    else
        update_status "memory" "healthy" "Memory usage: ${memory_usage}%"
        return 0
    fi
}

# Function to check disk usage
check_disk() {
    log_message "Checking disk usage..."
    
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        update_status "disk" "warning" "High disk usage: ${disk_usage}%"
        return 1
    else
        update_status "disk" "healthy" "Disk usage: ${disk_usage}%"
        return 0
    fi
}

# Function to check system load
check_load() {
    log_message "Checking system load..."
    
    local load=$(uptime | awk -F'load average:' '{ print $2 }' | cut -d, -f1 | tr -d ' ')
    local cores=$(nproc)
    local load_per_core=$(echo "$load / $cores" | bc -l)
    
    if (( $(echo "$load_per_core > 1" | bc -l) )); then
        update_status "load" "warning" "High system load: $load (per core: ${load_per_core})"
        return 1
    else
        update_status "load" "healthy" "System load: $load (per core: ${load_per_core})"
        return 0
    fi
}

# Function to check service status
check_services() {
    log_message "Checking service status..."
    
    local services=("nginx" "postgresql" "grafana-server" "prometheus" "fail2ban")
    local failed_services=()
    
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet "$service"; then
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        update_status "services" "healthy" "All services running"
        return 0
    else
        update_status "services" "critical" "Failed services: ${failed_services[*]}"
        return 1
    fi
}

# Function to check application health
check_application() {
    log_message "Checking application health..."
    
    local app_url="https://${DOMAIN}/health"
    local response=$(curl -s -o /dev/null -w "%{http_code}" "$app_url")
    
    if [ "$response" = "200" ]; then
        update_status "application" "healthy" "Application responding normally"
        return 0
    else
        update_status "application" "critical" "Application returned status code: $response"
        return 1
    fi
}

# Function to check SSL certificate
check_ssl() {
    log_message "Checking SSL certificate..."
    
    local domain="${DOMAIN}"
    local port=443
    local expiry=$(openssl s_client -connect "${domain}:${port}" -servername "${domain}" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "${expiry}" +%s)
    local current_epoch=$(date +%s)
    local days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if [ "$days_remaining" -lt 30 ]; then
        update_status "ssl" "warning" "SSL certificate expires in ${days_remaining} days"
        return 1
    else
        update_status "ssl" "healthy" "SSL certificate valid for ${days_remaining} days"
        return 0
    fi
}

# Function to check database connection
check_database() {
    log_message "Checking database connection..."
    
    if PGPASSWORD="${DB_PASSWORD}" psql -h localhost -U "${DB_USER:-nextjs}" -d "${DB_NAME:-nextjs}" -c '\q' 2>/dev/null; then
        update_status "database" "healthy" "Database connection successful"
        return 0
    else
        update_status "database" "critical" "Database connection failed"
        return 1
    fi
}

# Main health check routine
log_message "Starting health check process..."

# Perform all checks
check_cpu
check_memory
check_disk
check_load
check_services
check_application
check_ssl
check_database

# Calculate overall status
critical_count=$(jq '[.[].status] | map(select(. == "critical")) | length' "${HEALTH_STATUS}")
warning_count=$(jq '[.[].status] | map(select(. == "warning")) | length' "${HEALTH_STATUS}")

if [ "$critical_count" -gt 0 ]; then
    overall_status="critical"
elif [ "$warning_count" -gt 0 ]; then
    overall_status="warning"
else
    overall_status="healthy"
fi

# Update overall status
update_status "overall" "$overall_status" "Critical: $critical_count, Warning: $warning_count"

log_message "Health check completed with status: $overall_status"

# Send notification if there are issues
if [ "$overall_status" != "healthy" ] && [ ! -z "${ADMIN_EMAIL}" ]; then
    jq -r '. | to_entries | .[] | select(.value.status != "healthy") | "\(.key): \(.value.status) - \(.value.details)"' "${HEALTH_STATUS}" | \
    mail -s "System Health Check Alert - ${overall_status}" ${ADMIN_EMAIL}
fi

# Output status in JSON format
cat "${HEALTH_STATUS}"