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

### Proxmox Cluster
- **nut_server:** `pve004` - UPS server with direct serial connection
- **nut_netclients:** `pve001-pve003`, `pve005-pve007` - UPS network clients
- **proxmox:** Parent group containing all Proxmox hosts

### k3s Cluster
- **k3s_master:** `k3s-master-01` - Control plane node
- **k3s_workers:** `k3s-worker-01` through `k3s-worker-06` - Worker nodes
- **k3s_cluster:** Parent group containing all k3s nodes

## Host Variables

Host-specific variables are loaded from:
- `group_vars/proxmox.yml` - All Proxmox hosts
- `group_vars/k3s_cluster.yml` - All k3s hosts
- `group_vars/all.yml` - All hosts
- `host_vars/` - Individual host overrides

## Ansible Connection Details

Most hosts are accessed by hostname via Tailscale DNS. Some hosts have explicit `ansible_host` settings:

- **k3s-worker-04/05/06:** Use direct IP addresses (10.150.10.169-171)
  - These were added before Tailscale DNS was fully configured
  - Can be simplified once hostnames resolve properly

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
