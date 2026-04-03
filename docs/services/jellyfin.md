# Jellyfin

Media server for movies, TV, and music.

## Where It Runs

| Property | Value |
|----------|-------|
| Host | jellyfin01 |
| LXC ID | 3001 |
| Proxmox Node | pve01 |
| Tailscale Service | `svc:jellyfin` |
| Port | 8096 |

IPs and Tailscale addresses are in the [inventory](../../ansible/inventory/).

## How to Connect

Access via Tailscale Service. Non-Tailscale devices (Rokus, TVs) reach it through dns01's subnet router and AdGuard DNS rewrites.

Legacy access via EdgeRouter DNAT rule is still active for old Roku configs (#337).

## Backups

Two parallel backup jobs:

| Job | Destination | Schedule | Managed By |
|-----|-------------|----------|------------|
| restic | pi-burg | Daily 2:00 AM | `backup_client` role |
| rclone | Backblaze B2 | Daily midnight | `jellyfin_backup` role |

Restic retention: 7 daily, 4 weekly, 6 monthly. Weekly integrity check Sundays at 6:00 AM. Notifications via Apprise (Gmail SMTP).

The rclone/B2 backup is marked for deprecation (#72) once restic is fully verified.

## Ansible

- **Role:** [`backup_client`](../../ansible/roles/backup_client/), [`jellyfin_backup`](../../ansible/roles/jellyfin_backup/)
- **Group vars:** [`media_servers.yml`](../../ansible/inventory/group_vars/media_servers.yml)
- **Inventory group:** `media_servers`

## Known Issues

| Issue | Description |
|-------|-------------|
| [#337](https://github.com/8do-abehn/lab/issues/337) | Remove EdgeRouter DNAT rule after Roku apps updated |
| [#335](https://github.com/8do-abehn/lab/issues/335) | Retire pve005 — old jellyfin LXC still stopped there |
| [#269](https://github.com/8do-abehn/lab/issues/269) | Prune old `jellyfin` host snapshots from restic repo |
| [#313](https://github.com/8do-abehn/lab/issues/313) | MagicDNS leaks into LXC resolv.conf on reboot |

GPU acceleration (VAAPI) packages are installed but not actively used for transcoding.
