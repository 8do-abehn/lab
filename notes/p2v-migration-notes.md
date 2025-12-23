# P2V Migration Project - Boys' Gaming PCs

**Date Started:** 2025-10-24
**Goal:** Migrate two physical Windows PCs to VMs on Proxmox, eventually running both simultaneously on one host with dual GPU passthrough

---

## The Plan

### Phase 1: P2V Migration on pve007 (IN PROGRESS)
- Use pve007 (work loaner) for testing
- Clone Seb's PC → VM 701 (vm-seb)
- Clone RTB's PC → VM 702 (vm-rtb)
- Test each VM individually (one at a time)
- Verify everything works before moving to production

### Phase 2: Build Permanent Cluster (Completed)
- pve008: Dual RTX 3080 gaming host (in cluster)
- pve007: 2x RX 570 support host (in cluster, was originally planned as pve009)
- pve009: RTX 3080 Ti (pending - original work loaner, keeping it)

### Phase 3: Production Setup
- Migrate both VMs from pve007 → pve008
- Configure VM 701 with GPU #1
- Configure VM 702 with GPU #2
- Set up USB passthrough for keyboards/mice
- Return pve007 to work

### Phase 4: Hardware Setup
- Each boy gets:
  - Monitor connected via HDMI to their GPU
  - Dedicated keyboard/mouse (USB passthrough)
  - Audio through HDMI to monitor
  - Can use simultaneously!

---

## Hardware Inventory

### Current Hosts
- **pve007** (in cluster)
  - 2x AMD RX 570
  - Support host for other VMs/workloads

- **pve008** (in cluster)
  - 2x RTX 3080
  - Dual-GPU gaming host for both boys

- **pve009** (pending addition)
  - RTX 3080 Ti, 64GB RAM
  - Original work loaner, now keeping it
  - Additional compute capacity

### Physical PCs (to be migrated)
- **Seb's PC**
  - UEFI boot ✓
  - VirtIO drivers installed ✓
  - Ready to clone

- **RTB's PC**
  - UEFI boot ✓
  - VirtIO drivers installed ✓
  - Ready to clone

---

## Completed Tasks ✓

1. ✓ Downloaded VirtIO drivers ISO (from pve007)
2. ✓ Created USB stick with VirtIO installer
3. ✓ Installed VirtIO drivers on Seb's PC
4. ✓ Installed VirtIO drivers on RTB's PC
5. ✓ Verified both PCs are UEFI
6. ✓ Created VM 701 (vm-seb) on pve007

---

## VM Configurations

### VM 701 (vm-seb)
```
VMID: 701
Name: vm-seb
Memory: 12GB (12288 MB)
CPU: 6 cores, 1 socket, host type
Boot: UEFI (OVMF)
TPM: 2.0
Machine: q35

Disks:
- scsi0: 250GB (will be C: drive) - VirtIO SCSI
- scsi1: 500GB (will be D: drive) - VirtIO SCSI, SSD flag
- efidisk0: 4MB EFI partition
- tpmstate0: 4MB TPM state

GPU: RTX 3080 Ti passthrough (0000:3e:00.0, x-vga=1)
Network: VirtIO (bridge vmbr0)
CD-ROM: virtio-win.iso (for driver support)

Status: Created, ready for disk clone
```

### VM 702 (vm-rtb)
```
Status: Not yet created
Will have identical specs to VM 701
```

---

## Next Steps - Clonezilla Process

### 1. Create Clonezilla USB
- Download: https://clonezilla.org/downloads.php (AMD64 stable)
- Write to USB with Rufus or similar tool
- Create bootable USB

### 2. Prepare pve007
```bash
ssh root@pve007
mkdir -p /tmp/seb-clone
# Ensure SSH is running (should be by default)
systemctl status sshd
```

### 3. Clone Seb's PC
1. Boot Seb's PC from Clonezilla USB (F12/F11/DEL for boot menu)
2. Clonezilla wizard:
   - Language/keyboard: defaults OK
   - Start Clonezilla
   - Mode: "device-image"
   - Mount: "ssh_server"
   - SSH details:
     - Host: pve007 (or IP address)
     - Port: 22
     - User: root
     - Directory: /tmp/seb-clone
   - Operation: "savedisk" (save entire disk)
   - Image name: "seb-disk"
   - Select source disk (usually /dev/sda - the Windows disk)
   - Compression: gzip (good balance)
   - Start cloning!

3. Wait for clone to complete

### 4. Restore Clone to VM 701

After Clonezilla finishes, the disk image will be in `/tmp/seb-clone/` on pve007.

**Option A: If Clonezilla created standard disk image:**
```bash
# On pve007
cd /tmp/seb-clone/seb-disk

# Find the disk image file (will be something like sda.img or similar)
# You may need to reassemble parts if it was split

# Import to VM 701's scsi0 (250GB C: drive)
# This overwrites the empty disk we created
qm importdisk 701 <image-file> local-lvm

# Update VM config to use the imported disk
# (The import will tell you the new disk name)
```

**Option B: Manual restore using Clonezilla restore mode:**
Boot Clonezilla USB again, choose "restoreparts" or "restoredisk", point to pve007 SSH location

### 5. Fix Boot Order
After import, update VM boot order to boot from scsi0:
```bash
ssh root@pve007
qm set 701 -boot order=scsi0
```

### 6. Test VM 701
```bash
# Start the VM
qm start 701

# Check console (or connect monitor to HDMI)
# VM should boot into Windows
# May need to reactivate Windows license
```

### 7. Repeat for VM 702 (RTB's PC)
1. Create VM 702 with same specs
2. Clone RTB's PC using Clonezilla
3. Import to VM 702
4. Test

---

## Potential Issues & Solutions

### Windows won't boot in VM
- **Cause:** Missing VirtIO drivers (but we pre-installed them!)
- **Solution:** Boot should work since drivers are installed
- **Backup plan:** Change disk to SATA temporarily, boot, verify drivers, switch back to SCSI

### Windows activation
- **Issue:** Hardware change may require reactivation
- **Solution:** Reactivate with existing license key (digital licenses usually work)

### GPU passthrough not working
- **Check:** IOMMU enabled in BIOS
- **Check:** GPU bound to vfio-pci driver, not nvidia/nouveau
- **Check:** VM has `x-vga=1` flag (it does)

### Clone too large for disk
- **Issue:** Physical PC has more data than 250GB
- **Solution:** Resize VM disk before import:
  ```bash
  qm resize 701 scsi0 +50G  # Add more space as needed
  ```

---

## Important File Locations

### On pve007
- VirtIO ISO: `/var/lib/vz/template/iso/virtio-win.iso`
- Clone destination: `/tmp/seb-clone/` and `/tmp/rtb-clone/`
- VM configs: `/etc/pve/qemu-server/701.conf` and `702.conf`

### On local machine
- VirtIO ISO copy: `/tmp/virtio-win.iso`
- This notes file: `/home/adambehn/8do/P2V_MIGRATION_NOTES.md`

---

## Resources

- **Clonezilla download:** https://clonezilla.org/downloads.php
- **VirtIO drivers:** https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/
- **Proxmox GPU passthrough docs:** https://pve.proxmox.com/wiki/PCI_Passthrough

---

## Questions to Answer Later

1. What's pve007's IP address? (needed for Clonezilla SSH)
2. Do boys have Windows license keys handy? (may need for reactivation)
3. Which physical PC is Seb's and which is RTB's?
4. What USB keyboards/mice IDs to assign? (use `lsusb` on pve008)

---

## Timeline

- **2025-10-24:** Project started, VMs created, ready to clone
- **Next session:** Clone Seb's PC with Clonezilla
- **Goal:** Complete both clones and testing before pve007 goes back to work

---

## Notes

- Both PCs have VirtIO drivers pre-installed (smart move!)
- Both are UEFI, matching VM config perfectly
- Each VM gets 250GB C: + 500GB D: (plenty of space)
- GPU passthrough already configured in VM 701
- pve007 has warnings about thin pool overprovisioning (expected, not critical)
