# pve_config_offsite (+ pve_config_receiver)

Daily, encrypted, write-only copy of each Proxmox node's `/etc/pve` history
(roles/pve_config_history, #434) to the backup host (#568). The history holds the
cluster CA key, ceph keyrings and corosync authkey, so it leaves the node only as
**age** ciphertext to keys that are never on the cluster.

## How it works

| | where | what |
|---|---|---|
| push (daily ~03:30) | each node | `git bundle` of the history + latest `config.db`, tarred in tmpfs, encrypted with `age` to every listed recipient, sent with its SHA-256 over a dedicated ssh key |
| receive | the target backup host, user `pvecfg` | each node's key is forced to `pvecfg-receive <node>`: stores the upload only if it is age ciphertext, under 16 MiB, matches the SHA-256, and the node is under 1 GiB with 2 GiB free on the disk. Names the file itself. Cannot list, read, overwrite or delete. |
| prune (daily 06:30) | the target backup host, root | keeps 7 daily / 4 weekly / 12 monthly per node; **alerts if a node has not pushed for 48 h** |

The backup host's ssh host key is pinned from Ansible (never trust-on-first-use).
`pvecfg` has a locked password, publickey only, no tty or forwarding
(`/etc/ssh/sshd_config.d/99-pvecfg.conf`), and its keys live in a root-owned
`/etc/ssh/authorized_keys.d/pvecfg`. Settings: `inventory/group_vars/proxmox.yml`.

## What it protects against, and what not

- **House fire, or losing the whole cluster:** covered. The backup host is in a
  separate building (pi-burg in the shed; pve006 at another site after #512).
- **Ransomware or root on one node:** it cannot delete or overwrite stored copies.
  It can push junk copies, which retention would keep alongside the good ones.
- **Root on the backup host:** sees only ciphertext and cannot reach the nodes. It
  can delete copies, or plant forged ones: age encryption proves nothing about who
  made a file, since anyone with the public key can create one.
- **So after any compromise,** restore from a copy older than it (the monthly tier
  goes back about 12 months) and read `git log` before trusting what you restore.
- **Losing every private key** makes every copy unreadable. Hence two keys, below.

## Turn it on (once)

On your Mac, not on the cluster:

```
brew install age
age-keygen -o pve-config.key            # primary: prints "Public key: age1..."
age-keygen -o pve-config-offline.key    # second, offline key
```

1. Store `pve-config.key` (the `AGE-SECRET-KEY-1...` line) in Bitwarden as a
   secure note. Print `pve-config-offline.key` and keep the paper **outside the
   house**: a fire there must not take it with the cluster, and don't count on
   reaching Bitwarden in the middle of a disaster.
2. Before deleting the files, check what you stored matches: `age-keygen -y` on
   each stored copy re-derives its public key, and must print exactly the two
   public keys you are about to commit.
3. Delete both key files from the Mac.
4. Commit the two **public** keys in `ansible/inventory/group_vars/proxmox.yml`:
   ```
   pve_config_offsite_recipients:
     - age1...   # primary (Bitwarden)
     - age1...   # offline (paper)
   ```
5. After merging, deploy so deploy-drift records it:
   `gh workflow run ansible-deploy.yml -f playbook=site.yml -f tags=pve_config`
6. First push, then a real test, so a mismatched key is found now and not during a
   disaster: on a node `systemctl start pve-config-offsite.service`, then run the
   restore drill below against that first copy, once with each key.

## Check it is working

On the backup host: `sudo sh -c 'ls -l /mnt/backup/pve-config/*/'` (one file per
node per day) and `systemctl status pvecfg-prune.service`. On a node:
`systemctl list-timers pve-config-offsite.timer`. A node that stops pushing for
48 h alerts from the backup host; a failed push alerts from the node.

## Restore (and the yearly drill)

On a machine with `age` and one private key; never copy a key onto the cluster.
The decrypted files hold the cluster's secrets: work in a private temporary
directory and remove it afterwards.

```
d=$(mktemp -d) && cd "$d"
age -d -i pve-config.key -o payload.tar /path/to/pve01-20261008T033012Z.tar.age \
  && tar -xf payload.tar \
  && git clone -q history.bundle history \
  && git -C history fsck --no-dangling \
  && sqlite3 config.db 'PRAGMA quick_check;'
git -C history log -3 --stat                      # recent, and what you expect?
```

Decrypting to a file first means a damaged or truncated copy fails before
anything is extracted (the partial `payload.tar` stays in the temporary directory). For a real restore, continue with
roles/pve_config_history/README.md ("Whole cluster lost"), using `history/` and
`config.db` from here. For a drill, finish with `cd / && rm -rf "$d"`.

Do the drill once a year, with each key.

## Rotating or adding a key

Add the new public key to the list and deploy; from then on every copy is
readable by either key. Remove the old one only when you no longer need copies
made before the change: the monthly tier keeps them about 12 months, and those
still need the old private key.

## Moving to another backup host (#512)

1. Add the new host to `backup_servers` and set `pve_config_offsite_target` to it
   in `group_vars/proxmox.yml` (plus `pve_config_offsite_target_address` if its
   inventory name does not resolve from the nodes). Only the target runs as the
   active receiver; any other backup host stops accepting pushes and stops
   alerting.
2. Deploy (`site.yml --tags pve_config`): the new host gets the receiver, and the
   nodes pin its host key and push there.
3. If the backup disk itself moves to the new host, the copies come with it.
   Otherwise copy `/mnt/backup/pve-config/` across (`rsync -a`); file names carry
   the timestamps, so retention keeps working.
4. Remove the old host from `backup_servers` once it is retired.

## Turn it off

Set `pve_config_offsite_recipients: []` and deploy. The nodes stop pushing and
their units are removed (their ssh keys are kept); the backup host stops accepting
pushes and stops the daily stale-copy check, so a switched-off feature does not
alert. Stored copies are left in place.

## Safety notes

- A node's push key is under that node's control, so the receiver only ever
  authorizes the first two fields of a single `ssh-ed25519` key and refuses
  anything else: an extra line in a node's key file can never become an
  unrestricted login on the backup host.
- On/off, the target and the node list come from inventory, and each node's key is
  this run's or the one already authorized, so `--limit` or an unreachable node
  never cuts the other nodes off.
