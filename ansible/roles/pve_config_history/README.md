# pve_config_history

Hourly git history of `/etc/pve` plus each node's rebuild files, on every Proxmox
node (#434). Off-cluster copy: #568.

## What it keeps, and where

| | path (on every node) | covers |
|---|---|---|
| git history | `/var/lib/pve-config-history` | `etc-pve/`: all of `/etc/pve`, so every node's guest configs, storage, HA, firewall, users, ceph; `node-local/`: this node's network, hosts, fstab, grub, modprobe/sysctl/udev, corosync, `/etc/ceph`, apt sources, systemd units |
| pmxcfs database | `/var/lib/pve-config-history-db` | `config.db` (latest, refreshed hourly) plus `config.db.daily.YYYY-MM-DD` (7), `config.db.weekly.YYYY-Www` (4) and `config.db.monthly.YYYY-MM` (12), all UTC |

- Commits only when something changed; each commit message lists the changed paths.
- Both directories are `0700 root`: they hold `/etc/pve/priv` (cluster CA key,
  ceph keyrings), `/etc/ceph` and `/etc/corosync/authkey`, the same secrets the
  node already holds. **Git keeps every old version forever**: rotating a key does
  not remove the old one from history. Never copy these directories to Ceph/CephFS,
  a synced folder or anywhere unencrypted (the encrypted off-cluster copy is #568).
- Not kept: pmxcfs entries that change on their own (`.rrd`, `.version`,
  `.members`, `.clusterlog`, `.vmlist`, `.debug`, `ha/manager_status`,
  `ha/crm_commands`, `nodes/*/lrm_status`, `priv/lock`) and the ticket-signing keys
  Proxmox rotates daily and regenerates (`priv/authkey.key`, `authkey.pub*`).
- Each run copies `config.db` first, then takes the git snapshot. Either half
  failing does not stop the other; the run still fails, and
  `pve-config-history-failure.service` alerts through `/etc/apprise.yml`.
- Three copies, one per node disk: survives accidental edits, pmxcfs/corosync
  trouble and losing a node. Not the whole cluster; that is #568.

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

### Put back one guest config

The guest may have migrated since that commit, and its disks, snapshots or
`lock:` line may have changed. Restoring blindly can create a duplicate VMID or
point the guest at disks that no longer exist.

```
cd /var/lib/pve-config-history
find /etc/pve/nodes -name <vmid>.conf               # where it lives NOW
git show <commit>:etc-pve/nodes/<host>/qemu-server/<vmid>.conf > /tmp/<vmid>.conf
diff /tmp/<vmid>.conf /etc/pve/nodes/<now-host>/qemu-server/<vmid>.conf
qm shutdown <vmid>                                  # or pct shutdown for an LXC
cp /tmp/<vmid>.conf /etc/pve/nodes/<now-host>/qemu-server/<vmid>.conf
```

For a container use `lxc/` in place of `qemu-server/` and `pct` in place of `qm`.

Write it to the node the guest lives on now. pmxcfs refuses writes without
quorum; do this once the cluster is quorate.

### Put back a node-local file

`git show` writes symlinks out as plain text (e.g. `/etc/ceph/ceph.conf` is a
symlink to `/etc/pve/ceph.conf`). Extract with `git archive` instead, which keeps
symlinks and the executable bit. Git does **not** keep other modes: everything
comes back 0644/0755, so reset the mode of anything private (keys, keyrings)
after copying. Diff before overwriting:

```
cd /var/lib/pve-config-history
mkdir -p /tmp/restore
git -c tar.umask=022 archive <commit> node-local/etc/network/interfaces | tar -x -C /tmp/restore
diff /tmp/restore/node-local/etc/network/interfaces /etc/network/interfaces
cp -a /tmp/restore/node-local/etc/network/interfaces /etc/network/interfaces
ifreload -a
```

A bad `interfaces` cuts the node off the network: have console access before
`ifreload`.

### Whole cluster lost: rebuild from a surviving disk

**Untested here.** This follows the Proxmox recovery approach for pmxcfs (read
the "Recovery" section of the Proxmox cluster file system docs first). It is a
last resort: if any node still runs, restore from that instead.

Reinstall Proxmox on the node with its **old hostname and IP**, then attach the
old root disk read-only (here at `/mnt/old`). Its LVM volume group is also named
`pve`, the same as the fresh install's, so rename it on import first
(`vgimportclone` the old PV, or `vgrename <old-vg-uuid> pve_old`). Then:

```
old=/mnt/old/var/lib
mkdir -p /tmp/restore
systemctl stop pve-cluster corosync
rm -f /var/lib/pve-cluster/config.db-wal /var/lib/pve-cluster/config.db-shm
ls $old/pve-config-history-db/       # latest, or a daily/weekly/monthly copy from before the problem
install -m 0600 $old/pve-config-history-db/config.db /var/lib/pve-cluster/config.db
cd $old/pve-config-history
git -c tar.umask=022 archive HEAD node-local/etc/corosync node-local/etc/hosts node-local/etc/hostname \
  | tar -x -C /tmp/restore
cp -a /tmp/restore/node-local/etc/corosync/. /etc/corosync/
chmod 0755 /etc/corosync && chmod 0400 /etc/corosync/authkey    # git does not keep these
cp -a /tmp/restore/node-local/etc/hosts /tmp/restore/node-local/etc/hostname /etc/
reboot
```

After the reboot, a node alone in a 3-node `corosync.conf` has no quorum and
`/etc/pve` stays read-only until you run `pvecm expected 1`. Check
`ls /etc/pve/nodes/*/qemu-server` before touching any guest. The leftover
`-wal`/`-shm` removal matters: pairing an old WAL with the restored database
corrupts it.

## Check it is working

A commit only appears when something changed, so `git log` says nothing about
whether snapshots are still running. Check freshness instead:

```
systemctl list-timers pve-config-history.timer         # LAST should be < ~70 min ago
systemctl status pve-config-history.service             # last run's result
ls -l /var/lib/pve-config-history-db/config.db          # mtime refreshed every run
```

The first snapshot happens at the next hourly run. To take it right after
deploying: `systemctl start pve-config-history.service`.

If the timer itself is disabled or removed, nothing runs and nothing alerts; the
failure alert also stays silent if `/etc/apprise.yml` is missing.

## Limits

Checked at the start of every run. Today's use is ~3.5 MiB per node.

| limit | default | when hit |
|---|---|---|
| free space on the history's filesystem (the root disk) | 2 GiB (`pve_config_history_min_free_mb`) | writes nothing this run: this job can never be what fills the disk |
| history + `config.db` copies | 1 GiB (`pve_config_history_max_mb`) | stops committing to git until a human looks; `config.db` copies keep refreshing |
| early warning | 200 MiB (`pve_config_history_warn_mb`) | keeps working |

Each limit alerts at most once a day; in between, the run only logs it
(`journalctl -u pve-config-history.service`).

**Why retention is by time, and the git history is never pruned.** Keeping "the
last N changes" is the wrong limit for a backup: a script loop or a busy evening
of edits would push out exactly the history you need when you notice a problem
weeks later. `config.db` copies are kept 7 daily / 4 weekly / 12 monthly (at
most ~3 MiB). The git history keeps everything: text diffs of config files are
a few MB a year, and rewriting history to prune it is the riskiest thing you can
do to a backup. If it ever does approach the cap, a human decides:

### Squash: start a fresh history, keeping the old one

```
cd /var/lib
systemctl stop pve-config-history.timer pve-config-history.service   # and any run in progress
du -sh pve-config-history                       # confirm it is the history that grew
git -C pve-config-history log --stat -20        # and what grew it (a file to exclude?)
(umask 077; tar -czf /root/pve-config-history-$(hostname -s)-$(date -u +%F).tgz pve-config-history)
                                                # 0600 from the start: same secrets as the repo
rm -rf pve-config-history/.git
systemctl start pve-config-history.service      # re-initialises with one baseline commit
systemctl start pve-config-history.timer
```

Move the archive off the node (encrypted, see #568) or delete it once you are
sure you will not need the old history. If something unexpected was growing it,
add it to `pve_config_history_excludes` first.

## Turn it off

`pve_config_history_enabled: false` removes the timer, units and script. The
history in `/var/lib/pve-config-history*` is left in place; delete it by hand if
you really mean to.
