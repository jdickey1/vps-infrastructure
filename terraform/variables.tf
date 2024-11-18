# Variables for VPS infrastructure

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "libvirt_uri" {
  description = "Libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "network_name" {
  description = "Name of the main network"
  type        = string
  default     = "vps-network"
}

variable "domain_name" {
  description = "Domain name for the infrastructure"
  type        = string
}

variable "network_cidr" {
  description = "CIDR block for the main network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "management_cidr" {
  description = "CIDR block for the management network"
  type        = string
  default     = "10.1.0.0/16"
}

variable "storage_cidr" {
  description = "CIDR block for the storage network"
  type        = string
  default     = "10.2.0.0/16"
}

variable "admin_cidr" {
  description = "CIDR block for admin access"
  type        = string
}

variable "inbound_average" {
  description = "Average inbound bandwidth (bytes/s)"
  type        = number
  default     = 1000000
}

variable "inbound_peak" {
  description = "Peak inbound bandwidth (bytes/s)"
  type        = number
  default     = 2000000
}

variable "inbound_burst" {
  description = "Burst inbound bandwidth (bytes/s)"
  type        = number
  default     = 5000000
}

variable "outbound_average" {
  description = "Average outbound bandwidth (bytes/s)"
  type        = number
  default     = 1000000
}

variable "outbound_peak" {
  description = "Peak outbound bandwidth (bytes/s)"
  type        = number
  default     = 2000000
}

variable "outbound_burst" {
  description = "Burst outbound bandwidth (bytes/s)"
  type        = number
  default     = 5000000
}

variable "storage_pool_path" {
  description = "Path for the storage pool"
  type        = string
  default     = "/var/lib/libvirt/images"
}

variable "base_image_source" {
  description = "Source path for the base Ubuntu image"
  type        = string
}

variable "backup_path" {
  description = "Path for backups"
  type        = string
  default     = "/var/lib/vps-backup"
}

variable "snapshot_retention_days" {
  description = "Number of days to retain snapshots"
  type        = number
  default     = 7
}

variable "data_retention_days" {
  description = "Number of days to retain data backups"
  type        = number
  default     = 30
}

variable "compression_type" {
  description = "Compression type for backups"
  type        = string
  default     = "gzip"
}

variable "encryption_enabled" {
  description = "Enable backup encryption"
  type        = bool
  default     = true
}

variable "prometheus_retention_days" {
  description = "Number of days to retain Prometheus metrics"
  type        = number
  default     = 15
}

variable "grafana_admin_password" {
  description = "Admin password for Grafana"
  type        = string
  sensitive   = true
}

variable "dns_server_ip" {
  description = "IP address for DNS server"
  type        = string
}

variable "load_balancer_ip" {
  description = "IP address for load balancer"
  type        = string
}

variable "load_balancer_mgmt_ip" {
  description = "Management IP address for load balancer"
  type        = string
}

variable "notification_channels" {
  description = "List of notification channels"
  type        = list(object({
    type    = string
    target  = string
    enabled = bool
  }))
  default = []
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 90
}

variable "alertmanager_slack_webhook" {
  description = "Slack webhook URL for AlertManager"
  type        = string
  sensitive   = true
}

variable "ssh_allowed_ips" {
  description = "List of IP addresses allowed to SSH"
  type        = list(string)
  default     = []
}

variable "monitoring_allowed_ips" {
  description = "List of IP addresses allowed to access monitoring"
  type        = list(string)
  default     = []
}

variable "vm_instance_count" {
  description = "Number of VM instances to create"
  type        = number
  default     = 2
}

variable "enable_bastion" {
  description = "Whether to create a bastion host"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
