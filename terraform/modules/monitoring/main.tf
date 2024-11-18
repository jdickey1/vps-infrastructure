# Monitoring module configuration

# Prometheus server
resource "libvirt_domain" "prometheus" {
  name = "prometheus-server"
  
  # Resource limits
  memory = 2048
  vcpu = 2
  
  # Disk configuration
  disk {
    volume_id = var.prometheus_volume_id
    scsi = true
  }
  
  # Network configuration
  network_interface {
    network_id = var.network_id
    addresses = [var.prometheus_ip]
  }
  
  # Cloud-init configuration
  cloudinit = var.cloudinit_id
}

# Grafana server
resource "libvirt_domain" "grafana" {
  name = "grafana-server"
  
  # Resource limits
  memory = 1024
  vcpu = 1
  
  # Disk configuration
  disk {
    volume_id = var.grafana_volume_id
    scsi = true
  }
  
  # Network configuration
  network_interface {
    network_id = var.network_id
    addresses = [var.grafana_ip]
  }
  
  # Cloud-init configuration
  cloudinit = var.cloudinit_id
}

# AlertManager server
resource "libvirt_domain" "alertmanager" {
  name = "alertmanager-server"
  
  # Resource limits
  memory = 1024
  vcpu = 1
  
  # Disk configuration
  disk {
    volume_id = var.alertmanager_volume_id
    scsi = true
  }
  
  # Network configuration
  network_interface {
    network_id = var.network_id
    addresses = [var.alertmanager_ip]
  }
  
  # Cloud-init configuration
  cloudinit = var.cloudinit_id
}

# Node exporter configuration
resource "null_resource" "node_exporter" {
  count = var.vm_count
  
  triggers = {
    vm_ids = join(",", var.vm_ids)
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y prometheus-node-exporter",
      "systemctl enable prometheus-node-exporter",
      "systemctl start prometheus-node-exporter"
    ]
  }
}

# Prometheus configuration
resource "null_resource" "prometheus_config" {
  triggers = {
    prometheus_id = libvirt_domain.prometheus.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y prometheus",
      "cat > /etc/prometheus/prometheus.yml << 'EOL'",
      "${file("${path.module}/files/prometheus.yml")}",
      "EOL",
      "systemctl restart prometheus"
    ]
  }
}

# Grafana configuration
resource "null_resource" "grafana_config" {
  triggers = {
    grafana_id = libvirt_domain.grafana.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y grafana",
      "cat > /etc/grafana/grafana.ini << 'EOL'",
      "${file("${path.module}/files/grafana.ini")}",
      "EOL",
      "systemctl restart grafana-server"
    ]
  }
}

# AlertManager configuration
resource "null_resource" "alertmanager_config" {
  triggers = {
    alertmanager_id = libvirt_domain.alertmanager.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y prometheus-alertmanager",
      "cat > /etc/prometheus/alertmanager.yml << 'EOL'",
      "${file("${path.module}/files/alertmanager.yml")}",
      "EOL",
      "systemctl restart prometheus-alertmanager"
    ]
  }
}

# Monitoring dashboard setup
resource "null_resource" "grafana_dashboards" {
  depends_on = [null_resource.grafana_config]
  
  triggers = {
    grafana_id = libvirt_domain.grafana.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /var/lib/grafana/dashboards",
      "cat > /var/lib/grafana/dashboards/node_exporter.json << 'EOL'",
      "${file("${path.module}/files/dashboards/node_exporter.json")}",
      "EOL",
      "cat > /var/lib/grafana/dashboards/nginx.json << 'EOL'",
      "${file("${path.module}/files/dashboards/nginx.json")}",
      "EOL",
      "cat > /var/lib/grafana/dashboards/postgres.json << 'EOL'",
      "${file("${path.module}/files/dashboards/postgres.json")}",
      "EOL",
      "chown -R grafana:grafana /var/lib/grafana/dashboards"
    ]
  }
}

# Monitoring alerts setup
resource "null_resource" "prometheus_alerts" {
  depends_on = [null_resource.prometheus_config]
  
  triggers = {
    prometheus_id = libvirt_domain.prometheus.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /etc/prometheus/rules",
      "cat > /etc/prometheus/rules/node.rules.yml << 'EOL'",
      "${file("${path.module}/files/rules/node.rules.yml")}",
      "EOL",
      "cat > /etc/prometheus/rules/nginx.rules.yml << 'EOL'",
      "${file("${path.module}/files/rules/nginx.rules.yml")}",
      "EOL",
      "cat > /etc/prometheus/rules/postgres.rules.yml << 'EOL'",
      "${file("${path.module}/files/rules/postgres.rules.yml")}",
      "EOL",
      "systemctl restart prometheus"
    ]
  }
}
