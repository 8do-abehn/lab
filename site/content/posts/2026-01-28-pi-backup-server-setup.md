---
title: "Pi Backup Server Setup"
date: 2026-01-28
draft: true
tags: ["proxmox", "ansible", "tailscale", "media-server"]
---


**Date:** 2026-01-28

## Summary

Configured a Raspberry Pi (pi-burg) as a local backup server for Jellyfin's `/mnt/library` using restic with daily scheduled backups.

## Architecture

```
┌─────────────┐    restic backup     ┌─────────────┐
│  Jellyfin   │ ──────────────────▶  │  Pi Backup  │
│ /mnt/library│     (direct IP)      │ /mnt/backup │
└─────────────┘                      └─────────────┘
     2am daily cron                   2TB USB disk
```

## What Was Done

### Infrastructure
- Added `pibackup` host to Ansible inventory (10.150.10.140)
- Created `backup_server` role: disk mounting, restic repo init, backup user
- Created `backup_client` role: backup script, cron job, logrotate
- Created `backup-setup.yml` playbook

### Challenges Encountered
1. **Tailscale on Debian Trixie** - No trixie repo yet, modified role to use bookworm
2. **Disk I/O errors** - Old APFS metadata causing read errors around sector 409xxx
   - USB kept resetting every ~30 seconds
   - Resolved by manually wiping with `wipefs -a` and reformatting
3. **Tailscale ACLs blocking SSH** - Worked around by using direct IP instead of hostname
4. **SSH key setup** - Had to manually set up key-based auth from Jellyfin to Pi

### First Backup
- Started: 12:43 PM
- Size: ~1 TB (4962 files)
- Status: Running

## Files Created/Modified

| File | Action |
|------|--------|
| `ansible/inventory/homelab.yml` | Added backup_servers group |
| `ansible/roles/backup_server/*` | New role |
| `ansible/roles/backup_client/*` | New role |
| `ansible/backup-setup.yml` | New playbook |
| `ansible/roles/tailscale/tasks/install.yml` | Added trixie→bookworm fallback |

## Follow-up Issues Created

- **#69** - Expand ZFS storage on pve005 for Jellyfin
- **#70** - Update Tailscale ACLs and use Tailscale for Pi backups
- **#71** - Send backup logs to Netdata for monitoring
- **#72** - Disable Backblaze B2 backups after Pi backup verified

## Lessons Learned

1. Old Mac-formatted drives may have corrupted metadata that causes intermittent I/O errors
2. Raspberry Pi OS is now based on Debian Trixie (13) - newer than most package repos support
3. Always test disk operations manually before automating if there are any hardware concerns
4. Tailscale ACLs need to explicitly allow SSH between nodes

## Next Steps

1. Monitor first backup completion
2. Verify restore works
3. Update Tailscale ACLs (#70)
4. Set up Netdata monitoring (#71)
5. Disable B2 backups once Pi backup is proven (#72)
