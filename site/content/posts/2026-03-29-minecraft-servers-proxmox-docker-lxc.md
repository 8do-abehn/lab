---
title: "Running 6 Minecraft Servers on Proxmox with Docker-in-LXC"
date: 2026-03-29
draft: true
tags: ["homelab", "proxmox", "docker", "minecraft", "ansible"]
description: "Deploying 6 Paper Minecraft servers across 3 Proxmox LXCs using Ansible, itzg/minecraft-server, and automated backups — plus everything that broke along the way."
---

## The Goal

The kids want Minecraft servers. Not one — six. Survival, Creative, Adventure, Minigames, Hardcore, and a modded Fabric server. I have three Ryzen 9 5900X Proxmox nodes with 64-128GB RAM each, so hardware isn't the problem. The question was how to deploy and manage them without it becoming a second job.

## The Stack

After researching management panels (Pterodactyl, Crafty, AMP, MCSManager), I landed on the simplest approach: Docker Compose with the `itzg/minecraft-server` image. It handles Paper builds, EULA acceptance, Aikar's JVM flags, RCON, and graceful shutdown — all via environment variables. No panel needed.

Each server gets a backup sidecar (`itzg/mc-backup`) that pauses world saves via RCON, creates tarballs, and prunes old backups. A weekly cron pulls the latest Paper builds automatically.

The whole thing is an Ansible role. Define servers in inventory, run the playbook, done:

```yaml
# inventory/host_vars/mc01.yml
minecraft_servers:
  - name: survival
    port: 25565
    memory: "6G"
    motd: "Survival Server"
  - name: creative
    port: 25566
    memory: "4G"
    gamemode: creative
    motd: "Creative Server"
```

## What Went Wrong

### Docker on Proxmox Hosts? No Thanks.

My first plan was Docker directly on pve01-03. That works, but I didn't want Docker competing with Proxmox's own container runtime on the hypervisors. LXCs give better isolation.

### Unprivileged LXCs Don't Work with Docker

I created the LXCs with `--unprivileged 1` out of habit. Docker's overlay2 storage driver needs to mount overlayfs, which unprivileged containers can't do. Every `docker pull` failed with:

```
failed to mount overlayfs: permission denied
```

The fix is `--unprivileged 0` (privileged). But here's the catch: Proxmox marks `unprivileged` as read-only after creation. You can't change it — you have to destroy and recreate the container. I learned this after debugging mc01 for 30 minutes while mc02 and mc03 (which I'd accidentally created as privileged) worked fine.

### AppArmor: The Gift That Keeps Breaking

Even with `lxc.apparmor.profile: unconfined` in the container config, Docker still tries to load AppArmor profiles inside the LXC. You have to purge AppArmor entirely:

```bash
apt purge apparmor
systemctl restart docker
```

The restart is critical — without it, Docker's daemon still has AppArmor cached and will fail to start containers with:

```
AppArmor enabled on system but the docker-default profile could not be loaded
```

The Ansible role now handles this automatically (purge + conditional restart).

### DNS Breaks on Every Reboot

Ubuntu 24.04 LXCs run systemd-resolved, which writes `nameserver 127.0.0.53` to `/etc/resolv.conf`. Inside an LXC on a Proxmox host with Tailscale, MagicDNS leaks into the resolver config and breaks external DNS resolution. Every reboot, every `apt update` fails.

The fix: disable systemd-resolved and write a static resolv.conf pointing at my AdGuard Home server (dns01). The Ansible playbook handles this in pre_tasks before Docker installation.

### Debian Trixie Has No Docker Packages

The new Proxmox cluster runs Proxmox 9 on Debian Trixie (testing). Docker doesn't publish packages for Trixie yet. The Ansible role detects this and falls back to Bookworm:

```yaml
docker_codename: >-
  {{ 'bookworm'
     if ansible_facts['distribution_release'] in ['trixie', 'testing', 'n/a']
     else ansible_facts['distribution_release'] }}
```

### apt-key Is Dead

The old `ansible.builtin.apt_key` module fails on newer Debian because `apt-key` was removed. Modern approach: download the GPG key to `/etc/apt/keyrings/` and reference it with `signed-by` in the repo line. Same for `lsb_release` — it's not installed on Proxmox, so use `ansible_facts['distribution_release']` instead.

### CephFS Templates Save Time

The first mc03 creation failed because pve03 didn't have the Ubuntu template downloaded locally. Uploading to `cephfs-ssd` once makes it available on all nodes — no per-node template management.

## The Result

6 servers, 6 backup sidecars, 3 LXCs, one Ansible role:

| LXC | Server | Port | Mode |
|-----|--------|------|------|
| mc01 (pve01) | survival | 25565 | Survival |
| mc01 (pve01) | creative | 25566 | Creative |
| mc02 (pve02) | adventure | 25565 | Survival (hard) |
| mc02 (pve02) | minigames | 25566 | Survival |
| mc03 (pve03) | hardcore | 25565 | Hardcore |
| mc03 (pve03) | modded | 25566 | Fabric |

Each server gets ~4-6GB RAM (Paper with Aikar's flags), weekly auto-updates, and daily backups with 7-day retention. Adding a new server is one YAML block in inventory.

## What's Next

- Tailscale on the LXCs so friends can connect remotely (#317)
- Velocity proxy for a shared lobby (#316)
- BlueMap for web-based world maps (#316)
- Backblaze B2 offsite backup (reusing the jellyfin rclone pattern)
