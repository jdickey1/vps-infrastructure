# Main Terraform configuration for VPS infrastructure

terraform {
  required_version = ">= 1.0.0"
  
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
      version = "~> 0.7.0"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

# Network configuration
resource "libvirt_network" "vm_network" {
  name = "vm_network"
  mode = "nat"
  domain = var.domain_name
  addresses = [var.network_cidr]
  
  dhcp {
    enabled = true
  }
  
  dns {
    enabled = true
    local_only = true
  }
}

# Storage pool configuration
resource "libvirt_pool" "vm_pool" {
  name = "vm_pool"
  type = "dir"
  path = var.storage_pool_path
}

# Base image
resource "libvirt_volume" "base_image" {
  name = "base-ubuntu-22.04"
  pool = libvirt_pool.vm_pool.name
  source = var.base_image_source
  format = "qcow2"
}

# Security group configuration
module "security" {
  source = "./modules/security"
  
  domain_name = var.domain_name
  environment = var.environment
}

# Monitoring configuration
module "monitoring" {
  source = "./modules/monitoring"
  
  domain_name = var.domain_name
  environment = var.environment
  prometheus_retention_days = var.prometheus_retention_days
}

# Backup configuration
module "backup" {
  source = "./modules/backup"
  
  domain_name = var.domain_name
  environment = var.environment
  backup_retention_days = var.backup_retention_days
}

# DNS configuration
module "dns" {
  source = "./modules/dns"
  
  domain_name = var.domain_name
  environment = var.environment
}
