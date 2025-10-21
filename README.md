# Homelab Infrastructure

A comprehensive homelab infrastructure project running on Proxmox with Kubernetes, managed through Infrastructure as Code principles.

## Overview

This repository contains the complete infrastructure setup for a homelab environment, including:

- **Virtualization Platform**: Proxmox VE cluster with Ceph storage
- **Container Orchestration**: Kubernetes cluster for running applications
- **Configuration Management**: Ansible automation for Proxmox hosts
- **Infrastructure Provisioning**: Terraform and Packer for VM template creation and deployment
- **Self-hosted Applications**: Various services including Mealie, Homarr, Minecraft, and more

## Tech Stack

- **Proxmox VE**: Virtualization platform with Ceph distributed storage
- **Kubernetes (K3s)**: Lightweight Kubernetes distribution for container orchestration
- **Ansible**: Configuration management and automation
- **Terraform**: Infrastructure provisioning
- **Packer**: VM template building
- **Tailscale**: VPN and secure access
- **Network UPS Tools (NUT)**: UPS monitoring and management

## Structure

```
lab/
├── ansible/              # Ansible playbooks and roles
│   ├── roles/
│   │   ├── proxmox/     # Base Proxmox configuration
│   │   ├── tailscale/   # VPN and certificate management
│   │   └── nut/         # UPS monitoring setup
│   └── README.md        # Ansible documentation
│
├── k8s/                  # Kubernetes infrastructure
│   ├── terraform/       # Infrastructure provisioning
│   ├── packer/          # VM template building
│   ├── deployments/     # Application deployments
│   └── README.md        # K8s setup documentation
│
├── journal/             # Learning journal and documentation
│   └── *.md            # Day-by-day learnings and challenges
│
└── notes/              # Quick reference notes
    └── favorite_commands.md
```

## Components

### Infrastructure Management ([ansible/](ansible/))

Ansible automation for managing Proxmox hosts, including:
- Base system configuration
- Tailscale VPN setup with Let's Encrypt certificates
- Network UPS Tools (NUT) for power management
- Repository management and package installation

See [ansible/README.md](ansible/README.md) for detailed usage instructions.

### Kubernetes Cluster ([k8s/](k8s/))

Complete Kubernetes infrastructure setup:
- Terraform configurations for VM provisioning
- Packer templates for creating K8s node images
- Application deployments (Mealie, Homarr, Minecraft, etc.)
- Storage configurations using Ceph/CephFS

See [k8s/README.md](k8s/README.md) for setup and deployment instructions.

### Deployed Applications

Current applications running in the cluster:
- **Mealie**: Recipe management and meal planning
- **Homarr**: Dashboard for homelab services
- **Minecraft**: Vanilla server deployment
- **Nginx**: Documentation hosting

### Learning Journal ([journal/](journal/))

Documentation of the journey, challenges, and solutions discovered while building and maintaining the homelab. Each entry captures real-world problems and their resolutions.

## Quick Start

### Prerequisites

- Proxmox VE cluster with Ceph storage configured
- AWS account for Terraform state storage
- SSH access to Proxmox nodes
- Bitwarden CLI (optional, for credential management)

### Initial Setup

1. **Configure Ansible**
   ```bash
   cd ansible/
   # Create vault for secrets
   ansible-vault create vault.yml
   # Run site playbook
   ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml
   ```

2. **Deploy Kubernetes Infrastructure**
   ```bash
   cd k8s/
   # Load credentials
   export BW_SESSION=$(bw unlock --raw)
   source set-proxmox-creds.sh

   # Initialize Terraform
   cd terraform/
   terraform init -backend-config=backend.hcl
   terraform apply

   # Build K8s node template
   cd ../packer/
   packer build k8s-node.pkr.hcl
   ```

3. **Deploy Applications**
   ```bash
   cd k8s/deployments/
   kubectl apply -f <application>.yaml
   ```

## Key Features

- **Infrastructure as Code**: Everything defined in code for reproducibility
- **Automated Configuration**: Ansible playbooks for consistent host setup
- **Templated Deployments**: Packer templates for rapid VM creation
- **Distributed Storage**: Ceph for resilient, shared storage across cluster
- **Secure Access**: Tailscale VPN with automatic certificate management
- **Power Management**: NUT integration for graceful shutdown during power events
- **Self-documenting**: Journal entries track learnings and decision-making process

## Documentation

- [Ansible Setup](ansible/README.md) - Proxmox host configuration and management
- [Kubernetes Infrastructure](k8s/README.md) - K8s cluster setup and deployment
- [Journal](journal/) - Day-by-day learnings and troubleshooting
- [Notes](notes/) - Quick reference commands and links

## Development

The repository includes configurations for development environments:
- Packer templates for development VMs with pre-installed tools
- VSCode Remote SSH ready
- Git, Terraform, Packer, Python3, and Claude CLI pre-configured

## Security Notes

- Credentials managed via Ansible Vault
- SSH key-based authentication throughout
- Secrets stored in Bitwarden (optional)
- `.gitignore` configured to prevent accidental credential commits

## License

Personal homelab project - use at your own risk.
