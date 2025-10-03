# Kubernetes Homelab Infrastructure

Infrastructure as Code for a Kubernetes homelab cluster running on Proxmox.

## Setup

### 1. Prerequisites
- Proxmox cluster with Ceph storage
- AWS account for Terraform state storage
- SSH access to Proxmox nodes

### 2. Configure Backend
```bash
cd terraform/
cp backend.hcl.template backend.hcl
# Edit backend.hcl with your S3 bucket details
```

### 3. Set Environment Variables

**Option A: Using Bitwarden (Recommended)**
```bash
# Unlock Bitwarden vault
export BW_SESSION=$(bw unlock --raw)

# Load credentials and SSH keys from Bitwarden
source set-proxmox-creds.sh
```

**Option B: Manual Export**
```bash
# Use single quotes to preserve special characters like !
export TF_VAR_proxmox_api_token_id='root@pam!your-token'
export TF_VAR_proxmox_api_token_secret='your-secret'
export PKR_VAR_proxmox_api_token_id='root@pam!your-token'
export PKR_VAR_proxmox_api_token_secret='your-secret'
export PKR_VAR_ssh_public_key="~/.ssh/id_rsa.pub"
```

### 4. Test API Connection (Optional)
```bash
# Verify your Proxmox API access
# Replace <proxmox-host> with your Proxmox server hostname/IP
curl -k -H 'Authorization:PVEAPIToken=root@pam!your-token'="$TF_VAR_proxmox_api_token_secret" \
  https://<proxmox-host>:8006/api2/json/version
```

### 5. Deploy Infrastructure
```bash
# Create base cloud template
cd terraform/
terraform init -backend-config=backend.hcl
terraform plan
terraform apply

# Build K8s template with Packer
cd ../packer/
packer build k8s-node.pkr.hcl

# Deploy K8s cluster
cd ../terraform/
# (K8s cluster terraform configs coming next)
```

## Development Environment

### Prepare Ubuntu Cloud Template

Before building the development VM template, prepare the base cloud template:

```bash
# SSH to Proxmox host
ssh root@<proxmox-host>

# Configure SSH key in cloud-init
# Replace <template-vmid> with your cloud template VM ID (e.g., 9000)
# Replace /path/to/key.pub with your SSH public key path
qm set <template-vmid> --sshkey /path/to/key.pub

# Resize disk to 50GB
# Replace scsi0 with your disk identifier if different
qm resize <template-vmid> scsi0 50G
```

Alternatively, configure via the Proxmox web UI:
1. Select your cloud template VM (e.g., `ubuntu-cloud-template`)
2. Go to Cloud-Init tab and add your SSH public key
3. Go to Hardware tab, select the disk, and resize to desired size (50GB recommended)

### Build Development VM Template

**Requirements:**
- Ubuntu cloud template configured as above (customize template name in Packer config)
- Proxmox API credentials configured (see step 3 above)
- Bitwarden items (if using Bitwarden method - customize item names in script):
  - Login item with Proxmox API credentials (username/password fields)
  - SSH key item with your keypair

**Note:** The `set-proxmox-creds.sh` script will:
- Export Proxmox API credentials as environment variables
- Export SSH keys to `~/.ssh/` directory (customize key names in script)
- Set `PKR_VAR_ssh_public_key` to configure the dev user's SSH access

Create a VM template for development work with pre-installed tools:

```bash
# Load credentials from Bitwarden (includes SSH keys)
export BW_SESSION=$(bw unlock --raw)
source set-proxmox-creds.sh

# Optional: Customize username (default: dev.user)
export PKR_VAR_dev_username="your.username"

# Optional: Use different SSH key (default: ~/.ssh/id_rsa.pub)
export PKR_VAR_ssh_public_key="~/.ssh/other_key.pub"

# Build template
cd packer/
packer build dev-lxc.pkr.hcl
```

This creates a template with:
- Git
- Claude CLI
- Terraform & Packer
- Python3, build tools
- SSH server (for VSCode Remote)
- User `dev.user` with sudo access and SSH key configured (or custom username/key if set)

**Resources:**
- 2 CPU cores
- 2GB RAM
- Cloned disk from ubuntu-cloud-template
- QEMU agent enabled

## Structure
```
k8s/
├── terraform/              # Infrastructure provisioning
├── packer/                 # VM template building
├── ansible/                # Configuration management
├── set-proxmox-creds.sh    # Load credentials and SSH keys from Bitwarden
└── README.md               # This file
```

## Troubleshooting

### Packer Build Issues

**SSH timeout during build:**
- Verify SSH key is configured in the `ubuntu-cloud-template` cloud-init settings
- Check that the VM can boot and get network access
- Increase `task_timeout` in the Packer config if using slow storage

**Clone timeout:**
- Ceph storage can be slow for cloning operations
- The `task_timeout` is set to 5 minutes by default
- Monitor the task in Proxmox web UI or check logs: `tail -f /var/log/pve/tasks/index`