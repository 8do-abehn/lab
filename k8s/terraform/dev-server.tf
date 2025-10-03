# Cloud-init configuration for dev server
# Matches working VM 201 config
locals {
  cloud_init_config = yamlencode({
    users = [
      {
        name                = var.dev_username
        groups              = ["sudo"]
        shell               = "/bin/bash"
        sudo                = "ALL=(ALL) NOPASSWD:ALL"
        lock_passwd         = true
        ssh_authorized_keys = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
      }
    ]

    package_update = true

    packages = [
      "qemu-guest-agent"
    ]

    runcmd = [
      ["systemctl", "enable", "qemu-guest-agent"],
      ["systemctl", "start", "qemu-guest-agent"]
    ]
  })
}

# Dev server VM
resource "proxmox_vm_qemu" "dev_server" {
  name        = "dev-server"
  target_node = "pve001"
  vmid        = 200

  # Clone from cloud template
  clone = "ubuntu-cloud-template"

  # VM specs
  cores   = 2
  sockets = 1
  memory  = 4096

  # Disable QEMU agent for testing
  agent = 0

  # Network configuration
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # Disk configuration
  disk {
    slot    = "scsi0"
    type    = "disk"
    storage = "infra_storage"
    size    = "20G"
  }

  # Cloud-init configuration
  os_type = "cloud-init"

  ipconfig0 = "ip=dhcp"

  # Custom cloud-init config (handles user creation and SSH keys)
  cicustom = "user=local:snippets/dev-server-cloud-init.yaml"

  # Lifecycle management
  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}

# Upload cloud-init config to Proxmox
resource "null_resource" "upload_cloud_init" {
  triggers = {
    config_hash = md5(local.cloud_init_config)
  }

  provisioner "local-exec" {
    command = <<-EOF
      ssh root@pve001 "mkdir -p /var/lib/vz/snippets && cat > /var/lib/vz/snippets/dev-server-cloud-init.yaml" <<'CLOUDINIT'
${local.cloud_init_config}
CLOUDINIT
    EOF
  }
}

# Output the VM IP address
output "dev_server_ip" {
  description = "IP address of dev server"
  value       = proxmox_vm_qemu.dev_server.default_ipv4_address
}
