---
title: "Proxmox Node Onboarding Runbook"
date: 2025-12-04
draft: false
tags: ["proxmox", "ansible", "tailscale", "runbook"]
summary: "Step-by-step guide for adding a new Proxmox node to a cluster, including Ceph, Tailscale, and Ansible automation."
---


## Overview
Step-by-step guide for adding a new Proxmox node to the cluster, including hardware preparation, cluster join, Ceph configuration, Tailscale, and Ansible automation.

## Prerequisites
- Physical or virtual hardware ready
- Network access to existing cluster nodes
- Proxmox VE ISO (latest stable version)
- Cluster network details (IPs, gateway, DNS)
- Access to vault password for Ansible
- Access to Tailscale admin console

## Planning Phase

### 1. Determine Node Specifications
```
Hostname: pveXXX (e.g., pve009)
Management IP: 10.x.x.XX
Purpose: General compute / GPU workload / Storage / etc.
RAM: XXX GB
CPU: Model and core count
Storage: Disk configuration plan
GPU: If applicable
```

### 2. Network Planning
```bash
# Determine next available IP in cluster range
# Check existing nodes
ansible all -i inventory/homelab.yml -m shell -a "hostname -I | awk '{print \$1}'"

# Or check manually
for i in {40..60}; do ping -c 1 -W 1 10.x.x.$i &>/dev/null && echo "10.x.x.$i - UP" || echo "10.x.x.$i - available"; done
```

### 3. Check Cluster Health Before Adding
```bash
# On existing cluster node
pvecm status
ceph -s  # If using Ceph

# Ensure cluster is healthy before proceeding
```

## Phase 1: Hardware Preparation

### A. Physical Hardware Setup
- [ ] Install hardware in rack/location
- [ ] Connect power (note: consider UPS connectivity)
- [ ] Connect network cables
- [ ] Verify BIOS settings:
  - Virtualization enabled (VT-x/AMD-V)
  - IOMMU enabled (if doing GPU passthrough)
  - Boot order (network/USB/disk as needed)
  - Power settings (restore on AC power loss)

### B. Create Installation Media
```bash
# Download latest Proxmox VE ISO
# https://www.proxmox.com/en/downloads

# Verify checksum
sha256sum proxmox-ve_*.iso

# Create bootable USB (macOS)
sudo dd if=proxmox-ve_*.iso of=/dev/diskX bs=1m status=progress

# Or use balenaEtcher, Rufus, etc.
```

## Phase 2: Proxmox Installation

### A. Boot from Installation Media
1. Boot from USB/DVD
2. Select "Install Proxmox VE"
3. Accept EULA

### B. Target Disk Selection
- Select installation disk (usually smallest SSD)
- **Important:** Note which disks you're saving for Ceph/storage
- Consider ZFS for root disk if desired

### C. Location and Time Zone
```
Country: United States (or appropriate)
Time zone: America/Los_Angeles (or appropriate)
Keyboard Layout: en-us
```

### D. Password and Email
```
Root password: <use strong password, store in vault>
Email: your-email@example.com (or appropriate)
```

### E. Network Configuration
```
Management Interface: Choose primary NIC (usually eno1, ens18, etc.)
Hostname (FQDN): pveXXX.localdomain (e.g., pve009.localdomain)
IP Address: 10.150.60.XX/24
Gateway: 10.150.60.1
DNS Server: 10.150.60.1 (or appropriate)
```

**Important:** Double-check IP is not in use!

### F. BIOS Settings (Before Install)
- [ ] **SVM Mode** (AMD-V) → Enabled — required for VMs
- [ ] **IOMMU** → Enabled (not Auto) — required for PCIe passthrough
- [ ] **Secure Boot** → Disabled — Proxmox doesn't support it
- [ ] **CSM** → Disabled — UEFI only
- [ ] **Above 4G Decoding** → Enabled — needed for GPU passthrough
- [ ] **AER Cap** → Enabled, then **ACS Enable** → Enabled — for proper IOMMU groups

### F. Complete Installation
- Review summary
- Click "Install"
- Wait for installation to complete (~10 minutes)
- Remove installation media
- Reboot

## Phase 3: Post-Installation Setup

### A. Initial Login and Validation
```bash
# SSH to new node
ssh root@10.x.x.XX

# Verify basic connectivity
ping -c 3 8.8.8.8
ping -c 3 google.com

# Check time sync (critical for cluster)
timedatectl status
# Should show: System clock synchronized: yes

# If not synced
systemctl enable --now systemd-timesyncd
timedatectl set-ntp true
```

### B. Fix Repositories and Subscription Nag (before updates)

**Run from the Proxmox host shell (not SSH)** — the script uses interactive prompts that work best from the web UI console.

```bash
# Run community post-install script — fixes enterprise repos, adds no-subscription repos,
# sets up Ceph repos, and removes subscription nag popup
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/tools/pve/post-pve-install.sh)"
```
**Note:** Ansible (`roles/proxmox/tasks/repositories.yml`) also handles this, but repos must be correct before `apt update` and `pveceph install` will work.

### C. Update System
```bash
apt update && apt full-upgrade -y

# May require reboot
reboot
```

### D. Verify Web Interface Access
```
https://10.x.x.XX:8006

Login: root
Password: <root password>
```

## Phase 3.5: VLAN Network Configuration

### Current VLAN Layout
| VLAN | Purpose | Subnet | Host IPs |
|------|---------|--------|----------|
| 60 | Management + cluster (untagged/native) | 10.150.60.0/24 | .21, .22, ... |
| 65 | Storage / Ceph | 10.150.65.0/24 | .21, .22, ... (no gateway) |
| 70 | Guest / VM traffic | 10.150.70.0/24 | no host IP needed |

### Network Interfaces Config
```
auto lo
iface lo inet loopback

iface nic0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 10.150.60.XX/24
    gateway 10.150.60.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 65 70

auto vmbr0.65
iface vmbr0.65 inet static
    address 10.150.65.XX/24

source /etc/network/interfaces.d/*
```

### Verify VLAN Configuration
```bash
# Apply config
ifreload -a

# Verify VLAN interface
ip addr show vmbr0.65

# Verify bridge is passing VLANs on physical port
bridge vlan show dev nic0
# Must show VLANs 65 and 70, not just VLAN 1

# Test cross-node connectivity on storage VLAN
ping -c 3 10.150.65.XX  # other node's storage IP
```

### Switch Requirements (USW Flex / UniFi)
- Port profile: trunk with native VLAN 60
- Tagged VLANs: 65, 70 (or "allow all")
- VLANs 65 and 70 must exist as networks in UniFi controller

## Phase 4: Join Proxmox Cluster

**Critical:** Joining a cluster is irreversible without reinstalling. Make sure you're ready!

### A. Pre-Join Checks

On **new node**:
```bash
# Ensure no VMs or containers exist
qm list    # Should be empty
pct list   # Should be empty

# Verify time sync with cluster
ssh root@pve001 "date +%s" && date +%s
# Times should be within 1-2 seconds

# Verify cluster communication
ping -c 3 pve001
ssh root@pve001 "pvecm status"
```

### B. Get Cluster Join Information

On **existing cluster node**:
```bash
pvecm status
# Note the cluster name

# Get join information
pvecm add --help
```

### C. Join Cluster

On **new node**:
```bash
# Join cluster (use IP of existing node)
pvecm add 10.x.x.44

# You'll be prompted for:
# - Root password of existing node
# - Confirmation

# This will:
# - Configure corosync
# - Restart networking
# - Join cluster
# - Regenerate SSH host keys
```

**Note:** SSH connection will drop during join. Wait ~30 seconds, then reconnect.

### D. Verify Cluster Membership

On **any cluster node**:
```bash
pvecm status
# Should show new node in member list

pvecm nodes
# Should list all nodes including new one

# Check quorum
pvecm expected 1
# Should show expected votes and quorum info
```

On **new node**:
```bash
# Verify you can see cluster storage
pvesm status

# Verify you can see other nodes
pvesh get /nodes
```

## Phase 5: Storage Configuration

### A. Local Storage (Skip if Already Configured)
```bash
# Check existing storage
pvesm status

# Local storage should already exist from installation
```

### B. Ceph OSD Setup (If Using Ceph)

**Pre-requisites:**
- At least 3 nodes in cluster for redundancy
- Dedicated disks for Ceph (separate from OS disk)
- Network connectivity to other Ceph nodes

On **new node**:
```bash
# Install Ceph packages (if not already)
pveceph install

# Create Ceph monitor (if cluster needs more)
pveceph mon create

# Create Ceph manager
pveceph mgr create

# List available disks
lsblk
pveceph osd list

# Create OSDs for each data disk (replace /dev/sdX)
pveceph osd create /dev/sdb
pveceph osd create /dev/sdc
pveceph osd create /dev/sdd
```

### C. Verify Ceph Health
```bash
ceph -s
# Should show: HEALTH_OK (after rebalancing completes)

ceph osd tree
# Should show new OSDs in topology

ceph osd df
# Should show OSDs with appropriate size
```

**Note:** Ceph will rebalance data. This can take hours or days depending on cluster size.

## Phase 6: Tailscale Setup

### A. Manual Method (For Testing)
```bash
# On new node
curl -fsSL https://tailscale.com/install.sh | sh

# Authenticate (use auth key from Tailscale admin)
tailscale up --authkey=tskey-auth-XXXXX --hostname=pveXXX --advertise-tags=tag:proxmox --ssh

# Verify
tailscale status
```

### B. Remove Old Tailscale Entry (If Hostname Existed)
1. Go to https://login.tailscale.com/admin/machines
2. Search for `pveXXX`
3. Delete any old entries with same hostname
4. Re-run `tailscale up` command above

### C. Verify Tailscale Connectivity
```bash
# From your local machine
ping pveXXX.your-tailnet.ts.net

# SSH via Tailscale
ssh root@pveXXX.your-tailnet.ts.net

# Test web UI
# Open: https://pveXXX.your-tailnet.ts.net:8006
```

## Phase 7: Ansible Configuration

### A. Add to Inventory
```bash
# Edit inventory file
vi ansible/inventory/homelab.yml

# Add new node under proxmox > nut_netclients > hosts
# Example:
#     pve009:
#       ansible_host: 10.x.x.49
```

### B. Test Ansible Connectivity
```bash
# From your local machine in ansible directory
cd ~/8do/lab/ansible

# Ping test
ansible pve009 -i inventory/homelab.yml -m ping

# Should return: pong
```

### C. Run Ansible Playbook (Check Mode First)
```bash
# Dry run to see what will change
ansible-playbook -i inventory/homelab.yml site.yml --limit pve009 --ask-vault-pass --check --diff

# Review output carefully
```

### D. Apply Configuration
```bash
# Apply for real
ansible-playbook -i inventory/homelab.yml site.yml --limit pve009 --ask-vault-pass

# This will:
# - Configure repositories
# - Install packages
# - Configure Tailscale (update tags, setup SSH)
# - Request Tailscale TLS certificates for web UI
# - Configure NUT UPS client
```

### E. Verify Ansible Run
```bash
# Check Tailscale certificate
ssh root@pve009 "ls -la /etc/pve/local/pveproxy-ssl.*"

# Verify NUT client
ssh root@pve009 "systemctl status nut-monitor"
ssh root@pve009 "upsc myups@10.x.x.44"

# Verify web UI with Tailscale cert
# Open: https://pve009.your-tailnet.ts.net:8006
# Should show valid cert (no browser warning)
```

## Phase 8: Monitoring and Services

### A. Add to Netdata (If Using)
```bash
# Run Netdata playbook
ansible-playbook -i inventory/homelab.yml netdata_install.yml --limit pve009 --ask-vault-pass

# Verify in Netdata Cloud
# https://app.netdata.cloud/
```

### B. Verify UPS Monitoring
```bash
# On new node
upsc myups@10.x.x.44

# Should show UPS status

# Check logs
journalctl -u nut-monitor -f
```

### C. Update Documentation
- [ ] Update capacity tracking spreadsheet
- [ ] Update architecture diagrams
- [ ] Document any special configuration for this node
- [ ] Update monitoring dashboards

## Phase 9: Final Verification

### Cluster Health Checklist
```bash
# Proxmox cluster
pvecm status              # Quorum, all nodes online
pvecm nodes               # All nodes listed

# Corosync
corosync-quorumtool -s    # Should show expected votes

# Ceph (if applicable)
ceph -s                   # HEALTH_OK (after rebalancing)
ceph osd tree             # New OSDs visible and up

# Tailscale
tailscale status          # Connected, new node visible

# Services
systemctl status pveproxy
systemctl status pvedaemon
systemctl status pvestatd
systemctl status nut-monitor  # If UPS client
```

### Network Connectivity Tests
```bash
# From new node to cluster
ping -c 3 pve001
ping -c 3 10.x.x.44

# From local machine to new node
ping -c 3 10.x.x.XX
ping -c 3 pveXXX.your-tailnet.ts.net

# Test web UI
curl -k https://10.x.x.XX:8006
curl -k https://pveXXX.your-tailnet.ts.net:8006
```

### Test VM/Container Creation
```bash
# Download a template (if not already available)
pveam update
pveam available
pveam download local debian-12-standard_12.2-1_amd64.tar.zst

# Create test container
pct create 999 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname test \
  --memory 512 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --rootfs local-lvm:8

# Start it
pct start 999

# Verify
pct status 999
pct exec 999 -- ping -c 3 google.com

# Clean up
pct stop 999
pct destroy 999
```

## Phase 10: Optional GPU Configuration

### A. Verify GPU Visibility (If Applicable)
```bash
# Check PCI devices
lspci | grep -i vga
lspci | grep -i nvidia
lspci | grep -i amd

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l

# Load kernel modules
# For AMD
echo "options amdgpu si_support=1 cik_support=1" > /etc/modprobe.d/amdgpu.conf
update-initramfs -u

# For NVIDIA
# See specific GPU passthrough documentation
```

### B. Test GPU Passthrough (If Needed)
- Create test LXC with GPU device
- Verify device visibility inside container
- Test GPU workload (e.g., vainfo for VAAPI)

See: `jellyfin-gpu-passthrough-lxc.md` for detailed LXC GPU passthrough steps

## Rollback Plan

If something goes wrong during cluster join:

### Before Cluster Join
- Just reinstall Proxmox, start over

### After Cluster Join
**Cluster join is irreversible!** To remove:
- Follow the decommission runbook: `proxmox-node-decommission-runbook.md`
- Then reinstall and start over

## Common Issues

### Issue: Cluster join fails with "no quorum"
**Solution:**
```bash
# On existing node, check quorum
pvecm expected 1

# May need to temporarily adjust expected votes
pvecm expected <current_nodes_count>
```

### Issue: Time sync issues during join
**Solution:**
```bash
# Ensure time is synchronized
systemctl restart systemd-timesyncd
timedatectl set-ntp true

# Verify times match across cluster
date && ssh pve001 date
```

### Issue: Corosync communication errors
**Solution:**
```bash
# Check firewall (should allow corosync ports)
# TCP/UDP: 5405-5412, 3121 (pmxcfs)

# Verify multicast is working
corosync-cfgtool -s
```

### Issue: Tailscale hostname conflict (pveXXX-1)
**Prevention:** Always delete old Tailscale entry before provisioning
**Solution:**
1. Delete both entries in Tailscale admin
2. Re-run `tailscale up` command with correct hostname

### Issue: Ceph won't create OSDs
**Common causes:**
```bash
# Disk has existing partitions
wipefs -a /dev/sdX
sgdisk --zap-all /dev/sdX

# Disk is mounted
umount /dev/sdX*

# Disk has LVM signatures
pvremove /dev/sdX
```

### Issue: Ansible can't connect after cluster join
**Cause:** SSH host keys changed during join
**Solution:**
```bash
# Remove old host key
ssh-keygen -R 10.x.x.XX
ssh-keygen -R pveXXX
ssh-keygen -R pveXXX.your-tailnet.ts.net

# Reconnect to accept new key
ssh root@10.x.x.XX
```

### Issue: NVIDIA GPU causes blank screen during install
**Solution:** At boot menu, select Terminal UI, press `e`, add `nomodeset` to the `linux` line, Ctrl+X to boot.
If install still freezes: add `initcall_blacklist=nvidiafb_init` as well.

After install, make permanent in `/etc/default/grub`:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt nomodeset"
```
Then `update-grub` and blacklist nouveau:
```bash
cat > /etc/modprobe.d/blacklist-nvidia.conf << 'EOF'
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
EOF
update-initramfs -u
```

### Issue: VLAN traffic not passing on bridge-vlan-aware bridge
**Symptom:** VLAN interface (e.g. vmbr0.65) transmits frames but receives 0. Pings between nodes on VLAN fail.
**Cause:** `bridge-vlan-aware yes` is set but `bridge-vids` is missing. The bridge only passes VLAN 1 (default) on the physical port.
**Verify:**
```bash
bridge vlan show dev nic0
# If only VLAN 1 is listed, that's the problem
```
**Solution:** Add `bridge-vids` to vmbr0 in `/etc/network/interfaces`:
```
auto vmbr0
iface vmbr0 inet static
    address 10.150.60.XX/24
    gateway 10.150.60.1
    bridge-ports nic0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 65 70
```
Then `ifreload -a` and verify with `bridge vlan show dev nic0`.

### Issue: Ceph `pveceph mon create` fails with "Could not connect to ceph cluster"
**Cause:** On a fresh cluster, `pveceph mon create` tries to connect to monitors that don't exist yet. The auto-bootstrap can fail if directories or keyrings are missing.
**Solution — manual bootstrap:**
```bash
# 1. Ensure directories exist
mkdir -p /var/lib/ceph/mon /var/lib/ceph/mgr
chown -R ceph:ceph /var/lib/ceph

# 2. Create monmap
monmaptool --create --add $(hostname) <storage-ip> \
  --fsid $(grep fsid /etc/pve/ceph.conf | awk '{print $3}') /tmp/monmap

# 3. Bootstrap monitor as root, then fix ownership
ceph-mon --mkfs -i $(hostname) --monmap /tmp/monmap \
  --keyring /etc/pve/priv/ceph.mon.keyring
chown -R ceph:ceph /var/lib/ceph/mon/ceph-$(hostname)

# 4. Start and verify
systemctl start ceph-mon@$(hostname)
ceph -s
```

### Issue: `/etc/pve/priv/ceph.*` keyrings deleted across cluster
**Cause:** `/etc/pve/priv/` is shared via pmxcfs. Running `rm -f /etc/pve/priv/ceph.*` on ANY node deletes keyrings for ALL nodes.
**Recovery:** Extract from running monitor:
```bash
ceph --keyring /var/lib/ceph/mon/ceph-$(hostname)/keyring \
  --name mon. auth get client.admin -o /etc/pve/priv/ceph.client.admin.keyring
cp /var/lib/ceph/mon/ceph-$(hostname)/keyring /etc/pve/priv/ceph.mon.keyring
```

## Post-Onboarding Tasks

### Immediate (Same Day)
- [ ] Monitor cluster health for 1-2 hours
- [ ] Verify Ceph rebalancing progressing (if applicable)
- [ ] Test VM migration to/from new node
- [ ] Verify backup jobs work with new node
- [ ] Update capacity planning documents

### Short Term (Within Week)
- [ ] Migrate some production workloads to test
- [ ] Monitor performance and stability
- [ ] Document any special quirks or configurations
- [ ] Add to monitoring dashboards
- [ ] Review and update this runbook based on experience

### Long Term
- [ ] Include node in regular maintenance windows
- [ ] Monitor hardware health (SMART, temperatures)
- [ ] Plan capacity utilization

## Related Documentation

- [Proxmox Cluster Manager](https://pve.proxmox.com/wiki/Cluster_Manager)
- [Ceph Installation](https://pve.proxmox.com/wiki/Deploy_Hyper-Converged_Ceph_Cluster)
- [Tailscale Setup](https://tailscale.com/kb/1019/install-linux/)
- [Node Decommission Runbook](./proxmox-node-decommission-runbook.md)
- [GPU Passthrough Guide](./jellyfin-gpu-passthrough-lxc.md)

## Appendix: Quick Reference Commands

```bash
# Cluster status
pvecm status
pvecm nodes
corosync-quorumtool -s

# Ceph status
ceph -s
ceph osd tree
ceph osd df
ceph health detail

# Tailscale
tailscale status
tailscale ping pve001

# Services
systemctl status pveproxy pvedaemon pvestatd
systemctl status nut-monitor

# Ansible
ansible pveXXX -i inventory/homelab.yml -m ping
ansible-playbook -i inventory/homelab.yml site.yml --limit pveXXX --ask-vault-pass --check --diff

# Network tests
ping 10.x.x.1
ping pve001
ping pveXXX.your-tailnet.ts.net
```

## Notes

- **Timing:** Full onboarding takes 2-4 hours depending on:
  - Ceph rebalancing time
  - Number of updates to install
  - GPU/hardware configuration complexity
- **Planning:** Schedule during maintenance window
- **Backups:** Ensure cluster backups are current before adding nodes
- **Testing:** Always test on one node before bulk operations
- **Documentation:** Keep this runbook updated with lessons learned

## Changelog

- 2026-02-28: Updated with pve01/pve02 rebuild lessons
  - Added BIOS settings checklist (IOMMU, SVM, Secure Boot, Above 4G Decoding)
  - Added NVIDIA nomodeset boot fix for installer
  - Added VLAN network config with bridge-vids requirement
  - Added Ceph manual bootstrap procedure
  - Added bridge-vlan-aware troubleshooting
- 2024-12-04: Initial runbook created
  - Added Tailscale hostname conflict prevention
  - Added Ansible automation steps
  - Added GPU configuration appendix
  - Added comprehensive verification checklists
