# Network module configuration

# Main network bridge
resource "libvirt_network" "main" {
  name      = var.network_name
  mode      = "nat"
  domain    = var.domain_name
  addresses = [var.network_cidr]
  
  dhcp {
    enabled = true
  }
  
  dns {
    enabled    = true
    local_only = false
  }
}

# Management network
resource "libvirt_network" "management" {
  name      = "${var.network_name}-mgmt"
  mode      = "route"
  domain    = "mgmt.${var.domain_name}"
  addresses = [var.management_cidr]
  
  dhcp {
    enabled = false
  }
}

# Storage network
resource "libvirt_network" "storage" {
  name      = "${var.network_name}-storage"
  mode      = "route"
  domain    = "storage.${var.domain_name}"
  addresses = [var.storage_cidr]
  
  dhcp {
    enabled = false
  }
}

# Network ACLs
resource "libvirt_network_acl" "main" {
  network_id = libvirt_network.main.id
  
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = [80, 443]
    action    = "accept"
  }
  
  rule {
    direction = "in"
    protocol  = "tcp"
    port      = 22
    source    = var.admin_cidr
    action    = "accept"
  }
}

# Network QoS
resource "libvirt_network_qos" "main" {
  network_id = libvirt_network.main.id
  
  inbound {
    average = var.inbound_average
    peak    = var.inbound_peak
    burst   = var.inbound_burst
  }
  
  outbound {
    average = var.outbound_average
    peak    = var.outbound_peak
    burst   = var.outbound_burst
  }
}

# Load balancer configuration
resource "libvirt_domain" "load_balancer" {
  name   = "load-balancer"
  memory = "1024"
  vcpu   = 2
  
  network_interface {
    network_id = libvirt_network.main.id
    addresses  = [var.load_balancer_ip]
  }
  
  network_interface {
    network_id = libvirt_network.management.id
    addresses  = [var.load_balancer_mgmt_ip]
  }
  
  disk {
    volume_id = var.load_balancer_volume_id
  }
}

# HAProxy configuration
resource "null_resource" "haproxy_config" {
  triggers = {
    load_balancer_id = libvirt_domain.load_balancer.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y haproxy",
      "cat > /etc/haproxy/haproxy.cfg << 'EOL'",
      "global",
      "  log /dev/log local0",
      "  chroot /var/lib/haproxy",
      "  stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners",
      "  stats timeout 30s",
      "  user haproxy",
      "  group haproxy",
      "  daemon",
      "",
      "defaults",
      "  log global",
      "  mode http",
      "  option httplog",
      "  option dontlognull",
      "  timeout connect 5000",
      "  timeout client  50000",
      "  timeout server  50000",
      "",
      "frontend http_front",
      "  bind *:80",
      "  stats uri /haproxy?stats",
      "  default_backend http_back",
      "",
      "backend http_back",
      "  balance roundrobin",
      "  option httpchk",
      "  http-check send meth GET uri /health",
      "  server web1 ${var.web_server1_ip}:80 check",
      "  server web2 ${var.web_server2_ip}:80 check",
      "EOL",
      "systemctl restart haproxy"
    ]
  }
}

# Network monitoring
resource "null_resource" "network_monitoring" {
  triggers = {
    load_balancer_id = libvirt_domain.load_balancer.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "cat > /etc/prometheus/targets/network.yml << 'EOL'",
      "- targets:",
      "  - '${var.load_balancer_ip}:9100'",
      "  labels:",
      "    job: network",
      "    service: load_balancer",
      "EOL",
      "systemctl reload prometheus"
    ]
  }
}
