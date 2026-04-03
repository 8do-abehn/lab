# Homelab Infrastructure

[![Ansible CI/CD](https://github.com/8do-abehn/lab/actions/workflows/ansible-ci.yml/badge.svg)](https://github.com/8do-abehn/lab/actions/workflows/ansible-ci.yml)
[![Deploy Blog](https://github.com/8do-abehn/lab/actions/workflows/deploy-blog.yml/badge.svg)](https://github.com/8do-abehn/lab/actions/workflows/deploy-blog.yml)
[![Gitleaks](https://github.com/8do-abehn/lab/actions/workflows/gitleaks.yml/badge.svg)](https://github.com/8do-abehn/lab/actions/workflows/gitleaks.yml)
[![Build CI Image](https://github.com/8do-abehn/lab/actions/workflows/build-ci-image.yml/badge.svg)](https://github.com/8do-abehn/lab/actions/workflows/build-ci-image.yml)

Ansible automation and Hugo blog for a Proxmox-based homelab, with CI/CD via GitHub Actions and Tailscale.

## Structure

```
lab/
├── ansible/
│   ├── inventory/
│   │   ├── homelab.yml          # All hosts and groups
│   │   ├── group_vars/          # Per-group variables
│   │   └── host_vars/           # Per-host variables
│   ├── roles/                   # 9 roles (see table below)
│   ├── site.yml                 # Main playbook
│   ├── vault.yml                # Encrypted secrets (AES256)
│   └── README.md
├── site/                        # Hugo blog (lab.8devops.com)
│   └── themes/PaperMod/         # PaperMod theme (submodule)
├── scripts/                     # Migration and audit scripts
├── .github/
│   ├── ci/Dockerfile            # CI container image
│   └── workflows/
│       ├── ansible-ci.yml       # PR lint + dry-run validation
│       ├── ansible-deploy.yml   # Manual deployment
│       ├── build-ci-image.yml   # Build CI container image
│       ├── deploy-blog.yml      # Hugo site deployment
│       └── gitleaks.yml         # Secret scanning
└── .githooks/pre-commit         # Gitleaks pre-commit hook
```

## Ansible ([ansible/](ansible/))

Automation for Proxmox hosts and LXC services:

| Role | Purpose |
|------|---------|
| `proxmox` | Base Proxmox configuration, GPU passthrough |
| `tailscale` | VPN with SSH and subnet routing |
| `nut` | UPS monitoring (server/client via inventory groups) |
| `netdata` | Monitoring agent with cloud connection |
| `adguard_home` | DNS server with Tailscale Service registration |
| `mem0` | AI memory stack (OpenMemory, Ollama, Open WebUI) via Docker |
| `backup_client` | Restic backups to pi-burg with Apprise notifications |
| `backup_server` | Backup target disk management |
| `jellyfin_backup` | Jellyfin-specific backup (rclone to B2 + restic) |
| `minecraft` | Minecraft servers via Docker Compose (Paper + Fabric) |

See [ansible/README.md](ansible/README.md) for usage instructions.

## Services

User-facing services running on the homelab:

| Service | Host | Docs |
|---------|------|------|
| Jellyfin | jellyfin01 | [docs/services/jellyfin.md](docs/services/jellyfin.md) |
| AdGuard Home | dns01 | [docs/services/adguard.md](docs/services/adguard.md) |
| Minecraft (6 servers) | mc01–mc03 | [docs/services/minecraft.md](docs/services/minecraft.md) |
| OpenMemory | mem01 | [docs/services/mem0.md](docs/services/mem0.md) |

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

## Issue Triage

All issues get a priority label when created:

| Label | Response | Examples |
|-------|----------|---------|
| `priority:critical` | Drop everything, fix now | Prod service down, data loss risk, security issue |
| `priority:high` | Fix this sprint, blocks other work | Broken CI, missing infra for planned deploy |
| `priority:medium` | Fix soon, not blocking | Config drift between nodes, non-urgent cleanup |
| `priority:low` | Backlog, nice to have | Documentation updates, future optimizations |

If an issue doesn't have a priority label, it hasn't been triaged yet.

## Security

- Credentials managed via Ansible Vault
- SSH key-based authentication
- Secrets stored in Bitwarden CLI
- `.gitignore` configured to prevent accidental credential commits

## License

Personal homelab project - use at your own risk.
