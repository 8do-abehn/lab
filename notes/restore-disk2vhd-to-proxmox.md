# Restoring Disk2vhd Backups to Proxmox VMs

**Date**: 2025-11-05
**Purpose**: Restore Windows PC backups created with Sysinternals Disk2vhd to Proxmox VMs
**Related**: P2V Migration for boys' gaming PCs (VM 701 and VM 702)

---

## Overview

Disk2vhd creates VHD or VHDX files of physical Windows systems. To use these in Proxmox, they need to be converted to qcow2 format and imported as VM disks.

## Prerequisites

- VHD/VHDX backup files from Disk2vhd
- Proxmox host with qemu-img installed (default)
- Sufficient storage space (VHD size + converted qcow2 size)
- Existing VM with correct configuration (UEFI, TPM 2.0, etc.)

**Related VMs**:
- VM 701 (vm-seb) - Seb's gaming PC
- VM 702 (vm-rtb) - RTB's gaming PC

---

## Step 1: Transfer VHD Files to Proxmox

### Option A: Using SCP (from local machine)

```bash
# From local machine where VHD files are stored
scp /path/to/backup.vhd root@pve007:/tmp/
scp /path/to/backup.vhdx root@pve009:/tmp/
```

### Option B: Using rsync (for large files)

```bash
# Better for large files, shows progress, resumable
rsync -avh --progress /path/to/backup.vhd root@pve007:/tmp/
```

### Option C: Mount network share on Proxmox

```bash
# On Proxmox host
mkdir -p /mnt/backups
mount -t cifs //nas-server/backups /mnt/backups -o username=user,password=pass
```

---

## Step 2: Convert VHD/VHDX to qcow2

On the Proxmox host where you want to restore:

```bash
# Navigate to where VHD files are stored
cd /tmp  # or wherever you stored them

# Convert VHD to qcow2
qemu-img convert -f vpc -O qcow2 backup.vhd backup.qcow2

# Or for VHDX format:
qemu-img convert -f vhdx -O qcow2 backup.vhdx backup.qcow2

# Check the converted file
qemu-img info backup.qcow2
```

**Conversion options** (for better performance):

```bash
# With compression (smaller file, slower conversion)
qemu-img convert -f vpc -O qcow2 -c backup.vhd backup.qcow2

# With preallocation (faster performance, no compression)
qemu-img convert -f vpc -O qcow2 -o preallocation=metadata backup.vhd backup.qcow2
```

---

## Step 3: Import qcow2 to VM Disk

### Method A: Using qm importdisk (Recommended)

```bash
# Import to VM's storage
# Syntax: qm importdisk <vmid> <source> <storage>

# Example for VM 701 (Seb)
qm importdisk 701 backup.qcow2 local-lvm

# This will output something like:
# Successfully imported disk as 'unused0:local-lvm:vm-701-disk-1'
```

### Method B: Manual import to specific disk

If you want to replace an existing disk (like scsi0):

```bash
# First, remove or detach the existing disk
qm set 701 --delete scsi0

# Then import the new disk
qm importdisk 701 backup.qcow2 local-lvm

# The output will tell you the new disk name (e.g., unused0)
# Attach it as scsi0:
qm set 701 --scsi0 local-lvm:vm-701-disk-1,iothread=1,ssd=1
```

### Method C: Replace existing disk in-place

```bash
# Get the path to the existing VM disk
pvesm path local-lvm:vm-701-disk-0

# This might show something like:
# /dev/pve/vm-701-disk-0

# Convert and write directly (CAREFUL - overwrites existing disk!)
qemu-img convert -f vpc -O raw backup.vhd /dev/pve/vm-701-disk-0
```

**⚠️ WARNING**: Method C overwrites the existing disk immediately. Make sure you have the right disk path!

---

## Step 4: Configure VM Boot Order

After importing the disk, update the VM to boot from it:

```bash
# Check current config
qm config 701

# Set boot order to boot from scsi0
qm set 701 --boot order=scsi0

# Or if you're using multiple disks, specify order:
qm set 701 --boot order=scsi0;scsi1
```

---

## Step 5: Handle Multiple Disks (C: and D: drives)

If the physical PC had multiple drives (e.g., 250GB C: and 500GB D:):

### If Disk2vhd created separate VHD files:

```bash
# Convert both VHDs
qemu-img convert -f vpc -O qcow2 c-drive.vhd c-drive.qcow2
qemu-img convert -f vpc -O qcow2 d-drive.vhd d-drive.qcow2

# Import both to VM
qm importdisk 701 c-drive.qcow2 local-lvm  # Will become scsi0
qm importdisk 701 d-drive.qcow2 local-lvm  # Will become scsi1

# Attach them
qm set 701 --scsi0 local-lvm:vm-701-disk-0,iothread=1
qm set 701 --scsi1 local-lvm:vm-701-disk-1,iothread=1,ssd=1

# Set boot order
qm set 701 --boot order=scsi0
```

### If Disk2vhd created a single VHD with partitions:

```bash
# Single conversion and import
qemu-img convert -f vpc -O qcow2 full-backup.vhd full-backup.qcow2
qm importdisk 701 full-backup.qcow2 local-lvm
qm set 701 --scsi0 local-lvm:vm-701-disk-0,iothread=1

# Windows will see both C: and D: partitions automatically
```

---

## Step 6: Verify VM Configuration

Before starting the VM, verify the configuration matches what's needed:

```bash
# Check full VM config
qm config 701

# Should show:
# - UEFI boot (bios: ovmf)
# - TPM 2.0 (tpmstate0)
# - Correct disk(s) attached
# - GPU passthrough (hostpci0) if configured
# - VirtIO network
```

**Expected configuration**:
```
bios: ovmf
boot: order=scsi0
cores: 6
memory: 12288
name: vm-seb
net0: virtio=XX:XX:XX:XX:XX:XX,bridge=vmbr0
scsi0: local-lvm:vm-701-disk-0,iothread=1,size=250G
scsi1: local-lvm:vm-701-disk-1,iothread=1,size=500G,ssd=1
scsihw: virtio-scsi-single
tpmstate0: local-lvm:vm-701-disk-2,size=4M,version=v2.0
efidisk0: local-lvm:vm-701-disk-3,size=4M
```

---

## Step 7: Start and Test VM

```bash
# Start the VM
qm start 701

# Watch the boot process
qm terminal 701

# Or check via noVNC in Proxmox web UI
```

### What to expect:

1. **First boot may be slow**: Windows detects "new hardware"
2. **VirtIO drivers**: Should work if pre-installed on physical PC
3. **Windows may need reactivation**: Due to hardware change
4. **GPU passthrough**: Should work if configured (connect monitor to GPU HDMI)

---

## Step 8: Post-Restore Tasks

### Verify VirtIO Drivers

If VM boots but network/storage is slow or missing:

```bash
# Mount VirtIO ISO to VM
qm set 701 --ide2 local:iso/virtio-win.iso,media=cdrom

# Boot VM, install drivers from D: drive
# Then remove ISO:
qm set 701 --delete ide2
```

### Windows Activation

If Windows requires reactivation:

1. Open Settings → Activation
2. Use existing product key
3. Or use "Troubleshoot" → "I changed hardware on this device"
4. Digital licenses usually reactivate automatically

### GPU Passthrough

If GPU isn't working:

```bash
# Verify GPU is configured
qm config 701 | grep hostpci

# Should show something like:
# hostpci0: 0000:3e:00.0,pcie=1,x-vga=1

# If missing, add GPU passthrough:
qm set 701 --hostpci0 0000:3e:00.0,pcie=1,x-vga=1
```

### Performance Check

```bash
# Inside Windows VM, verify:
# - Device Manager shows VirtIO SCSI Controller
# - Network adapter is Red Hat VirtIO Ethernet
# - GPU shows as NVIDIA RTX 3080 (not "Basic Display Adapter")
# - Disk performance is good (CrystalDiskMark or similar)
```

---

## Troubleshooting

### Issue: "qemu-img: Could not open 'backup.vhd': No such file or directory"

**Solution**: Check file path and permissions
```bash
ls -lh /tmp/backup.vhd
chmod 644 /tmp/backup.vhd
```

### Issue: "qemu-img: error while converting vpc: Invalid argument"

**Solution**: VHD file may be corrupted or in wrong format
```bash
# Check VHD file info
qemu-img info backup.vhd

# Try different format
qemu-img convert -f vhdx -O qcow2 backup.vhd backup.qcow2
```

### Issue: VM Won't Boot After Restore

**Possible causes**:
1. Missing VirtIO drivers
2. UEFI/BIOS mismatch
3. Boot order incorrect
4. EFI partition missing

**Solutions**:
```bash
# Try booting from BIOS instead of UEFI (if original was BIOS)
qm set 701 --delete efidisk0
qm set 701 --bios seabios

# Or fix boot order
qm set 701 --boot order=scsi0

# Or temporarily change storage to SATA for driver install
qm set 701 --delete scsi0
qm set 701 --sata0 local-lvm:vm-701-disk-0
# Boot, install VirtIO drivers, switch back to SCSI
```

### Issue: "Thin pool has XXXX free space"

**Solution**: Need more storage space
```bash
# Check available space
pvs
vgs
lvs

# Extend volume group if needed
# Or use different storage location
qm importdisk 701 backup.qcow2 other-storage
```

### Issue: Disk Size Mismatch

If the imported disk is larger or smaller than expected:

```bash
# Resize the disk after import
qm resize 701 scsi0 +50G    # Add 50GB
qm resize 701 scsi0 250G    # Set to exactly 250GB

# Then extend partition in Windows (Disk Management)
```

---

## Complete Example: Restoring Seb's PC (VM 701)

```bash
# 1. Transfer VHD to Proxmox
scp /path/to/seb-backup.vhd root@pve007:/tmp/

# 2. SSH to Proxmox host
ssh root@pve007

# 3. Convert VHD to qcow2
cd /tmp
qemu-img convert -f vpc -O qcow2 seb-backup.vhd seb.qcow2

# 4. Import to VM 701
qm importdisk 701 seb.qcow2 local-lvm

# Output: Successfully imported disk as 'unused0:local-lvm:vm-701-disk-0'

# 5. Attach disk as scsi0
qm set 701 --scsi0 local-lvm:vm-701-disk-0,iothread=1

# 6. Set boot order
qm set 701 --boot order=scsi0

# 7. Verify config
qm config 701

# 8. Start VM
qm start 701

# 9. Connect to console
qm terminal 701
# Or connect monitor to GPU HDMI output

# 10. Clean up
rm /tmp/seb-backup.vhd /tmp/seb.qcow2
```

---

## Alternative: Direct VHD Import (Without Conversion)

Proxmox can sometimes use VHD files directly, though qcow2 is preferred:

```bash
# Import VHD directly
qm importdisk 701 backup.vhd local-lvm

# However, this still converts to raw/qcow2 internally
# Better to explicitly convert for control over options
```

---

## Storage Location Options

Where to import the disk:

### local-lvm (default)
```bash
qm importdisk 701 backup.qcow2 local-lvm
# Fast, uses LVM thin provisioning
```

### local (directory storage)
```bash
qm importdisk 701 backup.qcow2 local
# Stores in /var/lib/vz/images/
```

### CephFS (if using Ceph)
```bash
qm importdisk 701 backup.qcow2 cephfs
# Shared storage, can live migrate VMs
```

---

## Disk2vhd Backup Checklist

If you still need to **create** Disk2vhd backups (for RTB or future use):

1. Download Disk2vhd from Microsoft Sysinternals
2. Run on physical Windows PC (as Administrator)
3. Select drives to backup (C:, D:, etc.)
4. Choose output location (external drive, network share)
5. Select "Use VHDX" format (better for large disks)
6. Uncheck "Use Volume Shadow Copy" if disk is quiet
7. Click "Create"
8. Wait for backup to complete
9. Transfer VHDX to Proxmox for restoration

---

## Related Documentation

- P2V Migration Notes: `p2v-migration-notes.md`
- Dual GPU Architecture: `dual-gpu-p2v-architecture.md`
- Clonezilla Alternative: `clonezilla-p2v-clone-instructions.md`
- Gaming VM Setup: `journal/2025-10-24-gaming-vm-gpu-passthrough-success.md`

---

## Questions to Clarify

Before proceeding with restore:

1. **Where are the VHD/VHDX files located?**
   - Local machine?
   - External drive?
   - Network share?

2. **Which VMs need restoration?**
   - VM 701 (vm-seb) on pve007?
   - VM 702 (vm-rtb)?
   - Both?

3. **Are VMs already created with correct config?**
   - UEFI + TPM 2.0?
   - Correct memory/CPU?
   - GPU passthrough configured?

4. **What disk configuration?**
   - Single drive backup?
   - Multiple drives (C: + D:)?
   - VHD or VHDX format?

5. **Which Proxmox host?**
   - pve007 (temporary)?
   - pve008 (final destination)?

---

## Next Steps

1. Identify location of Disk2vhd backup files
2. Determine which VM(s) to restore
3. Transfer VHD files to appropriate Proxmox host
4. Convert and import using steps above
5. Test VM boot and functionality
6. Configure GPU passthrough if not already done
7. Verify games and data are intact
8. Repeat for second VM if needed

---

**Status**: Guide created, ready to restore once VHD file locations are identified

**Last Updated**: 2025-11-05
