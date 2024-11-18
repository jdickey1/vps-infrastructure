# Backup module configuration

# Backup storage pool
resource "libvirt_pool" "backup" {
  name = "backup-pool"
  type = "dir"
  path = var.backup_path
}

# VM snapshot management
resource "null_resource" "snapshot_manager" {
  triggers = {
    vm_ids = join(",", var.vm_ids)
  }

  provisioner "local-exec" {
    command = "mkdir -p ${var.backup_path}/{snapshots,data,logs}"
  }
}

# Backup coordinator service
resource "libvirt_domain" "backup_coordinator" {
  name = "backup-coordinator"
  memory = "512"
  vcpu = 1

  disk {
    volume_id = var.coordinator_volume_id
  }

  network_interface {
    network_id = var.network_id
    addresses  = [var.coordinator_ip]
  }
}

# Backup automation configuration
resource "null_resource" "backup_config" {
  triggers = {
    coordinator_id = libvirt_domain.backup_coordinator.id
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/backup-coordinator/config.d",
      "cat > /etc/backup-coordinator/config.yml << 'EOL'",
      "backup:",
      "  retention:",
      "    snapshots: ${var.snapshot_retention_days}",
      "    data: ${var.data_retention_days}",
      "  schedule:",
      "    snapshots: '0 2 * * *'",
      "    data: '0 3 * * *'",
      "  paths:",
      "    snapshots: ${var.backup_path}/snapshots",
      "    data: ${var.backup_path}/data",
      "    logs: ${var.backup_path}/logs",
      "  compression: ${var.compression_type}",
      "  encryption: ${var.encryption_enabled}",
      "  notification:",
      "    enabled: true",
      "    channels: ${jsonencode(var.notification_channels)}",
      "EOL",
      "systemctl restart backup-coordinator"
    ]
  }
}

# Snapshot management scripts
resource "null_resource" "snapshot_scripts" {
  triggers = {
    coordinator_id = libvirt_domain.backup_coordinator.id
  }

  provisioner "file" {
    source      = "${path.module}/files/scripts/"
    destination = "/usr/local/bin/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /usr/local/bin/snapshot-*",
      "ln -sf /usr/local/bin/snapshot-create /etc/cron.daily/",
      "ln -sf /usr/local/bin/snapshot-cleanup /etc/cron.weekly/"
    ]
  }
}

# Backup verification service
resource "null_resource" "backup_verify" {
  triggers = {
    coordinator_id = libvirt_domain.backup_coordinator.id
  }

  provisioner "remote-exec" {
    inline = [
      "cat > /usr/local/bin/verify-backups << 'EOL'",
      "#!/bin/bash",
      "set -e",
      "# Verify snapshot integrity",
      "find ${var.backup_path}/snapshots -type f -name '*.qcow2' -exec qemu-img check {} \\;",
      "# Verify data backup integrity",
      "find ${var.backup_path}/data -type f -name '*.tar.gz' -exec tar -tzf {} > /dev/null \\;",
      "# Check backup logs",
      "find ${var.backup_path}/logs -type f -name '*.log' -mtime -1 -exec grep -l 'ERROR\\|FAIL' {} \\;",
      "EOL",
      "chmod +x /usr/local/bin/verify-backups",
      "ln -sf /usr/local/bin/verify-backups /etc/cron.daily/"
    ]
  }
}

# Backup monitoring integration
resource "null_resource" "backup_monitoring" {
  triggers = {
    coordinator_id = libvirt_domain.backup_coordinator.id
  }

  provisioner "remote-exec" {
    inline = [
      "cat > /etc/prometheus/targets/backup.yml << 'EOL'",
      "- targets:",
      "  - '${var.coordinator_ip}:9100'",
      "  labels:",
      "    job: backup-coordinator",
      "    service: backup",
      "EOL",
      "systemctl reload prometheus"
    ]
  }
}
