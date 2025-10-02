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
```bash
# Use single quotes to preserve special characters like !
export TF_VAR_proxmox_api_token_id='root@pam!your-token'
export TF_VAR_proxmox_api_token_secret='your-secret'
export PKR_VAR_proxmox_api_token_id='root@pam!your-token'
export PKR_VAR_proxmox_api_token_secret='your-secret'
export PKR_VAR_ssh_public_key="$(cat ~/.ssh/id_rsa.pub)"
```

### 4. Test API Connection (Optional)
```bash
# Verify your Proxmox API access
curl -k -H 'Authorization:PVEAPIToken=root@pam!your-token'="$TF_VAR_proxmox_api_token_secret" \
  https://pve001:8006/api2/json/version
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

## Structure
```
k8s/
├── terraform/          # Infrastructure provisioning
├── packer/             # VM template building
├── ansible/            # Configuration management
└── README.md           # This file
```