# pve_config_offsite (+ pve_config_receiver)

Daily, encrypted, write-only copy of each Proxmox node's `/etc/pve` history
(roles/pve_config_history, #434) to the backup host (#568). The history holds the
cluster CA key, ceph keyrings and corosync authkey, so it leaves the node only as
**age** ciphertext to a key that is never on the cluster.

## How it works

| | where | what |
|---|---|---|
| push (daily ~03:30) | each node | `git bundle` of the history + latest `config.db`, tarred in tmpfs, encrypted with `age` to the recipient, sent with its SHA-256 over a dedicated ssh key |
| receive | backup host, user `pvecfg` | each node's key is forced to `pvecfg-receive <node>`: stores the upload only if it is age ciphertext, under 16 MiB, matches the SHA-256, and the node is under 1 GiB with 2 GiB free on the disk. Names the file itself. Cannot list, read, overwrite or delete. |
| prune (daily 06:30) | backup host, root | keeps 7 daily / 4 weekly / 12 monthly per node; **alerts if a node has not pushed for 48 h** |

The backup host's ssh host key is pinned from Ansible (never trust-on-first-use).
`pvecfg` has a locked password, publickey only, no tty or forwarding
(`/etc/ssh/sshd_config.d/99-pvecfg.conf`), and its keys live in a root-owned
`/etc/ssh/authorized_keys.d/pvecfg`.

## Turn it on (once)

Disabled until a recipient is set. On your Mac, not on the cluster:

```
brew install age
age-keygen -o pve-config.key        # prints "Public key: age1..."
```

1. Store the whole contents of `pve-config.key` (the `AGE-SECRET-KEY-1...` line) in
   Bitwarden as a secure note, and keep a second offline copy (printed, in the safe).
   Without it the copies cannot be decrypted; with it, anyone can read the cluster's
   secrets.
2. Delete `pve-config.key` from the Mac.
3. Set the **public** key (it is safe to commit) in (create the file if missing)
   `ansible/inventory/group_vars/proxmox.yml`:
   `pve_config_offsite_recipient: age1...`
4. From main: `ansible-playbook site.yml --tags pve_config`, then on a node
   `systemctl start pve-config-offsite.service` for the first push.

## Check it is working

On the backup host: `sudo ls -l /mnt/backup/pve-config/*/` (a file per node per
day) and `systemctl status pvecfg-prune.service`. On a node:
`systemctl list-timers pve-config-offsite.timer`.

## Restore

On any machine with `age` and the private key (never copy the key onto the cluster):

```
set -o pipefail                                  # a damaged file must stop the restore
age -d -i pve-config.key pve01-20261008T033012Z.tar.age | tar -x -C restore/
git clone restore/history.bundle restore/history # the full /etc/pve history
ls restore/config.db                             # the pmxcfs database
```

Then follow roles/pve_config_history/README.md ("Whole cluster lost") with
`restore/history` and `restore/config.db` in place of the node's local copies.

Do a restore drill once a year: decrypt the newest copy, `git clone` it, and check
`git log -1` is recent.

## Moving to another backup host (#512)

1. Add it to `backup_servers` and set `pve_config_offsite_target` (and
   `_target_address` if its inventory name does not resolve from the nodes).
2. `ansible-playbook site.yml --tags pve_config`: the new host gets the receiver,
   the nodes pin its host key and push there.
3. Copy the old host's `/mnt/backup/pve-config/` across (`rsync -a`); file names
   carry the timestamps, so retention keeps working.

## Turn it off

Set `pve_config_offsite_recipient: ""` and run `site.yml --tags pve_config`. The
nodes stop pushing and their units are removed (the ssh key is kept); the backup
host stops accepting pushes (its authorized keys file is removed) and stops the
daily stale-copy check, so a switched-off feature does not alert. Stored copies
are left in place.

## Safety notes

- A node's push key is under that node's control, so the receiver only ever
  authorizes the first two fields of a single `ssh-ed25519` key and refuses
  anything else: an extra line in a node's key file can never become an
  unrestricted login on the backup host.
- On/off and the node list come from inventory, and each node's key is this run's
  or the one already authorized, so `--limit` or an unreachable node never cuts
  the other nodes off.
