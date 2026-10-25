# Mealie

Self-hosted recipe manager: recipe import from a URL, meal plans and shopping
lists. Tracked in [#675](https://github.com/8do-abehn/lab/issues/675).

## Where It Runs

| Property | Value |
|----------|-------|
| Host | mealie01 |
| LXC ID | 3018 |
| Proxmox Node | HA-managed |
| Tailscale Service | `svc:mealie` |
| Port | 9000 |

IPs and Tailscale addresses are in the [inventory](../../ansible/inventory/).

Installed from the community-scripts Mealie helper, the same split as Immich:
the helper script owns the application (install and upgrades), and Ansible owns
networking, DNS, monitoring and backup.

## Build

1. On any pve node, run the community-scripts Mealie helper in Advanced mode:
   CT ID `3018`, hostname `mealie01`, unprivileged, rootfs on `rbd-ssd`,
   bridge on VLAN 70.
2. Tailnet policy: add `tag:mealie` to `tagOwners`, and
   `"svc:mealie": ["tag:mealie"]` to `autoApprovers.services`
   (see [roles/homepage/README.md](../../ansible/roles/homepage/README.md)).
3. Admin console: define the `svc:mealie` Service on port 443.
4. Generate a `tag:mealie` auth key and store it as
   `vault_tailscale_mealie_auth_key` with `ansible-vault edit ansible/vault.yml`.
5. From `main`: `ansible-playbook site.yml --check --diff --limit mealie01,mem01`,
   then the same without `--check`. mem01 picks up the homepage tile.
6. Open `https://mealie.<tailnet>`, sign in with the default admin, and change
   its password and email immediately.

## Configuration

Set in the Mealie UI, not in code. Recorded here so a rebuild reproduces them:

| Setting | Value | Why |
|---------|-------|-----|
| Base URL | `https://mealie.<tailnet>` | Used in share links and invites |
| Sign-ups | disabled | Household accounts are created by invitation |

## Backups

**Pending the install** ([#675](https://github.com/8do-abehn/lab/issues/675)):
the database engine the helper chooses (SQLite or Postgres) decides how the
consistent copy is taken. As with mem01, restic must never take a live database
file: a snapshot (`sqlite3 .backup` or `pg_dump`) runs first, and restic backs up
that copy plus the data directory (recipe images).

## Ansible

- **Roles:** [`tailscale`](../../ansible/roles/tailscale/), [`netdata`](../../ansible/roles/netdata/)
- **Group vars:** [`mealie_servers.yml`](../../ansible/inventory/group_vars/mealie_servers.yml)
- **Inventory group:** `mealie_servers`

There is no `mealie` service role. The community script owns the install.
