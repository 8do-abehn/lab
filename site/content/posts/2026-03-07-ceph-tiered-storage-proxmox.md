---
title: "Setting Up Tiered Ceph Storage with CephFS and RBD on Proxmox 9"
date: 2026-03-07
draft: false
tags: ["ceph", "proxmox", "homelab", "storage"]
description: "How I configured Ceph with CRUSH rules to separate SSD and HDD tiers, then set up both CephFS and RBD pools for different workloads on a 3-node Proxmox 9 cluster."
---

## The Setup

I have a 3-node Proxmox 9 cluster, each with a 4TB SSD and 2TB HDD dedicated to Ceph. The NVMe drives stay local for fast VM storage. The question was: how do I use the SSDs for performance-sensitive workloads and the HDDs for bulk storage?

```
Per Node:
  2TB NVMe  → nvme-local (LVM-thin, not Ceph)
  4TB SSD   → Ceph OSD (fast tier)
  2TB HDD   → Ceph OSD (bulk tier)
```

## CRUSH Rules: Telling Ceph Where to Put Data

Ceph already knows which OSDs are SSDs and which are HDDs — it assigns device classes automatically. But by default, it'll spread data across all OSDs regardless of type. CRUSH rules let you pin pools to specific device classes.

```bash
ceph osd crush rule create-replicated ssd_rule default host ssd
ceph osd crush rule create-replicated hdd_rule default host hdd
```

That's it. Two rules: one that only uses SSDs, one that only uses HDDs. The `host` parameter ensures replicas land on different nodes.

## The Pool Layout

I created six pools across two storage types:

### CephFS Pools (shared filesystem)

CephFS needs a metadata pool and one or more data pools. Metadata goes on SSD because it's small and latency-sensitive.

```bash
# Metadata pool (small, fast)
ceph osd pool create cephfs_meta 32 32 replicated ssd_rule

# SSD data pool (ISOs, templates, snippets)
ceph osd pool create cephfs_ssd 64 64 replicated ssd_rule

# HDD data pool (backups, media files)
ceph osd pool create cephfs_hdd 64 64 replicated hdd_rule
ceph osd pool set cephfs_hdd bulk true
```

Then create the filesystem and add the HDD pool as a secondary data pool:

```bash
ceph fs new cephfs cephfs_meta cephfs_ssd
ceph fs add_data_pool cephfs cephfs_hdd
```

### RBD Pools (block devices for VMs/LXCs)

CephFS is great for shared files, but VM and LXC disks need block storage. RBD (RADOS Block Device) is purpose-built for this.

```bash
ceph osd pool create rbd-ssd 64 64 replicated ssd_rule
ceph osd pool create rbd-hdd 64 64 replicated hdd_rule
ceph osd pool set rbd-hdd bulk true
rbd pool init rbd-ssd
rbd pool init rbd-hdd
```

### Why Both CephFS and RBD?

They serve different purposes on the same OSDs:

| Storage | Type | Best For |
|---------|------|----------|
| CephFS | Shared filesystem | ISOs, templates, backups, media libraries |
| RBD | Block device | VM disks, LXC rootfs — anything that needs raw I/O |

Think of it like having both an NFS share and a SAN on the same hardware.

## MDS: The Missing Piece

CephFS requires at least one Metadata Server (MDS). On Proxmox, create one per node — the active MDS handles metadata operations, standbys take over if it fails.

```bash
# Run on each node:
pveceph mds create
```

Verify with `ceph mds stat` — you should see one active and two standby.

## Adding Storage to Proxmox

This is where I hit a snag. My Ceph monitors bind to the storage VLAN (10.150.65.x), not the management VLAN (10.150.60.x). Using the wrong IPs for `--monhost` caused mount timeouts and cryptic errors.

**The fix**: always use the IPs where your Ceph monitors actually listen.

```bash
# Check where monitors are bound:
ceph mon dump | grep mon

# Use those IPs for Proxmox storage:
pvesm add rbd rbd-ssd --pool rbd-ssd --content images,rootdir \
  --monhost 10.150.65.21,10.150.65.22,10.150.65.23

pvesm add rbd rbd-hdd --pool rbd-hdd --content images,rootdir \
  --monhost 10.150.65.21,10.150.65.22,10.150.65.23

pvesm add cephfs cephfs-ssd --content iso,vztmpl,snippets \
  --monhost 10.150.65.21,10.150.65.22,10.150.65.23 --fs-name cephfs

pvesm add cephfs cephfs-hdd --content backup \
  --monhost 10.150.65.21,10.150.65.22,10.150.65.23 --fs-name cephfs
```

## The Final Layout

```bash
$ pvesm status | grep -E "cephfs|rbd|nvme"
cephfs-hdd      cephfs     active     ~16TB    HDD tier
cephfs-ssd      cephfs     active     ~16TB    SSD tier
rbd-hdd            rbd     active     ~1.8TB   HDD tier
rbd-ssd            rbd     active     ~3.5TB   SSD tier
nvme-local     lvmthin     active     ~1.8TB   Local per node
```

Five storage tiers, each with a clear purpose:

- **nvme-local**: Fastest. Gaming VMs with GPU passthrough, anything that needs raw local NVMe speed.
- **rbd-ssd**: Fast, shared. LXC/VM root disks that need to migrate between nodes. Jellyfin's OS disk goes here.
- **rbd-hdd**: Shared, bulk. VMs that don't need speed.
- **cephfs-ssd**: Shared filesystem. ISOs, LXC templates, cloud-init snippets. Upload once, available on all nodes.
- **cephfs-hdd**: Shared filesystem, bulk. Backups and media libraries. Jellyfin's `/mnt/library` goes here.

## Practical Example: Jellyfin

When I migrate Jellyfin to the new cluster, the storage split will be:

- **Root disk** → `rbd-ssd` (OS, app, database — needs random I/O)
- **Media library** → `cephfs-hdd` (movies, music, TV — sequential reads, doesn't need SSD)

The media is replicated across all three nodes automatically. If a node goes down, Jellyfin keeps streaming from the surviving copies.

## Gotchas

- **Monitor IPs matter**: `ceph mon dump` shows where monitors actually listen. If you have a separate storage VLAN, use those IPs — not your management VLAN.
- **`pvesm remove` is cluster-wide**: Learned this the hard way during VM migrations. Removing storage on one node removes the config from all nodes.
- **Bulk flag**: Set `ceph osd pool set <pool> bulk true` on HDD pools so the PG autoscaler makes better decisions.
- **pmxcfs locks**: If `pvesm add` times out, the Proxmox cluster config can get locked. `systemctl restart pve-cluster` usually clears it.
- **Keyring files**: CephFS needs both a keyring and a secret file in `/etc/pve/priv/ceph/`. RBD pools create these automatically, CephFS sometimes doesn't.
