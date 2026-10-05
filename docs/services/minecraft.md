# Minecraft

Six Minecraft servers across 3 LXC containers, run with Docker Compose.

## Where It Runs

| Host | LXC ID | Managed by Ansible |
|------|--------|--------------------|
| mc01 | 3004 | yes |
| mc02 | 3005 | yes |
| mc03 | 3006 | no (commented out in inventory) |

The LXCs are Proxmox HA resources on Ceph RBD, so the node they run on changes.
Check the current node with `pvesh get /cluster/resources --type vm` rather than
trusting a doc. IPs and node notes are in the [inventory](../../ansible/inventory/).

## Servers

| Server | Host | Port | Type | Version | Memory |
|--------|------|------|------|---------|--------|
| survival | mc01 | 25565 | Vanilla | 26.3 | 6G |
| creative | mc01 | 25566 | Vanilla | 26.3 | 4G |
| oneblock | mc01 | 25567 | Vanilla + Skyblock Infinite | 26.3 | 4G |
| skyblock (x2) | mc02 | 25567, 25568 | Vanilla + Skyblock Infinite | 26.3 | 4G |
| cobblemon | mc03 | 25565 | Fabric + Cobblemon | 1.21.1 | 8G |

Versions are pinned per server in the host_vars files, not `LATEST`. Clients must
run the exact same version as the server.

Images: `itzg/minecraft-server:java25` by default (26.x needs Java 25). Cobblemon
overrides it to `java21` because Cobblemon only targets 1.21.1.

The skyblock servers set `LEVEL: skyblock-infinite`, so the active world lives in
`/data/skyblock-infinite`. The old pre-datapack world is still in `/data/world`.

## Upgrading

1. Check every datapack/mod supports the target version on Modrinth:
   `curl -s "https://api.modrinth.com/v2/project/<slug>/version?limit=5"`
   and read `game_versions`. A world upgraded to a newer format cannot be
   downgraded.
2. Snapshot the LXC on Proxmox (`pct snapshot <id> pre-<version>`) and force a
   fresh backup (`docker exec mc-backup-<name> backup now`).
3. Bump `version` in host_vars, PR, then deploy from `main`.
4. Join each server and confirm the world loads.

## Backups

Each server has a backup sidecar (`itzg/mc-backup`):

- **Interval:** every 24 hours
- **Retention:** 7 days
- **Method:** RCON save-off, tarball of all of `/data`, stored in a Docker volume
- **Idle skip:** skips the backup if no players have been online

These backups live on the same LXC as the server, so they protect against world
corruption, not against losing the container.

## Auto-Updates

Weekly cron (Sunday 4:00 AM) pulls the latest container images and recreates
changed containers. The game version stays pinned, so this updates the image and
sidecars, not Minecraft itself.

## Ansible

- **Role:** [`minecraft`](../../ansible/roles/minecraft/)
- **Host vars:** [`mc01.yml`](../../ansible/inventory/host_vars/mc01.yml), [`mc02.yml`](../../ansible/inventory/host_vars/mc02.yml), [`mc03.yml`](../../ansible/inventory/host_vars/mc03.yml)
- **Inventory group:** `minecraft_servers`

## Known Issues

| Issue | Description |
|-------|-------------|
| [#316](https://github.com/8do-abehn/lab/issues/316) | Enhancement spike: Velocity proxy, web maps, Prometheus metrics |
