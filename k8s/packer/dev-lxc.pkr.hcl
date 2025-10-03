packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

variable "proxmox_api_url" {
  type    = string
  default = "https://pve001:8006/api2/json"
  # Override via: export PKR_VAR_proxmox_api_url="https://your-host:8006/api2/json"
}

variable "proxmox_api_token_id" {
  type = string
  # Set via environment variable: export PKR_VAR_proxmox_api_token_id="root@pam!your-token"
}

variable "proxmox_api_token_secret" {
  type      = string
  sensitive = true
  # Set via environment variable: export PKR_VAR_proxmox_api_token_secret="your-secret-here"
}

variable "dev_username" {
  type    = string
  default = "dev.user"
  # Override via: export PKR_VAR_dev_username="your.username"
}

variable "ssh_public_key" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
  # Override via: export PKR_VAR_ssh_public_key="~/.ssh/your_key.pub"
}

source "proxmox-clone" "dev-vm" {
  # Proxmox Connection Settings
  proxmox_url              = var.proxmox_api_url
  username                 = var.proxmox_api_token_id
  token                    = var.proxmox_api_token_secret
  insecure_skip_tls_verify = true
  task_timeout             = "5m"  # Increase timeout for slow Ceph storage

  # VM General Settings
  node                 = "pve001"  # Customize: your Proxmox node name
  vm_name              = "dev-vm-template"
  template_description = "Ubuntu 22.04 VM template for development"

  # Clone from cloud template (customize template name if different)
  clone_vm = "ubuntu-cloud-template"

  # VM System Settings
  qemu_agent = true

  # VM Hard Disk Settings
  scsi_controller = "virtio-scsi-pci"

  # Note: Resize the cloud template disk in Proxmox before running this
  # proxmox-clone doesn't support resizing, it only clones the existing disk

  # VM CPU Settings
  cores = "2"

  # VM Memory Settings
  memory = "2048"

  # VM Network Settings
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"  # Customize: your Proxmox network bridge
    firewall = "false"
  }

  ipconfig {
    ip = "dhcp"
  }

  # VM Cloud-Init Settings
  cloud_init              = true
  cloud_init_storage_pool = "infra_storage"  # Customize: your storage pool name

  # Communicator Settings
  communicator = "ssh"
  ssh_username = "ubuntu"
  # Let Packer auto-generate SSH keys for the build
  ssh_timeout  = "20m"

  # Template Conversion Settings
  template_name = "dev-vm-template"
}

build {
  name    = "dev-vm"
  sources = ["source.proxmox-clone.dev-vm"]

  # Wait for cloud-init and update system
  provisioner "shell" {
    inline = [
      "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
      "sudo apt-get update",
      "sudo apt-get upgrade -y"
    ]
  }

  # Install basic tools and SSH server
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y openssh-server curl wget vim git htop tmux qemu-guest-agent",
      "sudo systemctl enable ssh",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl start qemu-guest-agent"
    ]
  }

  # Install Terraform and Packer
  provisioner "shell" {
    inline = [
      "wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg",
      "echo \"deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main\" | sudo tee /etc/apt/sources.list.d/hashicorp.list",
      "sudo apt-get update",
      "sudo apt-get install -y terraform packer"
    ]
  }

  # Install Claude CLI
  provisioner "shell" {
    inline = [
      "curl -fsSL https://claude.ai/install.sh | sh"
    ]
  }

  # Install additional dev tools
  provisioner "shell" {
    inline = [
      "sudo apt-get install -y build-essential python3 python3-pip jq unzip"
    ]
  }

  # Create dev user with parameterized username
  provisioner "shell" {
    environment_vars = [
      "DEV_USER=${var.dev_username}"
    ]
    inline = [
      "sudo useradd -m -s /bin/bash -G sudo $DEV_USER",
      "echo \"$DEV_USER ALL=(ALL) NOPASSWD:ALL\" | sudo tee /etc/sudoers.d/$DEV_USER",
      "sudo chmod 0440 /etc/sudoers.d/$DEV_USER"
    ]
  }

  # Set up SSH key for dev user
  provisioner "file" {
    source      = pathexpand(var.ssh_public_key)
    destination = "/tmp/authorized_keys"
  }

  provisioner "shell" {
    environment_vars = [
      "DEV_USER=${var.dev_username}"
    ]
    inline = [
      "sudo mkdir -p /home/$DEV_USER/.ssh",
      "sudo mv /tmp/authorized_keys /home/$DEV_USER/.ssh/authorized_keys",
      "sudo chown -R $DEV_USER:$DEV_USER /home/$DEV_USER/.ssh",
      "sudo chmod 700 /home/$DEV_USER/.ssh",
      "sudo chmod 600 /home/$DEV_USER/.ssh/authorized_keys"
    ]
  }

  # Clean up
  provisioner "shell" {
    inline = [
      "sudo apt-get autoremove -y",
      "sudo apt-get autoclean",
      "sudo cloud-init clean",
      "sudo rm -rf /tmp/*",
      "sudo rm -rf /var/tmp/*",
      "history -c"
    ]
  }
}
