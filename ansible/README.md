# Ansible Proxmox Infrastructure

Ansible automation for Proxmox homelab infrastructure management.

## Quick Reference

```bash
# Apply all configuration to homelab
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml

# Dry-run with preview
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --check --diff

# Run on single host
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --limit pve01

# Install Netdata monitoring
ansible-playbook -i inventory/homelab.yml --ask-vault-pass netdata_install.yml

# Verify NUT UPS setup
ansible-playbook -i inventory/homelab.yml verify_nut.yml

# Install tools on k3s cluster
ansible-playbook -i inventory/homelab.yml k3s_setup_tools.yml

# Setup Pi backup server and Jellyfin backup client
ansible-playbook -i inventory/homelab.yml --ask-vault-pass backup-setup.yml
```

## Structure

```
ansible/
├── inventory/
│   ├── homelab.yml       # Homelab infrastructure inventory
│   └── README.md         # Inventory documentation
├── site.yml              # Main playbook (runs all roles)
├── verify_nut.yml        # NUT UPS verification playbook
├── vault.yml             # Encrypted secrets (Tailscale keys, etc.)
├── roles/
│   ├── proxmox/          # Base Proxmox configuration
│   ├── tailscale/        # Tailscale VPN and certificates
│   ├── nut/              # Network UPS Tools (server/client via inventory)
│   ├── netdata/          # Monitoring agent with cloud connection
│   ├── adguard_home/     # DNS server with Tailscale Service
│   ├── mem0/             # AI memory stack (OpenMemory, Ollama, Open WebUI)
│   ├── backup_server/    # Pi backup server (disk mount, restic repo)
│   ├── backup_client/    # Backup client (restic backup script, cron)
│   ├── jellyfin_backup/  # Jellyfin rclone to B2
│   └── minecraft/        # Minecraft servers via Docker Compose
├── group_vars/           # Group-specific variables
└── host_vars/            # Host-specific variables
```

## Vault Management

### Create a new vault file
```bash
ansible-vault create vault.yml
```

### Edit existing vault
```bash
ansible-vault edit vault.yml
```

## Running Playbooks

### Run the main site playbook (all roles, all hosts)
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml
```
Prompts for vault password and applies all roles to all hosts in inventory.

### Check mode (dry run)
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --check
```
Shows what would change without making any actual changes.

### Check mode with diff output
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --check --diff
```
Shows what would change and displays file differences.

### Run on specific host only
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --limit pve01
```
Applies playbook only to the specified host (pve01 in this example).

### Verbose output
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml -v
```
Shows detailed execution output. Use `-vv` or `-vvv` for more verbosity.

### Combine options
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --limit pve01 --check --diff -v
```
Runs check mode on a specific host with diff and verbose output.

### Verify NUT setup (no vault required)
```bash
ansible-playbook -i inventory/homelab.yml verify_nut.yml
```
Tests NUT UPS monitoring configuration and connectivity.

### Install Netdata monitoring
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass netdata_install.yml
```
Installs Netdata monitoring on all hosts (Proxmox + k3s).

### Install basic tools on k3s cluster
```bash
ansible-playbook -i inventory/homelab.yml k3s_setup_tools.yml
```
Installs vim and git on k3s nodes (no vault required).

## Roles

### proxmox
Base Proxmox configuration including:
- Repository management
- Essential packages
- System configuration

### tailscale
Tailscale VPN setup including:
- Installation
- Authentication with auth keys from vault
- Let's Encrypt certificate management for Proxmox web UI

### nut
Network UPS Tools configuration with:
- Auto-detection of server vs. client role based on inventory groups
- UPS monitoring and shutdown coordination
- Server configuration (pve004 on legacy cluster)
- Client configuration (pve001-003, pve005-006 on legacy cluster)
- New cluster (pve01-03) not yet connected to UPS

### netdata
Netdata monitoring setup including:
- Installation and configuration
- Claiming to Netdata Cloud with vault-stored tokens
- Monitoring for both Proxmox and k3s infrastructure

**Design decision:** Uses `state: latest` instead of `state: present` because Ubuntu's
distro packages are built with `--disable-cloud`. The official netdata repo packages
include cloud support, so `latest` ensures they replace any pre-existing distro packages.

**Note:** Run via `netdata_install.yml` playbook, not included in `site.yml`

### backup_server
Raspberry Pi backup server setup including:
- External USB disk mounting with fstab
- Restic repository initialization
- Backup user with SSH access

### backup_client
Backup client configuration including:
- Restic installation
- Backup script deployment (daily 2am cron)
- Log rotation

**Note:** Run via `backup-setup.yml` playbook, not included in `site.yml`

### adguard_home
AdGuard Home DNS server with Tailscale Service registration:
- Installation and initial configuration
- DNS binding on port 53
- Tailscale Service registration (`svc:dns`)

### mem0
AI memory stack via Docker Compose:
- OpenMemory MCP server, Ollama, Open WebUI
- Tailscale Service registration (`svc:mem0`)
- Ollama model provisioning

### jellyfin_backup
Jellyfin-specific backup configuration:
- rclone sync to Backblaze B2
- Scheduled via cron (daily midnight)

### minecraft
Minecraft servers via Docker Compose:
- Paper and Fabric server support
- Per-host server definitions via inventory
- Automated backups via mc-backup sidecar
- Weekly auto-update cron

## Inventory Groups

### Proxmox Groups
- `proxmox`: Parent group containing all Proxmox hosts (both clusters)
- `proxmox_pve0x`: New cluster (pve01-03, Proxmox 9, Ceph, 10.150.60.0/24)
- `proxmox_pve00x`: Legacy cluster (pve001-006, 10.150.10.0/24, UPS connected)
  - `nut_server`: Host with UPS directly connected (pve004)
  - `nut_netclients`: Hosts that monitor UPS over network (pve001-003, pve005-006)

### k3s Groups (decommissioned 2026-01)
- `k3s_cluster`: Commented out in inventory, preserved for history

### Backup Groups
- `backup_servers`: Backup storage servers (pi-burg)
- `media_servers`: Media servers with backup clients (jellyfin)

## Tips

- Always use `--check --diff` first to preview changes
- Use `--limit` to test on a single host before running on all
- Store vault password in a secure location (not in the repository)
- Run `verify_nut.yml` after making UPS configuration changes
