---
title: "Rebuilding My Homelab: From 9 Nodes to 3 with Proxmox 9 and Ceph"
date: 2026-03-07
draft: false
tags: ["proxmox", "ceph", "homelab", "ansible"]
description: "How I consolidated a sprawling 9-node Proxmox 8 cluster into a lean 3-node Proxmox 9 cluster with Ceph storage, GPU passthrough, and fully automated Ansible management."
---

## The Problem

My homelab had grown organically into a 9-node Proxmox 8 cluster on a flat 10.150.10.0/24 network. Six i5/i7 machines (pve001-006) with 16GB RAM each, plus three Ryzen 9 5900X machines (pve007-009) with 64-128GB RAM and dedicated GPUs. The old nodes were underpowered, the network was a mess, and managing it all was getting painful.

It was time to consolidate.

## The Plan

Rebuild the three Ryzen machines as a proper 3-node cluster with:
- **Proxmox 9** (fresh installs, not upgrades)
- **Ceph** for distributed storage
- **VLANs** for network segmentation (management, storage, guest)
- **Ansible** for repeatable configuration
- Keep the legacy cluster running during migration

## Hardware

Each node is a Ryzen 9 5900X (12C/24T) with serious storage:

| Node | RAM | GPU | NVMe (local) | SSD (Ceph) | HDD (Ceph) |
|------|-----|-----|-------------|-----------|-----------|
| pve01 | 128GB | 2x RX 570 | 2TB | 4TB | 2TB |
| pve02 | 64GB | 1x RTX 3080 Ti | 2TB | 4TB | 2TB |
| pve03 | 128GB | 2x RTX 3080 | 2TB | 4TB | 2TB |

Total Ceph capacity: ~16TB across 6 OSDs (3 SSD, 3 HDD) with device class separation for tiered storage.

## Network Architecture

I carved out three VLANs on my Ubiquiti gear:

```
VLAN 60 — Management  (10.150.60.0/24)  Proxmox hosts
VLAN 65 — Storage     (10.150.65.0/24)  Ceph replication
VLAN 70 — Guest       (10.150.70.0/24)  VMs and LXCs
```

Keeping Ceph traffic on its own VLAN prevents storage replication from competing with VM traffic. This was a big upgrade from the flat network where everything shared the same subnet.

### The 10G Detour

I bought a 10G switch and some server-grade copper 10G NICs off eBay to upgrade the storage network. The NICs all had tiny fans that were well past their lifespan — they overheated quickly and I couldn't trust them for 24/7 operation. Luckily, each node came with at least a 2.5GbE NIC (Intel I225-V), and pve02 already had a fanless Aquantia 10G from its previous life.

At 2.5G, Ceph replication and VM migrations still hit ~294 MB/s — not 10G speeds, but plenty for a homelab. I'm keeping an eye out for fanless desktop 10G NICs (Aquantia AQC113, Intel X550-T1) to upgrade the other two nodes when good deals come up.

## The Build

### Proxmox 9 Installation

Each node got a fresh Proxmox 9 install on a small boot SSD. I used the [community post-install script](https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh) to disable the enterprise repo and set up the no-subscription repo — run this from the Proxmox host shell, not SSH.

### Ceph Setup

Setting up Ceph across the three nodes went smoothly once I wiped the old LVM signatures:

```bash
# On each node, for each disk:
wipefs -a /dev/sdX
sgdisk --zap-all /dev/sdX
pveceph osd create /dev/sdX
```

The key decision was keeping the 2TB NVMe drives **local** (not Ceph). These are LVM-thin pools named `nvme-local` for VM root disks that need fast local I/O — like the gaming VMs with GPU passthrough. Ceph gets the 4TB SSDs and 2TB HDDs for distributed storage.

#### Standardizing Local Storage Names

One thing I didn't get right on the first pass: each node ended up with a different name for its NVMe storage (`nvme2tb`, `nvme-vg`, `nvme-local`). This matters because Proxmox uses storage names for migrations — if the source and target have the same storage name, `qm migrate` knows where to put the disk without extra flags.

I standardized everything to `nvme-local` across all three nodes. For pve01, this meant migrating the gaming VMs off, deleting the old plain LVM volume group, and recreating it as LVM-thin. Worth the effort — now any VM can migrate between nodes without specifying `--targetstorage`.

Final OSD tree with device class separation:

```
ID  CLASS  WEIGHT    TYPE NAME
-1         16.37500  root default
-3          5.45830      host pve01
 0    ssd   3.63910          osd.0    (4TB SSD)
 1    hdd   1.81920          osd.1    (2TB HDD)
-5          5.45830      host pve02
 2    ssd   3.63910          osd.2
 3    hdd   1.81920          osd.3
-7          5.45830      host pve03
 4    ssd   3.63910          osd.4
 5    hdd   1.81920          osd.5
```

### Gaming VM Migrations

The boys have Windows 11 gaming VMs with GPU passthrough. Migrating them required:

1. Shut down the VM
2. Remove all passthrough devices (hostpci, usb) — these block migration
3. `qm migrate <vmid> <target> --targetstorage nvme-local --online 0`
4. Re-add GPU and USB passthrough on the target node
5. Boot and test

Each 750GB disk took about 45 minutes at ~294 MB/s over the 2.5G network.

**Lesson learned**: One migration failed mid-copy during a power outage. The VM was locked (`qm unlock <vmid>` fixed it) and left an orphan LV on the target. Always check for orphans after a failed migration.

## Ansible Automation

### Inventory Restructuring

The biggest Ansible change was supporting both clusters simultaneously:

```yaml
proxmox:
  children:
    proxmox_pve00x:   # Legacy (pve001-006)
    proxmox_pve0x:    # New (pve01-03)
```

Each cluster gets its own group vars — the legacy cluster has NUT/UPS config, the new cluster has its own Tailscale auth key. Shared settings (SSH user, Netdata) live in the parent `proxmox` group.

### NUT/UPS Fix

A power outage revealed that the NUT role's auto-detection was broken — it was detecting the UPS server (pve004) as a client because the serial probe was unreliable. I replaced the detection logic with a simple inventory group check:

```yaml
# Before: fragile serial detection
- name: Detect UPS presence on this host
  include_tasks: detect.yml

# After: inventory is the source of truth
- name: Set NUT mode from inventory group membership
  set_fact:
    nut_mode: "{{ 'server' if 'nut_server' in group_names else 'client' }}"
```

### CI/CD Pipeline

Every PR runs through GitHub Actions:
1. **ansible-lint** — catches style issues
2. **Test Against Infrastructure** — runs `--check --diff` against real hosts via Tailscale
3. **Manual Deploy** — `workflow_dispatch` to apply changes with a Netdata health check

The CI runner connects to all hosts through Tailscale, so it works the same whether the hosts are on VLAN 10, 60, or anywhere on the tailnet.

## Gotchas

A few things that bit me:

- **`pvesm remove` is cluster-wide**: Removing a storage entry from one node removes it from all nodes. I learned this when a VM migration failed because the source storage disappeared mid-copy.
- **Ghost nodes after decommission**: Old nodes leave VM/LXC configs in `/etc/pve/nodes/`. Use `pvecm delnode` to remove from corosync, then `rm -rf /etc/pve/nodes/<name>/` to clean up configs. I found dozens of ghost VMs and LXCs from three decommissioned nodes cluttering the UI.
- **Orphan disks from forgotten services**: During a job search, I'd spun up a bunch of services (Ollama, various LXCs) and forgotten about them. When I decommissioned the nodes, the root disks were left behind on the NVMe drives. Inventorying what's actually running before a rebuild saves cleanup time later.
- **Tailscale auth keys are tag-scoped**: The legacy cluster used `tag:ci` + `tag:media`, but the new cluster needed `tag:proxmox`. Separate keys, separate vault variables.
- **ansible_host IPs before Tailscale**: New nodes need IP addresses in the inventory until Tailscale is installed. After that, remove the overrides and let Tailscale DNS handle it.

## What's Next

- **CephFS** with CRUSH rules for tiered storage (SSD pool for metadata + hot data, HDD pool for bulk)
- **Migrate services** from legacy cluster — jellyfin, unifi controller, docker (Minecraft servers), changedetection
- **Ollama** re-deployment with RTX 3080 Ti (12GB VRAM vs the old RX 570s)
- **UPS migration** to new cluster with USB-serial adapter
- Power down the legacy nodes

## Before and After

```
BEFORE (2025)                          AFTER (2026)
─────────────────────                  ─────────────────────
9 nodes, flat network                  3 nodes, VLANed
Proxmox 8                             Proxmox 9
Local storage only                    Ceph + local NVMe
16GB RAM per legacy node              64-128GB RAM per node
Manual config                         Ansible-managed
Serial UPS detection (broken)         Inventory-based (reliable)
```

The new cluster has more compute, more storage, and better network isolation in a third of the nodes. Sometimes less really is more.
