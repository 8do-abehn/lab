# Immich

Self-hosted photo and video library, migrated from Google Photos.

## Where It Runs

| Property | Value |
|----------|-------|
| Host | immich01 |
| LXC ID | 3013 |
| Proxmox Node | pve03 |
| Tailscale Service | `svc:immich` |
| Port | 2283 |

IPs and Tailscale addresses are in the [inventory](../../ansible/inventory/).

Installed from the community-scripts Immich helper, which pins a tested Immich
version rather than tracking upstream. Ansible owns networking, DNS, monitoring
and backup; the helper script owns the application itself.

## Storage

| Mount | Storage | Size | Holds |
|-------|---------|------|-------|
| rootfs | `rbd-ssd` | 68 GB | OS, Postgres + VectorChord, ML model cache |
| `/opt/immich/upload` | `rbd-ssd` | 1200 GB | entire Immich data tree |
| `/staging` | `rbd-ssd` | 700 GB | **temporary**, Google Takeout zips; delete after import |

Deliberately RBD rather than CephFS. Immich has one consumer of its library and
needs no shared-filesystem semantics, and RBD avoids the boot-order race that
cost jellyfin01 three days of empty backups when its ceph-fuse mount failed.

Deliberately `rbd-ssd` rather than `rbd-hdd`: at the time of building, the HDD
tier was 34% used and shared with jellyfin01's growing library, while the SSD
tier was 3% used. `pct move-volume` can relocate it later if that inverts.

Immich **fails to start** if `/opt/immich/upload` is not mounted, via the
`.immich` marker files it writes in each subfolder. That is a feature: it fails
loudly rather than silently serving an empty library.

## Configuration

Set in Administration > Settings, not in code. Recorded here so a rebuild
reproduces them:

| Setting | Value | Why |
|---------|-------|-----|
| Storage Template | enabled | Off by default since 1.92.0. Gives date-based readable paths so photos are findable on disk without the database. Must be on before the first import or a migration job has to run over the whole library. |
| Backup (database) | `30 2 * * *`, keep 3 | 02:30 puts a fresh dump 30 minutes ahead of the 03:00 restic run. Keep 3 rather than 14 because the dumps are gzipped and do not dedup in restic. |

## Hardware Acceleration

`/dev/dri` and `/dev/kfd` are passed through for **VAAPI video transcoding**,
which still has to be enabled in Immich Settings.

Machine learning runs on **CPU**. The RX 570 is Polaris/gfx803, dropped from
ROCm 6.x, and more decisively the install script has no ROCm path at all: its
only GPU machine-learning option is Intel OpenVINO, which needs Intel hardware.

All three nodes expose `card0`, `renderD128` and `/dev/kfd`, so the passthrough
does not prevent HA migration. The latent hazard is that pointing a gaming VM at
an RX 570 would strip `/dev/dri` from that node.

## Backups

**Not yet configured. This host is deliberately not a `backup_clients` member.**

pi-burg's `wlan0` negotiates 5.5 Mbit/s and its `eth0` is unplugged (#478), giving
a measured ~1.2 MB/s. Immich's roughly 600 GB first backup would take about six
days at that rate. With no concurrency guard in `backup_client` (#479) the nightly
cron would relaunch and stack, and because every client shares one restic repo it
would contend for locks with jellyfin01's working backup.

**Interim protection:** the photos still exist in Google Photos. Do not delete
them from Google until immich01 has a verified snapshot. Ceph `size=3` covers disk
and host failure but not deletion, corruption, or site loss.

### Planned, once eth0 is connected

| Job | Destination | Schedule |
|-----|-------------|----------|
| restic | pi-burg | Daily 3:00 AM |

Staggered off jellyfin01's 02:00 so the two clients never contend for the shared
repo lock, and late enough to capture Immich's 02:30 database dump. Weekly
integrity check Sundays 7:00 AM.

Back up `/opt/immich/upload` and `/opt/immich/.env` -- the `.env` carries the
installer-generated database password and lives on the rootfs, outside the library
volume. Exclude `thumbs/` and `encoded-video/`, both regenerable.

Add via `backup-setup.yml` run against both hosts in one invocation, so pi-burg
authorizes the new key in the same run that generates it.

## Ansible

- **Role:** [`backup_client`](../../ansible/roles/backup_client/), [`tailscale`](../../ansible/roles/tailscale/), [`netdata`](../../ansible/roles/netdata/)
- **Group vars:** [`immich_servers.yml`](../../ansible/inventory/group_vars/immich_servers.yml)
- **Host vars:** [`immich01.yml`](../../ansible/inventory/host_vars/immich01.yml)
- **Inventory group:** `immich_servers`

There is no `immich` service role. The community script owns the install, and a
role that fought it would misrepresent what manages what.

## Known Issues

| Issue | Description |
|-------|-------------|
| [#313](https://github.com/8do-abehn/lab/issues/313) | MagicDNS leaks into LXC resolv.conf on reboot |

Public sharing via Cloudflare Tunnel is deliberately not configured. An Immich
share link fetches its assets through `/api/...`, which Cloudflare Access
challenges along with everything else, so bypassing only `/share/*` yields a page
of broken images. Making share links work for people without accounts means
bypassing `/api`, leaving Immich's own login as the only internet-facing barrier.
