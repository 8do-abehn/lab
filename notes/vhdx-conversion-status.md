# VHDX to qcow2 Conversion Status

**Date**: 2025-11-10 00:15 UTC
**Status**: Conversions running overnight on CephFS
**Related**: VM 701 (vm-seb), VM 702 (vm-rtb) restoration from Disk2vhd backups

---

## Current Conversion Status

All 4 VHDX files are converting to qcow2 on CephFS (`/mnt/pve/cephfs/temp/`) on pve007:

```
File              Current    Target    Progress    ETA
──────────────────────────────────────────────────────────
seb-c.qcow2       29GB       70GB      41%         ~45 min
rtb-c.qcow2       20GB       71GB      28%         ~1 hour
seb-d.qcow2       11GB       334GB     3%          ~13 hours
rtb-d.qcow2       11GB       318GB     3%          ~13 hours

CephFS Usage:     74GB / 2.5TB (3% full) ✓
```

**Conversion Speed**: ~0.5-0.7 GB/min per file (network storage)

**Background Processes**:
- 4x `qemu-img convert` processes running on pve007
- Monitoring script updating every 15 seconds (shell 364fd7)

---

## Ceph Cluster Warning

**IMPORTANT**: Do NOT physically remove the 4TB SATA drive from pve007 yet!

**Current Situation**:
- OSD.5 (4TB drive) marked as "down" in Ceph cluster ✓
- **30% of cluster data still degraded** (backfilling in progress)
- **58 placement groups waiting for backfill**
- Recovery speed: 3.8 MiB/s
- Cluster health: HEALTH_WARN

**Why waiting is important**:
- Ceph is redistributing data from the removed OSD to other nodes
- Physically removing the drive before backfill completes could cause data corruption
- Your conversion files are safe (replicated across remaining OSDs)

---

## Tomorrow Morning - Action Items

### 1. Check Conversion Status

```bash
# Check file sizes
ssh root@pve007 "ls -lh /mnt/pve/cephfs/temp/*.qcow2"

# Expected sizes when complete:
# seb-c.qcow2:  ~70GB
# rtb-c.qcow2:  ~71GB
# seb-d.qcow2:  ~334GB
# rtb-d.qcow2:  ~318GB
```

### 2. Check Ceph Health

```bash
# Check overall cluster status
ssh root@pve007 "ceph status"

# Check placement group status
ssh root@pve007 "ceph pg stat"
```

**Safe to remove drive when you see**:
- Health: HEALTH_OK (not HEALTH_WARN)
- PGs: "97 pgs: 97 active+clean" (no degraded/undersized)

### 3. Clean Up Ceph (if healthy)

```bash
# Purge the old OSD from cluster
ssh root@pve007 "ceph osd purge osd.5 --yes-i-really-mean-it"

# NOW you can physically remove the 4TB drive
```

### 4. Import C: Drives First (when ready)

The C: drives should complete first (~1 hour). You can import and test them while D: drives continue converting:

```bash
# Import Seb's C: drive to VM 701
ssh root@pve007 "qm importdisk 701 /mnt/pve/cephfs/temp/seb-c.qcow2 local-lvm"

# Import RTB's C: drive to VM 702
ssh root@pve007 "qm importdisk 702 /mnt/pve/cephfs/temp/rtb-c.qcow2 local-lvm"

# The import will create "unused" disks, note the disk names from output
# Example output: "Successfully imported disk as 'unused0:local-lvm:vm-701-disk-4'"
```

### 5. Attach C: Drives to VMs

```bash
# Find the imported disk names
ssh root@pve007 "qm config 701 | grep unused"
ssh root@pve007 "qm config 702 | grep unused"

# Attach Seb's C: drive to scsi0 (replace vm-701-disk-X with actual disk name)
ssh root@pve007 "qm set 701 --scsi0 local-lvm:vm-701-disk-X,iothread=1"

# Attach RTB's C: drive to scsi0 (replace vm-702-disk-X with actual disk name)
ssh root@pve007 "qm set 702 --scsi0 local-lvm:vm-702-disk-X,iothread=1"

# Set boot order
ssh root@pve007 "qm set 701 --boot order=scsi0"
ssh root@pve007 "qm set 702 --boot order=scsi0"
```

### 6. Test Boot VM 701 (Seb)

```bash
# Start VM
ssh root@pve007 "qm start 701"

# Watch console (or connect monitor to GPU HDMI)
ssh root@pve007 "qm terminal 701"
```

**What to expect**:
- First boot may be slow (Windows detecting "new hardware")
- VirtIO drivers should work (pre-installed on physical PC)
- Windows may need reactivation due to hardware change
- GPU passthrough should work (RTX 3080 Ti at 0000:3e:00.0)

### 7. Import D: Drives (when conversions complete)

After D: drives finish (~13 hours from 00:15 = ~13:00 UTC):

```bash
# Import D: drives
ssh root@pve007 "qm importdisk 701 /mnt/pve/cephfs/temp/seb-d.qcow2 local-lvm"
ssh root@pve007 "qm importdisk 702 /mnt/pve/cephfs/temp/rtb-d.qcow2 local-lvm"

# Attach to scsi1 (data drive)
ssh root@pve007 "qm set 701 --scsi1 local-lvm:vm-701-disk-Y,iothread=1,ssd=1"
ssh root@pve007 "qm set 702 --scsi1 local-lvm:vm-702-disk-Y,iothread=1,ssd=1"
```

### 8. Clean Up Temporary Files

After successful import and VM testing:

```bash
# Remove temporary qcow2 files from CephFS
ssh root@pve007 "rm /mnt/pve/cephfs/temp/*.qcow2"

# This will free up ~74GB on CephFS
```

---

## VM Configurations

### VM 701 (vm-seb)
```
VMID: 701
Name: vm-seb
Memory: 12GB (12288 MB)
CPU: 6 cores (host type)
Boot: UEFI (OVMF)
TPM: 2.0
Machine: q35

Disks (after import):
- scsi0: C: drive (250GB) ← seb-c.qcow2
- scsi1: D: drive (500GB) ← seb-d.qcow2
- efidisk0: 4MB EFI partition
- tpmstate0: 4MB TPM state

GPU: RTX 3080 Ti passthrough (0000:3e:00.0, x-vga=1)
Network: VirtIO (vmbr0)
Host: pve007 (temporary, will move to pve008)
```

### VM 702 (vm-rtb)
```
VMID: 702
Name: vm-rtb
Memory: 12GB
CPU: 6 cores (host type)
Boot: UEFI (OVMF)
TPM: 2.0
Machine: q35

Disks (after import):
- scsi0: C: drive (250GB) ← rtb-c.qcow2
- scsi1: D: drive (500GB) ← rtb-d.qcow2
- efidisk0: 4MB EFI partition
- tpmstate0: 4MB TPM state

GPU: Will use RTX 3080 Ti on pve007 for testing
Network: VirtIO (vmbr0)
Host: pve007 (temporary, will move to pve008)
```

---

## Background Processes Running

**Active qemu-img conversions** (4 processes):
- Shell 30afb7: PUGET_SEB_C.VHDX → seb-c.qcow2
- Shell 732dc8: PUGET_RTB_C.VHDX → rtb-c.qcow2
- Shell 70dcd1: PUGET_SEB_D.VHDX → seb-d.qcow2
- Shell fd08c6: PUGET-RTB-D.VHDX → rtb-d.qcow2

**Monitoring script**:
- Shell 364fd7: Live progress monitor (updates every 15 seconds)
- Kill with: `kill <pid>` or `Ctrl+C` in that terminal

**Other background tasks**:
- Jellyfin LXC 3001 migration to local-lvm (should be complete)

---

## Source Files

**VHDX Location**: `/var/lib/lxc/800/rootfs/root/test/` (LXC 800 on pve007)

```
PUGET_SEB_C.VHDX   70GB   (virtual: 1.82 TiB)
PUGET_SEB_D.VHDX   334GB  (virtual: 3.64 TiB)
PUGET_RTB_C.VHDX   71GB   (virtual: 1.82 TiB)
PUGET-RTB-D.VHDX   318GB  (virtual: 3.64 TiB)
```

**Issue**: Disk2vhd creates VHDX files with full physical disk virtual size (entire 2TB and 4TB disks), even though actual data is much smaller. This caused multiple failed conversion attempts to local storage before switching to CephFS.

---

## Conversion History / Lessons Learned

### Failed Attempts

1. **Local `/var/lib/vz/temp`**: Root filesystem only 94GB, filled to 100%
2. **LXC 800 storage**: Only 145GB free, would have exceeded space
3. **Direct LVM conversion**: qemu-img tried to resize LVM volume to match VHDX virtual size (1.82TB)

### Successful Approach

- **CephFS network storage**: 2.5TB available, handles sparse data correctly
- **qcow2 format**: Only writes actual used blocks, not full virtual size
- **Parallel conversions**: All 4 running simultaneously (~2.5 GB/min total throughput)

---

## Storage Topology (pve007)

```
Root filesystem:        94GB total, 61GB free (on NVMe)
local-lvm (NVMe):       1.67TB thin pool, 674GB free ✓
CephFS (network):       2.5TB available, 74GB used (3%) ✓
OSD.5 (SATA 4TB):       Being removed, in backfill state
```

**Why CephFS?**: Only location with enough space to safely handle VHDX virtual sizes during conversion.

**Why not local-lvm?**: Conversion writes to `/var/lib/vz/temp` first (root filesystem), which has limited space. After conversion, files will be imported to local-lvm.

---

## Post-Import Plan

### Phase 1: Testing on pve007 (Current)
- Boot and test VM 701 with C: drive only
- Verify Windows boots, GPU works, drivers load
- Add D: drive after conversion completes
- Test VM 702 similarly

### Phase 2: Migration to pve008 (Future)
- Move both VMs from pve007 → pve008
- pve008 will have dual RTX 3080s (one for each boy)
- Configure dedicated GPU passthrough for each VM
- Set up USB passthrough for keyboards/mice
- Each boy gets monitor + HDMI to their GPU

### Phase 3: Production
- Return pve007 to work (temporary loaner)
- Boys can game simultaneously on separate VMs
- Monitors connected directly to GPUs via HDMI

---

## Troubleshooting

### If Conversions Fail

Check for:
```bash
# Check conversion processes still running
ssh root@pve007 "ps aux | grep qemu-img"

# Check CephFS still mounted
ssh root@pve007 "df -h /mnt/pve/cephfs"

# Check Ceph health
ssh root@pve007 "ceph status"
```

### If VM Won't Boot After Import

```bash
# Try BIOS instead of UEFI (if original was BIOS)
ssh root@pve007 "qm set 701 --delete efidisk0"
ssh root@pve007 "qm set 701 --bios seabios"

# Or change storage to SATA temporarily
ssh root@pve007 "qm set 701 --delete scsi0"
ssh root@pve007 "qm set 701 --sata0 local-lvm:vm-701-disk-X"
```

### If Windows Needs Activation

1. Open Settings → Activation
2. Use existing product key
3. Or use "Troubleshoot" → "I changed hardware on this device"
4. Digital licenses usually reactivate automatically

---

## Related Documentation

- **P2V Migration Notes**: `p2v-migration-notes.md`
- **Restore Guide**: `restore-disk2vhd-to-proxmox.md`
- **Puget Gaming POC**: `puget-gaming-poc-plan.md`

---

## Timeline

- **2025-11-09 23:48 UTC**: Started all 4 conversions in parallel
- **2025-11-10 00:15 UTC**: Conversions ongoing, left running overnight
- **2025-11-10 ~01:00 UTC**: C: drives should complete
- **2025-11-10 ~13:00 UTC**: D: drives should complete
- **TBD**: Import, test, migrate to pve008

---

**Status**: Conversions running successfully, Ceph backfilling, check back tomorrow morning

**Last Updated**: 2025-11-10 00:15 UTC
