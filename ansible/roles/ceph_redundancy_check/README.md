# ceph_redundancy_check

Emails through Apprise when the Ceph cluster loses redundancy (#529). Runs every
5 minutes on each Ceph node, from `site.yml` under the `ceph` tag, together with
`ceph_daemon_restart`.

## What alerts

| key | meaning |
|---|---|
| `OSD_DOWN`, `OSD_HOST_DOWN`, `MON_DOWN` | daemons or a whole node down |
| `MDS_INSUFFICIENT_STANDBY`, `MGR_STANDBY` | no standby left to fail over to |
| `MDS_ALL_DOWN`, `FS_DEGRADED`, `FS_WITH_FAILED_MDS`, `MGR_DOWN` | CephFS or the mgr unavailable |
| `PG_AVAILABILITY` | inactive PGs, so guest I/O is blocked |
| `NO_QUORUM` | this node cannot reach a mon quorum (reported by each node about itself) |
| `NOOUT` | `noout` left set for more than 8 hours |

Every other warning (insecure keys, clock skew, crash reports...) is ignored, and so
is any check muted with `ceph health mute`.

- **One email per incident.** Only the alphabetically-first mon in quorum reports
  cluster problems. Around a change of reporter, two nodes can briefly both send.
- **Debounced on both edges.** A problem must show on two consecutive runs (about
  10 minutes) to alert, and be gone for two to clear. While it lasts, it
  re-alerts every 12 hours.

## Not covered

- **A node that is cut off can't send.** On 2026-09-27 all three nodes were cut off
  for ~20 hours, so nothing could have been delivered. Off-cluster alerting is
  #555.
- **Losing one of two standbys is silent.** Only having zero standbys alerts.
- **There is no fallback sender.** If the reporting node's sends fail, no other node
  takes over the email.

## Runbook

Commands marked **pve** run as root on a Proxmox node. The rest run from
`~/8do/lab/ansible` on main.

**Planned maintenance (rebooting a node)**

```
ceph osd set noout          # pve, before
ceph osd unset noout        # pve, after the node is back and `ceph -s` is clean
```

While `noout` is set, the per-node keys (OSD/MON down, standbys) are not alerted.
`PG_AVAILABILITY`, `MDS_ALL_DOWN`, `FS_*` and `NO_QUORUM` still alert, because those
mean something is actually unavailable. If `noout` is still set after 8 hours, that
alerts as well.

**Silence one known warning instead**

```
ceph health mute OSD_DOWN 4h      # pve; the TTL makes it expire on its own
ceph health unmute OSD_DOWN       # pve
```

**Test it**

```
ceph-redundancy-check --dry-run   # pve: what it sees, what it would send. Sends nothing, writes no state
ceph-redundancy-check --test      # pve: sends one real test email. Exits 1 if apprise failed
systemctl list-timers ceph-redundancy-check.timer
journalctl -u ceph-redundancy-check.service -n 20
cat /var/lib/ceph-redundancy-check/state.json   # what is open, and since when
```

**Turn it off**

Set `ceph_check_enabled: false`, then run `ansible-playbook site.yml --tags ceph`.
That disables the timer and removes the script, units and state. To stop it on
one node right away without Ansible:

```
systemctl disable --now ceph-redundancy-check.timer   # pve
```

## `ceph_daemon_restart` (same play)

This role installs a drop-in for `ceph-{osd,mds,mgr}@` so daemons that die waiting
on quorum keep retrying (#529). Its defaults file has the reasoning and the
start-limit arithmetic. Deploying it only runs `daemon-reload`; no daemon restarts.

```
systemctl show ceph-osd@4 -p RestartForceExitStatus,StartLimitBurst,RestartUSec   # pve: SIGHUP, 5, 30s
```

To roll it back, set `ceph_restart_enabled: false` and run `--tags ceph`. That
removes the drop-in and reloads systemd.

To stop an OSD that keeps restarting, run `systemctl stop ceph-osd@N` (pve). A unit
you stop yourself is never restarted automatically.
