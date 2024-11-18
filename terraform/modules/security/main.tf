# Security module configuration

# Firewall configuration
resource "libvirt_firewall" "main" {
  name = "main-firewall"
  
  # SSH access
  rule {
    direction = "in"
    protocol = "tcp"
    port = 22
    action = "accept"
    log = true
  }
  
  # HTTP/HTTPS access
  rule {
    direction = "in"
    protocol = "tcp"
    port = [80, 443]
    action = "accept"
  }
  
  # Monitoring ports
  rule {
    direction = "in"
    protocol = "tcp"
    port = [3000, 9090, 9093, 9100]
    action = "accept"
    source = var.monitoring_cidr
  }
  
  # ICMP for monitoring
  rule {
    direction = "in"
    protocol = "icmp"
    action = "accept"
  }
  
  # Default deny
  rule {
    direction = "in"
    action = "drop"
  }
}

# Security policies
resource "libvirt_domain" "security_policies" {
  name = "security-policies"
  
  security {
    type = "selinux"
    enforcing = true
  }
  
  # Memory limits
  memory = 512
  
  # CPU limits
  vcpu = 1
  
  # Disk limits
  disk {
    volume_id = var.security_volume_id
    scsi = true
  }
  
  # Network configuration
  network_interface {
    network_id = var.network_id
    addresses = [var.security_ip]
  }
}

# Fail2ban configuration
resource "null_resource" "fail2ban" {
  triggers = {
    security_policy_id = libvirt_domain.security_policies.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y fail2ban",
      "cat > /etc/fail2ban/jail.local << 'EOL'",
      "# Fail2ban configuration",
      "[DEFAULT]",
      "bantime = 3600",
      "findtime = 600",
      "maxretry = 5",
      "",
      "[sshd]",
      "enabled = true",
      "port = ssh",
      "filter = sshd",
      "logpath = /var/log/auth.log",
      "maxretry = 3",
      "",
      "[nginx-http-auth]",
      "enabled = true",
      "filter = nginx-http-auth",
      "port = http,https",
      "logpath = /var/log/nginx/error.log",
      "",
      "[nginx-limit-req]",
      "enabled = true",
      "filter = nginx-limit-req",
      "port = http,https",
      "logpath = /var/log/nginx/error.log",
      "EOL",
      "systemctl restart fail2ban"
    ]
  }
}

# AppArmor profiles
resource "null_resource" "apparmor" {
  triggers = {
    security_policy_id = libvirt_domain.security_policies.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y apparmor-utils",
      "aa-enforce /etc/apparmor.d/usr.sbin.nginx",
      "aa-enforce /etc/apparmor.d/usr.sbin.postgresqld",
      "systemctl reload apparmor"
    ]
  }
}

# Security auditing
resource "null_resource" "auditd" {
  triggers = {
    security_policy_id = libvirt_domain.security_policies.id
  }
  
  provisioner "remote-exec" {
    inline = [
      "apt-get update",
      "apt-get install -y auditd audispd-plugins",
      "cat > /etc/audit/rules.d/audit.rules << 'EOL'",
      "# Audit rules",
      "-w /etc/passwd -p wa -k identity",
      "-w /etc/group -p wa -k identity",
      "-w /etc/shadow -p wa -k identity",
      "-w /etc/sudoers -p wa -k sudo_actions",
      "-w /var/log/auth.log -p wa -k auth_logs",
      "-w /var/log/syslog -p wa -k syslog",
      "-w /etc/ssh/sshd_config -p wa -k sshd_config",
      "-w /etc/nginx/nginx.conf -p wa -k nginx_config",
      "EOL",
      "systemctl restart auditd"
    ]
  }
}
