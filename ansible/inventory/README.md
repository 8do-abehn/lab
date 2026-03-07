# Ansible Inventory

This directory contains inventory files for different environments.

## Structure

```
inventory/
├── homelab.yml    # Local Proxmox + k3s infrastructure
├── aws.yml        # (future) AWS resources
└── azure.yml      # (future) Azure resources
```

## Usage

### Target specific environment

```bash
# Homelab
ansible-playbook -i inventory/homelab.yml site.yml

# AWS (future)
ansible-playbook -i inventory/aws.yml deploy.yml

# Azure (future)
ansible-playbook -i inventory/azure.yml deploy.yml
```

### Target multiple environments

```bash
ansible-playbook -i inventory/homelab.yml -i inventory/aws.yml site.yml
```

### Use entire inventory directory (all environments)

```bash
ansible-playbook -i inventory/ site.yml
```

## Homelab Inventory

The `homelab.yml` inventory includes:

### Proxmox New Cluster (`proxmox_pve0x`) — Proxmox 9, Ceph

3-node cluster rebuilt 2026-03. Management VLAN 60 (10.150.60.0/24), Storage VLAN 65, Guest VLAN 70.

| Host | CPU | RAM | GPU | NIC | NVMe (local) | SSD (Ceph) | HDD (Ceph) | OS Disk |
|------|-----|-----|-----|-----|-------------|-----------|-----------|---------|
| pve01 | Ryzen 9 5900X (12C/24T) | 128GB | 2x RX 570 | Intel I225-V 2.5G | 1.8TB | 3.6TB | 1.8TB | 120GB |
| pve02 | Ryzen 9 5900X (12C/24T) | 64GB | 1x RTX 3080 Ti | Aquantia 10G + Intel I225-V 2.5G | 1.8TB | 3.6TB | 1.8TB | 112GB |
| pve03 | Ryzen 9 5900X (12C/24T) | 128GB | 2x RTX 3080 | Intel I225-V 2.5G | 1.8TB | 3.6TB | 1.8TB | 120GB |

### Proxmox Legacy Cluster (`proxmox_pve00x`) — Proxmox 8, 10.150.10.0/24, UPS connected

To be decommissioned after jellyfin migration to new cluster.

| Host | CPU | RAM | GPU | NIC | Storage | Notes |
|------|-----|-----|-----|-----|---------|-------|
| pve001 | i5-6500 (4C/4T) | 16GB | Intel HD 530 | Intel I219-LM 1G | 477GB SSD + 954GB NVMe | |
| pve002 | i5-6500 (4C/4T) | 16GB | Intel HD 530 | Intel I219-LM 1G | 477GB SSD + 954GB NVMe | |
| pve003 | i5-6500 (4C/4T) | 16GB | Intel HD 530 | Intel I219-LM 1G | 477GB SSD + 954GB NVMe | |
| pve004 | i5-6500 (4C/4T) | 16GB | Intel HD 530 | Intel I219-LM 1G | 477GB SSD + 954GB NVMe | NUT/UPS server |
| pve005 | i5-7500 (4C/4T) | 16GB | Intel HD 630 (QSV) | Intel I219-V 1G | 954GB SSD + 112GB SSD + 2.7TB HDD | Jellyfin host |
| pve006 | i7-4600U (2C/4T) | 16GB | Intel Haswell ULT | Realtek 8111 1G | 239GB SSD | Laptop form factor |

- **nut_server:** `pve004` - UPS server with direct serial connection
- **nut_netclients:** `pve001-pve003`, `pve005-pve006` - UPS network clients

### Backup Infrastructure
- **backup_servers:** `pi-burg` - Raspberry Pi with 8TB USB backup storage
- **media_servers:** `jellyfin` - Media server (LXC 3001 on pve005) backing up to pi-burg

### k3s Cluster (decommissioned 2026-01)
- Commented out in inventory, preserved for history

## Host Variables

Host-specific variables are loaded from:
- `group_vars/proxmox.yml` - Shared settings for all Proxmox hosts (Tailscale, Netdata)
- `group_vars/proxmox_pve00x.yml` - Legacy cluster (NUT/UPS config)
- `group_vars/all.yml` - All hosts
- `host_vars/` - Individual host overrides

## Ansible Connection Details

All hosts are accessed by hostname via Tailscale DNS.

To override connection details for any host, add to the inventory:
```yaml
hostname:
  ansible_host: 10.x.x.x
  ansible_user: ubuntu
  ansible_port: 22
```

## Naming Convention

- **homelab.yml** - Physical/local infrastructure
- **aws.yml** - AWS cloud resources
- **azure.yml** - Azure cloud resources
- **gcp.yml** - Google Cloud Platform (future)
- **production.yml** - Production environment (if needed)
- **staging.yml** - Staging environment (if needed)

## Migration from inventory.ini

Previous single-file inventory (`inventory.ini`) has been migrated to `inventory/homelab.yml` with YAML format for better structure and consistency.

Update commands that used:
```bash
ansible-playbook -i inventory.ini site.yml
```

To use:
```bash
ansible-playbook -i inventory/homelab.yml site.yml
# or
ansible-playbook -i inventory/ site.yml
```
