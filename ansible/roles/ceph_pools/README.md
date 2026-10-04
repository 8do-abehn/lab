# ceph_pools

Cluster-wide Ceph pool and balancer settings for the Proxmox-managed cluster (#559).
Run through `ansible/ceph_pools.yml`, never `site.yml`: the balancer change starts
HDD backfill, so it runs when chosen.

What it enforces:

- No pool on `replicated_rule`. It spans both device classes, and while any pool
  uses it the PG autoscaler skips **every** pool ("contains an overlapping root...
  skipping scaling"). `.mgr` is moved to `ssd_rule`; any other pool found there
  (Proxmox creates new pools on it by default) fails the run before anything is
  written.
- `mgr/balancer/upmap_max_deviation` = 1 (Ceph default 5).

## Runbook

Commands marked **pve** run as root on any Proxmox node; the rest run from
`~/8do/lab/ansible` on main.

### 1. Baseline (pve)

```
ceph -s                                   # HEALTH_OK, all PGs active+clean
ceph balancer eval                        # note the score
ceph osd df | grep hdd                    # HDD %USE, 31-41% on 2026-10-04
ceph osd dump | grep pg_upmap_items > /root/upmap-before-559.txt
```

### 2. Apply

Preferred, so `deploy-drift` records it as deployed:

```
gh workflow run ansible-deploy.yml -f playbook=ceph_pools.yml
```

Or locally:

```
ansible-playbook ceph_pools.yml --check --diff    # plans .mgr -> ssd_rule, deviation 5 -> 1
ansible-playbook ceph_pools.yml
```

### 3. What to expect (pve)

- Within a minute or two the balancer adds up to 10 upmaps, then the rest on its
  next pass (~18 in total on 2026-10-04, ~151 GiB, each swapping a replica between
  the two HDDs of one host).
- `ceph -s` shows PGs `remapped` / `backfilling` while health stays **HEALTH_OK**.
  Backfill is throttled by mclock (`balanced` profile) and capped at 5% misplaced.
- `ceph osd pool autoscale-status` is no longer empty. The HDD pools show NEW
  PG_NUM 128 but are not resized (the autoscaler only acts past 3x).

Done when every PG is `active+clean`. Then:

```
ceph balancer eval        # lower than the baseline
ceph osd df | grep hdd    # HDD %USE within ~34.6-36.9%
```

### Pause

```
ceph osd set norebalance      # pause backfill of PGs that are only misplaced
ceph osd unset norebalance    # resume
```

Health shows **HEALTH_WARN** (OSDMAP_FLAGS) while the flag is set. That is the
flag, not a problem.

`ceph balancer off` only stops the balancer creating more upmaps; data for the
upmaps it already made keeps moving unless `norebalance` is set.

### Roll back

Setting the deviation back to 5 does **not** move data back: the upmaps the
balancer created stay. Undo them explicitly:

```
ceph balancer off
ceph config set mgr mgr/balancer/upmap_max_deviation 5
diff /root/upmap-before-559.txt <(ceph osd dump | grep pg_upmap_items)
ceph osd rm-pg-upmap-items <pgid>        # for each pgid with a ">" line
ceph balancer on
```

`rm-pg-upmap-items` drops **every** mapping of that PG. If a pgid also has a "<"
line (the balancer changed or dropped a mapping that existed before), restore
its original entry from the baseline file afterwards:

```
# baseline line:  pg_upmap_items 6.8 [3,8]
ceph osd pg-upmap-items 6.8 3 8
```

Then re-run the diff; it should be empty.

Moving `.mgr` back (`pveceph pool set .mgr --crush_rule replicated_rule`) disables
the autoscaler for every pool again, and this role will then fail on every run.
There is no reason to do it.
