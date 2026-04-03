# Minecraft

6 Minecraft servers across 3 LXC containers, managed via Docker Compose.

## Where It Runs

| Host | LXC ID | Proxmox Node |
|------|--------|--------------|
| mc01 | 3004 | pve01 |
| mc02 | 3005 | pve02 |
| mc03 | 3006 | pve03 |

IPs are in the [inventory](../../ansible/inventory/). Default Minecraft port is 25565, second server on each host uses 25566.

## Servers

| Server | Host | Port | Type | Mode | Memory |
|--------|------|------|------|------|--------|
| survival | mc01 | 25565 | Paper | survival | 6G |
| creative | mc01 | 25566 | Paper | creative | 4G |
| adventure | mc02 | 25565 | Paper | hard | 6G |
| minigames | mc02 | 25566 | Paper | survival | 4G |
| hardcore | mc03 | 25565 | Paper | hard (hardcore) | 6G |
| modded | mc03 | 25566 | Fabric | survival | 8G |

All servers use `itzg/minecraft-server:java21` with Aikar's JVM flags. Version set to `LATEST`.

## Backups

Each server has a backup sidecar (`itzg/mc-backup`):

- **Interval:** Every 24 hours
- **Retention:** 7 days
- **Method:** RCON pause, tarball, Docker volume
- **Idle skip:** Pauses backup if no players online

## Auto-Updates

Weekly cron (Sunday 4:00 AM) pulls latest container images and restarts: `docker compose pull && docker compose up -d`.

## Ansible

- **Role:** [`minecraft`](../../ansible/roles/minecraft/)
- **Host vars:** [`mc01.yml`](../../ansible/inventory/host_vars/mc01.yml), [`mc02.yml`](../../ansible/inventory/host_vars/mc02.yml), [`mc03.yml`](../../ansible/inventory/host_vars/mc03.yml)
- **Inventory group:** `minecraft_servers` (currently commented out — no Tailscale SSH, see #317)

## Known Issues

| Issue | Description |
|-------|-------------|
| [#317](https://github.com/8do-abehn/lab/issues/317) | No Tailscale or Netdata on Minecraft LXCs — breaks CI |
| [#316](https://github.com/8do-abehn/lab/issues/316) | Enhancement spike: Velocity proxy, web maps, Prometheus metrics |
| [#326](https://github.com/8do-abehn/lab/issues/326) | CI slowdown from `check_mode: false` docker compose pull |
