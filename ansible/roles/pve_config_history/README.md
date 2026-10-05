# pve_config_history

Hourly git history of `/etc/pve` plus each node's rebuild files, on every Proxmox
node (#434). Off-cluster copy: #568.

## What it keeps, and where

| | path (on every node) | covers |
|---|---|---|
| git history | `/var/lib/pve-config-history` | `etc-pve/`: all of `/etc/pve`, so every node's guest configs, storage, HA, firewall, users, ceph; `node-local/`: this node's network, hosts, fstab, grub, modprobe/sysctl/udev, corosync, `/etc/ceph`, apt sources, systemd units |
| pmxcfs database | `/var/lib/pve-config-history-db` | `config.db` (latest, hourly) and `config.db.YYYY-MM-DD` (7 dailies, UTC) |

- Commits only when something changed; each commit message lists the changed paths.
- Both directories are `0700 root`: they hold `/etc/pve/priv` (cluster CA key,
  ceph keyrings) and `/etc/corosync/authkey`, the same secrets `/etc/pve` already
  holds on the node. Do not copy them anywhere unencrypted.
- Not kept: pmxcfs status/stat entries that change on their own (`.rrd`,
  `.version`, `.members`, `.clusterlog`, `.vmlist`, `ha/manager_status`,
  `nodes/*/lrm_status`, `priv/lock`) and the ticket-signing keys
  (`priv/authkey.key`, `authkey.pub*`) that Proxmox rotates daily and regenerates.
- Three copies, one per node disk: survives accidental edits, pmxcfs/corosync
  trouble and losing a node. Not the whole cluster; that is #568.
- If the snapshot fails, `pve-config-history-failure.service` alerts through
  `/etc/apprise.yml`.

## Restore

All as root on a node. Use `nodes/<host>/...` paths: `local/`, `qemu-server/` and
`lxc/` at the top of `/etc/pve` are symlinks to the current node's directory.

### See what changed

```
cd /var/lib/pve-config-history
git log --stat                                    # every change, newest first
git log -p -- etc-pve/nodes/pve01/qemu-server/101.conf
git log -p -- node-local/etc/network/interfaces
```

### Put back one guest config (cluster quorate)

```
git show <commit>:etc-pve/nodes/<host>/qemu-server/<vmid>.conf > /tmp/<vmid>.conf
diff /tmp/<vmid>.conf /etc/pve/nodes/<host>/qemu-server/<vmid>.conf
cp /tmp/<vmid>.conf /etc/pve/nodes/<host>/qemu-server/<vmid>.conf
```

pmxcfs refuses writes without quorum; restore once the cluster is quorate.

### Put back a node-local file

```
git show <commit>:node-local/etc/network/interfaces > /etc/network/interfaces
```

### Whole cluster lost, rebuild from a surviving disk

`config.db` is the pmxcfs database itself. The Proxmox procedure for recovering a
cluster from it, on a reinstalled node with the same hostname and IP:

```
systemctl stop pve-cluster corosync
cp /var/lib/pve-config-history-db/config.db /var/lib/pve-cluster/config.db
cp -r <history>/node-local/etc/corosync/* /etc/corosync/
systemctl start corosync pve-cluster
```

Read the Proxmox "Recovery" section of the cluster manager docs before doing this
for real; it is a last resort, not a routine step.

## Check it is working

```
systemctl list-timers pve-config-history.timer
journalctl -u pve-config-history.service -n 20
git -C /var/lib/pve-config-history log -1
```

## Turn it off

`pve_config_history_enabled: false` removes the timer, units and script. The
history in `/var/lib/pve-config-history*` is left in place; delete it by hand if
you really mean to.
