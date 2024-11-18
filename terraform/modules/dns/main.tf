# DNS module configuration

# DNS server configuration
resource "libvirt_domain" "dns_server" {
  name   = "dns-server"
  memory = "1024"
  vcpu   = 1

  network_interface {
    network_id = var.network_id
    addresses  = [var.dns_server_ip]
  }

  disk {
    volume_id = var.dns_volume_id
  }
}

# Bind9 configuration
resource "null_resource" "bind_config" {
  triggers = {
    dns_server_id = libvirt_domain.dns_server.id
  }

  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y bind9 bind9utils",
      
      # Configure named options
      "cat > /etc/bind/named.conf.options << 'EOL'",
      "options {",
      "  directory \"/var/cache/bind\";",
      "  recursion yes;",
      "  allow-recursion { trusted; };",
      "  listen-on { ${var.dns_server_ip}; };",
      "  allow-transfer { none; };",
      "  forwarders {",
      "    1.1.1.1;",
      "    8.8.8.8;",
      "  };",
      "  dnssec-validation auto;",
      "  auth-nxdomain no;",
      "  version none;",
      "  hostname none;",
      "  server-id none;",
      "};",
      "EOL",
      
      # Configure local zones
      "cat > /etc/bind/named.conf.local << 'EOL'",
      "zone \"${var.domain_name}\" {",
      "  type master;",
      "  file \"/var/lib/bind/${var.domain_name}.zone\";",
      "  allow-update { none; };",
      "};",
      "zone \"${join(".", reverse(split(".", cidrhost(var.network_cidr, 0)))}.in-addr.arpa\" {",
      "  type master;",
      "  file \"/var/lib/bind/${var.domain_name}.rev\";",
      "  allow-update { none; };",
      "};",
      "EOL",
      
      # Create forward zone file
      "cat > /var/lib/bind/${var.domain_name}.zone << 'EOL'",
      "$TTL 86400",
      "@ IN SOA ns1.${var.domain_name}. admin.${var.domain_name}. (",
      "  $(date +%s) ; Serial",
      "  3600       ; Refresh",
      "  1800       ; Retry",
      "  604800     ; Expire",
      "  86400      ; Minimum TTL",
      ")",
      "",
      "@ IN NS ns1.${var.domain_name}.",
      "",
      "ns1    IN A ${var.dns_server_ip}",
      "*.${var.domain_name}. IN A ${var.load_balancer_ip}",
      "EOL",
      
      # Create reverse zone file
      "cat > /var/lib/bind/${var.domain_name}.rev << 'EOL'",
      "$TTL 86400",
      "@ IN SOA ns1.${var.domain_name}. admin.${var.domain_name}. (",
      "  $(date +%s) ; Serial",
      "  3600       ; Refresh",
      "  1800       ; Retry",
      "  604800     ; Expire",
      "  86400      ; Minimum TTL",
      ")",
      "",
      "@ IN NS ns1.${var.domain_name}.",
      "",
      "${split(".", var.dns_server_ip)[3]} IN PTR ns1.${var.domain_name}.",
      "${split(".", var.load_balancer_ip)[3]} IN PTR lb.${var.domain_name}.",
      "EOL",
      
      # Set permissions
      "chown -R bind:bind /var/lib/bind",
      "chmod 644 /var/lib/bind/*",
      
      # Restart service
      "systemctl restart bind9"
    ]
  }
}

# DNS monitoring
resource "null_resource" "dns_monitoring" {
  triggers = {
    dns_server_id = libvirt_domain.dns_server.id
  }

  provisioner "remote-exec" {
    inline = [
      "cat > /etc/prometheus/targets/dns.yml << 'EOL'",
      "- targets:",
      "  - '${var.dns_server_ip}:9100'",
      "  labels:",
      "    job: dns",
      "    service: bind",
      "EOL",
      "systemctl reload prometheus"
    ]
  }
}

# DNS health check
resource "null_resource" "dns_healthcheck" {
  triggers = {
    dns_server_id = libvirt_domain.dns_server.id
  }

  provisioner "remote-exec" {
    inline = [
      "cat > /usr/local/bin/check-dns << 'EOL'",
      "#!/bin/bash",
      "dig @${var.dns_server_ip} ns1.${var.domain_name} +short | grep -q ${var.dns_server_ip}",
      "if [ $? -eq 0 ]; then",
      "  echo 'DNS check passed'",
      "  exit 0",
      "else",
      "  echo 'DNS check failed'",
      "  exit 1",
      "fi",
      "EOL",
      "chmod +x /usr/local/bin/check-dns",
      "echo '*/5 * * * * root /usr/local/bin/check-dns' > /etc/cron.d/dns-check"
    ]
  }
}
