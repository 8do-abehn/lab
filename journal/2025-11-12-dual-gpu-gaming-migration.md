# Journal Entry - 2025-11-12

## Dual-GPU Gaming VM Migration to pve008

Successfully migrated boys' gaming VMs from pve007 to new pve008 host with dual RTX 3080 GPU passthrough setup. Both VMs now running simultaneously with dedicated GPUs.

## Major Accomplishments

### 1. New Proxmox Installations
- **pve006**: Reinstalled Proxmox (was Linux desktop), joined to cluster
- **pve008**: Fresh Proxmox install on Puget system (AMD Ryzen 9 5900X)
- Fixed IP typo on pve006 during setup

### 2. Ansible Infrastructure Updates
- **Repository fix**: Added `update_cache: no` to all apt_repository tasks
- **Issue**: Fresh Proxmox installs fail due to enterprise repo 401 errors
- **Solution**: Disable enterprise repos first, update cache only after all repos fixed
- **Hostname management**: Added `--hostname={{ inventory_hostname }}` to Tailscale auth
- **Result**: Idempotent Ansible playbooks now work on fresh installs

### 3. SSH and Dotfiles Configuration
- Migrated SSH keys to new laptop
- Updated dotfiles SSH config with homelab settings
- Created idempotent install scripts for SSH config management
- All configs now symlinked from `~/8do/dotfiles`

### 4. Cluster Expansion
- Added pve006 to cluster: `pvecm add pve001.taile975f.ts.net`
- Added pve008 to cluster: `pvecm add pve001.taile975f.ts.net`
- **Key learning**: Use Tailscale FQDN to avoid cert verification issues
- Cluster now has 8 active nodes (pve001-008)

### 5. IOMMU and GPU Passthrough Setup

**pve008 Hardware:**
- CPU: AMD Ryzen 9 5900X 12-Core (no iGPU)
- GPUs: 2x NVIDIA RTX 3080
- Storage: 4TB SDA (sda4tb) + 2TB NVMe (nvme2tb)

**IOMMU Configuration:**
```bash
# /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt"
```

**IOMMU Groups:**
- Group 26: RTX 3080 #1 (0a:00.0 + 0a:00.1 audio)
- Group 27: RTX 3080 #2 (0b:00.0 + 0b:00.1 audio)
- Perfect isolation - each GPU in separate group

**Host Configuration:**
- pve008 runs headless (SSH-only management)
- Both GPUs dedicated to VMs
- No iGPU available (5900X doesn't have one)

### 6. VM Migration Process

**Challenge**: VMs had GPU and USB passthrough tied to pve007 hardware

**Migration Steps:**
1. Removed passthrough devices from VM configs
2. Changed VGA to `std` (from `none`)
3. Offline migration with target storage
4. Recreated passthrough with pve008 device IDs

**VM 701 (vm-seb):**
```bash
qm set 701 --delete hostpci0 --delete hostpci1
qm set 701 --delete usb0 --delete usb1 --delete usb2
qm set 701 --vga std
qm migrate 701 pve008 --targetstorage sda4tb
```

**VM 702 (vm-rtb):**
- Same process as VM 701
- **Issue**: TPM state file conflict after migration
- **Solution**: Removed and recreated TPM state
```bash
lvremove -y /dev/sda4tb/vm-702-disk-2
qm set 702 --delete tpmstate0
qm set 702 -tpmstate0 sda4tb:4,version=v2.0
```

**Migration Time:**
- Network speed: 116 MB/s
- Per VM: ~1 hour 50 minutes (750GB each)
- Total: ~4 hours for both VMs

**Storage Layout:**
- Source: pve007 local-lvm (LVM-thin)
- Target: pve008 sda4tb (4TB LVM)
- VMs now have plenty of room to grow

### 7. GPU Passthrough Configuration

**VM 701 (Seb):**
```
hostpci0: 0a:00.0,pcie=1,x-vga=1  # GPU
hostpci1: 0a:00.1,pcie=1          # HDMI Audio
vga: none
cores: 8
memory: 32768
```

**VM 702 (RTB):**
```
hostpci0: 0b:00.0,pcie=1,x-vga=1  # GPU
hostpci1: 0b:00.1,pcie=1          # HDMI Audio
vga: none
cores: 8
memory: 32768
```

Both VMs now have:
- Dedicated RTX 3080
- HDMI audio through GPU
- 8 CPU cores (from 12-core 5900X)
- 32GB RAM each

### 8. Guest Tools and Controllers

**QEMU Guest Agent:**
- Installed `virtio-win-guest-tools.exe` on both VMs
- Enables graceful shutdown, IP address visibility, better snapshots
- Verified: `qm agent 701 ping` and `qm agent 702 ping`

**Game Controllers:**
- USB passthrough configured for controllers
- Both boys can game simultaneously

**BitLocker Recovery:**
- VMs prompted for BitLocker key after TPM change
- Keys retrieved from Microsoft account
- Both VMs successfully unlocked

## Architecture

### Before (pve007):
- Single host with 2x RTX 3080
- Both VMs with GPU passthrough
- Work loaner system (temporary)

### After (pve008):
- Permanent home system (personal Puget workstation)
- AMD Ryzen 9 5900X (12c/24t)
- 2x RTX 3080 in separate IOMMU groups
- 4TB + 2TB storage
- SSH-only management (no display on host)

## Technical Challenges Overcome

### 1. Ansible Repository Management
- Enterprise repos cause fresh install failures
- Solution: Skip cache updates until all repos fixed
- Now works idempotently on fresh Proxmox installs

### 2. Tailscale Hostname Collisions
- Fresh installs created duplicate hostnames (pve006-1, pve006)
- Solution: Explicit `--hostname` flag in Ansible
- Prevents random suffixes on node names

### 3. Cluster Join Certificate Issues
- Direct IP failed: "hostname verification failed"
- Solution: Use Tailscale FQDN (pve001.taile975f.ts.net)
- Certificates match Tailscale domain

### 4. VM Migration with Passthrough Devices
- Can't migrate with local device passthrough
- Solution: Remove devices, migrate, re-add with new IDs
- Learned: Must update device addresses for new host

### 5. TPM State After Migration
- swtpm won't overwrite existing state file
- Solution: Remove LVM volume, recreate TPM state
- BitLocker recovery keys from Microsoft account

## Lessons Learned

### Infrastructure
- **Tailscale FQDNs**: Use .ts.net domains for cluster operations
- **Ephemeral keys**: Should use ephemeral + reusable auth keys for frequent rebuilds
- **IOMMU planning**: Check CPU for iGPU before planning GPU assignments
- **Storage selection**: LVM on large drives better than thin provisioning for gaming VMs

### Ansible Best Practices
- Always test on fresh installs, not just existing infrastructure
- Skip cache updates during repo changes (`update_cache: no`)
- Explicit hostnames prevent Tailscale collisions
- Idempotent playbooks save hours of manual work

### GPU Passthrough
- Each GPU needs separate IOMMU group (or pass whole group)
- Both GPU + audio must be passed together
- TPM state doesn't migrate cleanly between hosts
- No iGPU = SSH-only host when passing all GPUs

### VM Migration
- Offline migration faster than online for large VMs
- Remove passthrough devices before migration
- TPM/EFI state can cause issues - be ready to recreate
- BitLocker keys in Microsoft account are lifesavers

## Next Steps

**Immediate:**
- Return pve007 to work (no longer needed)
- Test gaming performance on both VMs
- Verify Microsoft Family Safety time limits working

**Soon:**
- Install pve009 when RX 570 power cable arrives
- Consider USB controller passthrough instead of individual devices
- Set up VM backups to Ceph storage
- Document GPU passthrough setup for future rebuilds

**Future Optimizations:**
- CPU pinning for lower latency
- Huge pages for better memory performance
- Consider USB controller passthrough
- Automated VM snapshots before game updates

## Current Homelab Status

**Cluster Nodes:**
- pve001-005: Original cluster (mixed roles)
- pve006: Fresh install, general purpose
- pve007: Will return to work
- pve008: Dual-GPU gaming host (production)
- pve009: Pending RX 570 power cable

**Key VMs:**
- 701 (vm-seb): RTX 3080, 8 cores, 32GB RAM
- 702 (vm-rtb): RTX 3080, 8 cores, 32GB RAM
- k3s cluster: Offline (will restart later)
- Jellyfin (3001): Running on pve005 with RX 570

**Storage:**
- Ceph: 2.5TB (shared storage)
- Local: Various LVM volumes per host
- pve008: 4TB SDA + 2TB NVMe

## Why This is Cool

Instead of two separate physical gaming PCs:
- One powerful host with 2 GPUs
- Each boy has independent VM with dedicated GPU
- Both can game simultaneously
- Easier management, backups, snapshots
- More economical than 2 physical machines
- Easy resource adjustments (RAM, CPU, storage)
- Integrated with homelab infrastructure

The boys don't know they're on VMs - performance is native!

---

**Status**: Both VMs running successfully on pve008 with full GPU passthrough

**Mood**: Accomplished! This was a complex migration with many moving parts.

**Time spent**: ~6 hours (installation, migration, troubleshooting, configuration)

**Key win**: Both boys gaming on dedicated GPUs from single host
