---
title: "Proxmox Node Decommission Runbook"
date: 2025-12-04
draft: true
tags: ["proxmox", "ansible", "tailscale", "containers", "lxc", "runbook"]
---


## Overview
Step-by-step guide for safely removing a Proxmox node from the cluster, including Ceph storage, Proxmox cluster membership, and Tailscale network.

## Prerequisites
- SSH access to the node being decommissioned
- SSH access to at least one other cluster node
- Cluster is healthy (check with `pvecm status`)
- If using Ceph: At least 2 other nodes with OSDs remaining
- For cross-cluster LXC migration: Tailscale ACL allows SSH between cluster tags (e.g., `tag:proxmox` → `tag:proxmox`). Without this, direct `scp` between clusters fails with `tailnet policy does not permit you to SSH to this node`.

## Pre-Decommission Checklist

### 1. Identify Node to Decommission
```bash
# On any cluster node
pvecm nodes
```

### 2. Check for Running VMs/Containers
```bash
# On the node to be decommissioned
qm list           # VMs
pct list          # Containers

# Count running instances
qm list | grep running | wc -l
pct list | grep running | wc -l
```

### 3. Check Ceph Status (if applicable)
```bash
# Check if node has Ceph OSDs
ceph osd tree

# Check cluster health
ceph -s

# Check node's OSDs
pveceph osd tree | grep -A 5 "$(hostname)"

# List OSDs on this node
ceph osd ls-tree $(hostname)
```

## Decommission Steps

### Phase 1: Migrate Workloads

#### A. Migrate VMs
```bash
# List VMs with their IDs
qm list

# Migrate each VM to another node
# Online migration (VM stays running)
qm migrate <VMID> <target-node> --online

# Offline migration (VM stops, migrates, starts)
qm migrate <VMID> <target-node>

# Batch migrate all VMs (example for node pve007)
for vmid in $(qm list | grep running | awk '{print $1}'); do
  echo "Migrating VM $vmid..."
  qm migrate $vmid pve005 --online
done
```

#### B. Migrate Containers
```bash
# List containers
pct list

# Migrate each container
pct migrate <CTID> <target-node> --restart

# Batch migrate all containers
for ctid in $(pct list | grep running | awk '{print $1}'); do
  echo "Migrating CT $ctid..."
  pct migrate $ctid pve005 --restart
done
```

#### C. Verify All Workloads Migrated
```bash
# Should show no running VMs/CTs
qm list
pct list
```

#### D. Cross-Cluster LXC Migration

When migrating LXCs between separate Proxmox clusters (different corosync, different Ceph), `pct migrate` is not available. Use vzdump + scp + pct restore instead.

**Prereqs:**
- Tailscale ACL allows SSH between cluster tags (see Prerequisites)
- Target cluster has a storage pool with enough free space (e.g., `rbd-ssd`)
- Pick a new VMID that doesn't collide on the target cluster
- **Check for stale DHCP static mappings tied to the LXC's MAC.** If the source cluster's DHCP server (e.g., EdgeRouter) has a `static-mapping` reserving an IP on the source VLAN pool for the LXC's MAC, DHCP on the target VLAN will silently fail — dnsmasq matches the MAC to the old static entry and sends the OFFER out the wrong interface. The LXC will keep sending `DHCPDISCOVER` with no response and no log entries to explain why.
   ```bash
   # Find stale mappings on EdgeRouter
   show configuration commands | match static-mapping
   # Delete before migrating (or regenerate the LXC MAC with: pct set <ctid> --net0 name=eth0,bridge=vmbr0,ip=dhcp,type=veth)
   ```
- **Plan for IP-baked-in services.** If adopted devices have the old LXC IP hardcoded (unifi UAPs, printers, monitoring probes), you'll need a DNAT + proxy-ARP rule on the router so the old IP keeps working after the LXC moves to a new VLAN (see step 8 below).

**Steps:**

1. Remove the container from HA. `vzdump --mode stop` fails on HA-managed services with `Cannot execute a backup with stop mode on a HA managed and enabled Service`.
   ```bash
   # From any node in the source cluster
   ha-manager remove ct:<CTID>
   ```

2. Backup the container to local storage:
   ```bash
   # On the source node
   vzdump <CTID> --mode stop --compress zstd --storage local
   ```

3. Transfer the dump to the target node (requires cross-cluster SSH ACL):
   ```bash
   # From the source node
   scp /var/lib/vz/dump/vzdump-lxc-<CTID>-*.tar.zst <target-node>:/var/lib/vz/dump/
   ```

4. Restore on the target node with a new VMID:
   ```bash
   # On the target node
   pct restore <NEW-CTID> /var/lib/vz/dump/vzdump-lxc-<CTID>-*.tar.zst --storage <target-storage>
   ```

5. Start and verify:
   ```bash
   pct start <NEW-CTID>
   pct exec <NEW-CTID> -- ip -4 addr show eth0
   pct exec <NEW-CTID> -- tailscale status
   # Verify the application service is running
   ```

6. **Immediately** stop (do not destroy) the original container as a rollback:
   ```bash
   # On the source node
   pct stop <CTID>
   ```
   Note: `vzdump --mode stop` auto-restarts the container when the backup finishes. For LXCs running Tailscale, having both the old and new instance online with the same node key causes an identity race — one gets logged out. Stop the original as soon as the backup completes, before running the restore on the target.

7. Post-migration network updates. For services with IP-baked-in clients (unifi, jellyfin, any custom integrations):
   - **DNAT rule on the router** redirecting `<old-ip>:<port>` → `<new-ip>:<port>` for each relevant port. On EdgeRouter:
     ```
     set service nat rule <N> description '<service> legacy IP redirect'
     set service nat rule <N> type destination
     set service nat rule <N> protocol tcp
     set service nat rule <N> inbound-interface switch0+
     set service nat rule <N> destination address <old-ip>
     set service nat rule <N> destination port <port>
     set service nat rule <N> inside-address address <new-ip>
     set service nat rule <N> inside-address port <port>
     ```
   - **Proxy-ARP / secondary IP.** DNAT alone isn't enough if clients live on the **same VLAN** as the old IP — they reach it via L2 ARP and never traverse the router where DNAT would kick in. Give the router a secondary `/32` address matching the old IP so the router answers ARP and DNAT fires:
     ```
     set interfaces switch switch0 address <old-ip>/32
     ```
   - **Update DHCP option 43 / service discovery** pointers (e.g., `unifi-controller`, `bootfile-server`, custom options) that referenced the old IP.
   - **Clean up stale DHCP static mappings** for the old LXC on the old VLAN (the ones that caused the prereq DHCP failure).

8. After a verification period (typically 24-48h of live traffic), destroy the original LXC and clean up the dump files on both nodes.

### Phase 2: Remove from Ceph Cluster (if applicable)

**IMPORTANT:** Only proceed if you have at least 2 other nodes with OSDs and cluster is healthy.

#### A. Check Replication Settings
```bash
# Ensure you have enough replicas
ceph osd pool ls detail | grep size
# Should show: size 3, min_size 2 (or similar)
```

#### B. Stop OSDs on Node
```bash
# List OSDs on this node
ceph osd tree | grep -A 10 "$(hostname)"

# Stop each OSD (replace X with actual OSD number)
systemctl stop ceph-osd@X
```

#### C. Mark OSDs Out
```bash
# For each OSD on this node (replace X with actual OSD number)
ceph osd out osd.X

# Example for multiple OSDs
for osd in 0 1 2; do
  ceph osd out osd.$osd
done
```

#### D. Wait for Rebalancing
```bash
# Monitor rebalancing progress (this can take a LONG time)
watch ceph -s

# Wait until:
# - All PGs are active+clean
# - No misplaced or degraded objects
# - HEALTH_OK or HEALTH_WARN (acceptable warnings only)
```

#### E. Remove OSDs from Cluster
```bash
# For each OSD (replace X with actual OSD number)
ceph osd purge osd.X --yes-i-really-mean-it

# Or via Proxmox UI:
# Datacenter > Ceph > OSD > Select OSD > More > Destroy
```

#### F. Remove Monitor (if this node runs one)
```bash
# Check if node has a monitor
ceph mon stat

# Remove monitor (from another node)
pveceph mon destroy <node-name>
```

#### G. Remove Manager (if this node runs one)
```bash
# Check if node has a manager
ceph mgr stat

# Remove manager
pveceph mgr destroy <node-name>
```

#### H. Verify Ceph Cleanup
```bash
# Node should not appear in Ceph topology
ceph osd tree
ceph mon stat
ceph mgr stat
```

### Phase 3: Remove from Proxmox Cluster

**IMPORTANT:** Perform these steps from ANOTHER cluster node, NOT the node being removed.

#### A. Verify Node is Offline or Ready
```bash
# From another cluster node
pvecm nodes

# Ensure no VMs/CTs are running on target node
ssh <node-to-remove> "qm list && pct list"
```

#### B. Remove Node from Cluster
```bash
# From another cluster node (NOT the one being removed)
pvecm delnode <node-name>

# Example:
pvecm delnode pve007
```

#### C. Verify Cluster Status
```bash
# Check cluster is healthy
pvecm status
pvecm nodes

# Node should no longer appear in the list
```

#### D. Clean Up Stale Configuration Files
```bash
# On each remaining cluster node, remove stale configs
rm -rf /etc/pve/nodes/<removed-node-name>

# Example:
rm -rf /etc/pve/nodes/pve007
```

### Phase 4: Remove from Tailscale

#### A. Remove from Tailscale Admin Console
1. Go to https://login.tailscale.com/admin/machines
2. Find the machine with hostname matching the node (e.g., `pve007`)
3. Click the "..." menu
4. Select "Delete"
5. Confirm deletion

#### B. (Optional) Uninstall Tailscale from Node
```bash
# On the decommissioned node, if still accessible
tailscale logout
apt-get remove --purge tailscale
rm -rf /var/lib/tailscale
```

### Phase 5: Clean Up Ansible Inventory

#### A. Remove from Inventory
```bash
# Edit inventory file
vi ansible/inventory/homelab.yml

# Remove or comment out the node
# Example:
#     pve007:
#       ansible_host: 10.150.10.47
```

#### B. Remove Host Variables (if any)
```bash
# Check for host-specific variables
ls ansible/host_vars/

# Remove if exists
rm -rf ansible/host_vars/pve007.yml
```

#### C. Update Documentation
- Update any architecture diagrams
- Update capacity planning documents
- Update monitoring dashboards

### Phase 6: Final Decommission

#### A. Verify All Services Stopped
```bash
# On the decommissioned node
systemctl list-units --state=running | grep -E 'pve|ceph|corosync'

# Should show no cluster services
```

#### B. (Optional) Wipe Disks
```bash
# If repurposing or disposing of hardware
# ⚠️  DANGER: This will erase ALL data

# For each disk (replace /dev/sdX)
wipefs -a /dev/sdX
sgdisk --zap-all /dev/sdX
dd if=/dev/zero of=/dev/sdX bs=1M count=100
```

#### C. Power Down
```bash
shutdown -h now
```

## Verification Checklist

After decommission, verify:

- [ ] All VMs/containers successfully migrated and running
- [ ] Ceph cluster is healthy (if applicable): `ceph -s`
- [ ] Ceph has no references to old node: `ceph osd tree`
- [ ] Proxmox cluster is healthy: `pvecm status`
- [ ] Node removed from cluster: `pvecm nodes`
- [ ] Tailscale admin console shows node deleted
- [ ] Ansible inventory updated
- [ ] No monitoring alerts for removed node

## Rollback Plan

If you need to add the node back:

1. **Rejoin Proxmox cluster:**
   ```bash
   # On the node
   pvecm add <existing-node-ip>
   ```

2. **Rejoin Ceph (if applicable):**
   ```bash
   # Recreate monitor
   pveceph mon create

   # Recreate OSDs (for each disk)
   pveceph osd create /dev/sdX
   ```

3. **Re-authenticate Tailscale:**
   ```bash
   # Make sure old entry is deleted first
   tailscale up --authkey=<key> --hostname=<node-name> --advertise-tags=tag:proxmox --ssh
   ```

4. **Re-add to Ansible inventory**

## Common Issues

### Issue: "Node still has quorum votes"
**Solution:** Use force removal:
```bash
pvecm delnode <node-name> --force
```

### Issue: "Ceph won't rebalance"
**Cause:** Not enough space or replicas
**Solution:**
```bash
# Check space
ceph df

# Temporarily adjust replica settings (use with caution)
ceph osd pool set <pool-name> size 2
ceph osd pool set <pool-name> min_size 1
```

### Issue: "Node still appears in /etc/pve"
**Solution:** Manually remove from each node:
```bash
rm -rf /etc/pve/nodes/<node-name>
```

### Issue: "Tailscale hostname conflict later"
**Prevention:** Always delete old Tailscale entry before re-provisioning
**Fix:** Delete duplicate entries in Tailscale admin console

## Related Documentation

- [Proxmox Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)
- [Ceph OSD Management](https://docs.ceph.com/en/latest/rados/operations/add-or-rm-osds/)
- [Tailscale Machine Management](https://tailscale.com/kb/1099/device-management/)
- [LXC Migration Troubleshooting](./lxc-migration-troubleshooting.md)

## Notes

- **Timing:** Ceph rebalancing can take hours or days depending on data size
- **Minimum Nodes:** Don't go below 3 nodes for Proxmox + Ceph clusters
- **Backups:** Always verify backups before decommissioning
- **Testing:** Test migrations in maintenance window if possible
- **Communication:** Notify team/users of scheduled maintenance

## Changelog

- 2026-04-11: Expanded cross-cluster LXC migration procedure with network gotchas
  - Added prereq: check for stale DHCP static mappings on source VLAN pool (causes silent DHCPDISCOVER failure on target VLAN)
  - Added prereq: plan for IP-baked-in clients (adopted unifi devices, etc.) before migrating
  - Added step 7 (post-migration network updates): DNAT rules, proxy-ARP secondary IP trick, DHCP option 43 / service discovery updates
  - Emphasized stopping the original container immediately after vzdump (Tailscale identity race if both instances stay online)
- 2026-04-09: Added cross-cluster LXC migration procedure
  - Documented vzdump + scp + `pct restore` flow for migrating between separate Proxmox clusters
  - Added HA removal prerequisite (`vzdump --mode stop` fails on HA-managed services)
  - Added Tailscale ACL prerequisite for direct cross-cluster scp
- 2024-12-03: Initial runbook created
  - Added Tailscale hostname conflict prevention
  - Added Ansible inventory cleanup steps
  - Added comprehensive verification checklist
