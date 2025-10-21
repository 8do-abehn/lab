# Ansible Proxmox Infrastructure

Ansible automation for Proxmox homelab infrastructure management.

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
│   └── nut/              # Network UPS Tools (auto-detect server/client)
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
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --limit pve004
```
Applies playbook only to the specified host (pve004 in this example).

### Verbose output
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml -v
```
Shows detailed execution output. Use `-vv` or `-vvv` for more verbosity.

### Combine options
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --limit pve004 --check --diff -v
```
Runs check mode on a specific host with diff and verbose output.

### Verify NUT setup (no vault required)
```bash
ansible-playbook -i inventory/homelab.yml verify_nut.yml
```
Tests NUT UPS monitoring configuration and connectivity.

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
- Server configuration (pve004)
- Client configuration (all other hosts)

## Inventory Groups

- `nut_server`: Host with UPS directly connected (pve004)
- `nut_netclients`: Hosts that monitor UPS over network
- `proxmox`: Parent group containing all Proxmox hosts

## Tips

- Always use `--check --diff` first to preview changes
- Use `--limit` to test on a single host before running on all
- Store vault password in a secure location (not in the repository)
- Run `verify_nut.yml` after making UPS configuration changes
# CI Test
