# Homelab Infrastructure

Ansible automation and Hugo blog for a Proxmox-based homelab, with CI/CD via GitHub Actions and Tailscale.

## Structure

```
lab/
├── ansible/              # Ansible playbooks and roles
│   ├── roles/
│   │   ├── proxmox/     # Base Proxmox configuration
│   │   ├── tailscale/   # VPN and certificate management
│   │   └── nut/         # UPS monitoring setup
│   └── README.md
│
├── site/                 # Hugo blog (lab.8devops.com)
│   └── themes/PaperMod/  # PaperMod theme (submodule)
│
├── scripts/              # Backup and migration scripts
│
├── .github/workflows/    # CI/CD pipelines
│   ├── ansible-ci.yml    # PR lint + dry-run validation
│   ├── ansible-deploy.yml # Manual deployment
│   └── deploy-blog.yml   # Hugo site deployment
│
└── .gitignore
```

## Ansible ([ansible/](ansible/))

Automation for managing Proxmox hosts:
- Base system configuration
- Tailscale VPN with automatic Let's Encrypt certificates
- Network UPS Tools (NUT) for power management
- Repository management and package installation

See [ansible/README.md](ansible/README.md) for usage instructions.

## Blog ([site/](site/))

Hugo site published to [lab.8devops.com](https://lab.8devops.com), using the PaperMod theme. Deployed automatically via GitHub Actions on push to `main`.

## CI/CD Pipeline

GitHub Actions with Tailscale integration:
- **ansible-ci**: PR triggers lint checks and dry-run validation against real infrastructure
- **ansible-deploy**: Manual workflow dispatch with playbook selection
- **deploy-blog**: Automatic Hugo build and deploy on push

Runners connect to the homelab via Tailscale VPN using OAuth authentication with tag-based ACLs.

## Quick Start

```bash
# Enable gitleaks pre-commit hook
git config core.hooksPath .githooks

# Run Ansible
cd ansible/
ansible-vault create vault.yml
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml
```

## Archive

Previous content (K8s configs, AD lab, OpenPLC, journals, notes) is preserved at the `v1-archive` tag. To restore any file:

```bash
git checkout v1-archive -- path/to/file
```

## Security

- Credentials managed via Ansible Vault
- SSH key-based authentication
- Secrets stored in Bitwarden CLI
- `.gitignore` configured to prevent accidental credential commits

## License

Personal homelab project - use at your own risk.
