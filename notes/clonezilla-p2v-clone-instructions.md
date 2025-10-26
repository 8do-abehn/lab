# Clonezilla P2V Clone Instructions

**Purpose**: Clone physical Windows PC to Proxmox VM via Clonezilla over SSH
**Target**: pve007 (10.150.10.47)
**Storage**: CephFS (/mnt/pve/cephfs/clones/)

---

## Step 1: Boot PC from Clonezilla USB

1. **Plug Clonezilla USB** into target PC
2. **Reboot** the PC
3. **Enter boot menu**:
   - Press **F12** (or F11, DEL, or ESC depending on manufacturer)
   - Dell/HP: Usually F12
   - Lenovo: Usually F12
   - ASUS: Usually ESC or F8
4. **Select USB device** from boot menu
5. **Boot Clonezilla Live**

## Step 2: Clonezilla Initial Setup

**Language Selection:**
- Press **Enter** to select English (or arrow keys to choose)

**Keyboard Layout:**
- Press **Enter** to select default (or choose your layout)

**Start Clonezilla:**
- Select **"Start_Clonezilla"**
- Press **Enter**

## Step 3: Clonezilla Mode Selection

**Select Mode:**
- Choose **"device-image"** (work with disks or partitions using images)
- Press **Enter**

**Mount Location:**
- Choose **"ssh_server"** (Use SSH server)
- Press **Enter**

## Step 4: SSH Server Configuration

**SSH Server IP Address:**
- Enter: `10.150.10.47`
- Press **Enter**

**SSH Server Port:**
- Enter: `22`
- Press **Enter**

**SSH Account:**
- Enter: `root`
- Press **Enter**

**SSH Directory:**
- For Seb: `/mnt/pve/cephfs/clones/seb-clone`
- For RTB: `/mnt/pve/cephfs/clones/rtb-clone`
- Press **Enter**

**Password:**
- Enter pve007 root password
- Press **Enter**

**Confirm Connection:**
- Should see "Connection successful" or similar
- Press **Enter** to continue

## Step 5: Clone Operation Selection

**Beginner/Expert Mode:**
- Select **"Beginner mode"** (recommended)
- Press **Enter**

**Operation:**
- Select **"savedisk"** (Save local disk as an image)
- Press **Enter**

**Image Name:**
- For Seb: `seb-disk`
- For RTB: `rtb-disk`
- Press **Enter**

**Source Disk Selection:**
- Use **arrow keys** to select the Windows disk
- Usually **sda** or **nvme0n1** (the largest disk)
- Look for the disk size matching the PC
- Press **Space** to select
- Press **Enter**

## Step 6: Compression and Options

**Compression:**
- Select **"-z1p"** (gzip compression, parallel)
- Press **Enter**

**Image Checking:**
- Select **"-sfsck"** (Skip checking/repairing source file system)
- Press **Enter**

**Image Encryption:**
- Select **"-senc"** (Skip encryption)
- Press **Enter**

**Action when finished:**
- Select **"poweroff"** or **"reboot"** (your choice)
- Press **Enter**

## Step 7: Confirmation

**Review Settings:**
- Check that everything looks correct:
  - Image name: seb-disk or rtb-disk
  - Target: /mnt/pve/cephfs/clones/...
  - Source disk: (your Windows disk)

**Start Cloning:**
- Press **"y"** to confirm
- Press **Enter**

**Final Confirmation:**
- May ask again to confirm
- Press **"y"**
- Press **Enter**

## Step 8: Cloning Process

**Wait for completion:**
- Progress will be shown
- **Estimated time**: 15-60 minutes depending on:
  - Amount of data on disk
  - Network speed
  - Compression

**What you'll see:**
- Progress bar
- Files being copied
- Compression stats
- Time remaining estimate

## Step 9: After Cloning Completes

**Cloning finished:**
- Will show "clone completed successfully" (or similar)
- Press **Enter**

**Shutdown/Reboot:**
- PC will shutdown or reboot based on your selection
- **Remove USB stick** before it reboots

**Keep physical PC OFF** for now (don't start it back up yet)

---

## Quick Reference Cards

### Seb's PC Clone
```
SSH Server: 10.150.10.47
Port: 22
User: root
Directory: /mnt/pve/cephfs/clones/seb-clone
Image name: seb-disk
Operation: savedisk
Compression: -z1p
Source: (Windows disk - sda or nvme0n1)
```

### RTB's PC Clone
```
SSH Server: 10.150.10.47
Port: 22
User: root
Directory: /mnt/pve/cephfs/clones/rtb-clone
Image name: rtb-disk
Operation: savedisk
Compression: -z1p
Source: (Windows disk - sda or nvme0n1)
```

---

## After Clone - Restore to VM

Once clone completes, the image will be on pve007 at:
- `/mnt/pve/cephfs/clones/seb-clone/seb-disk/`
- `/mnt/pve/cephfs/clones/rtb-clone/rtb-disk/`

**Next steps:**
1. Find the cloned disk image files
2. Convert/import to VM disk
3. Update VM boot configuration
4. Test boot

**Clonezilla image structure:**
- Multiple files (sda1, sda2, etc. for each partition)
- Metadata files (parts, disk info)
- May need to use Clonezilla restore or manual dd

---

## Troubleshooting

### Can't connect to SSH server
- Check IP is correct: `10.150.10.47`
- Verify network cable is plugged in
- Try pinging: `ping 10.150.10.47`
- Check firewall on pve007
- Verify SSH is running: `systemctl status sshd`

### Can't see source disk
- Make sure disk is detected in BIOS
- Try rebooting Clonezilla USB
- Check cables are connected
- Try expert mode if beginner mode fails

### Clone fails/errors
- Note the error message
- Take a photo if needed
- Check destination has enough space: `df -h /mnt/pve/cephfs`
- Try again with different compression (-z0 for no compression)
- Check network connectivity

### Network is slow
- Use gigabit ethernet if possible
- Check network switch is gigabit
- Try different compression level
- Monitor with: `ssh root@10.150.10.47 "watch df -h /mnt/pve/cephfs"`

### Disk too large for image
- Check actual used space vs total disk size
- Clonezilla only clones used blocks
- Consider resizing partitions on physical PC first
- Or use partition cloning instead of whole disk

---

## Storage Requirements

**CephFS available**: 2.5TB
**Estimated clone sizes** (compressed):
- Seb's PC: ~50-150GB (depends on data)
- RTB's PC: ~50-150GB (depends on data)
- Total: ~100-300GB (plenty of space!)

---

## Related Documentation

- **P2V Migration Notes**: `p2v-migration-notes.md`
- **Architecture**: `dual-gpu-p2v-architecture.md`
- **Journal**: `journal/2025-10-24-p2v-migration-project-started.md`
