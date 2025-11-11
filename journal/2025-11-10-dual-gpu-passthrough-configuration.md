# Dual GPU Passthrough Configuration for Gaming VMs

**Date**: 2025-11-10
**Host**: pve007
**Mission**: Configure dual NVIDIA GPU passthrough for two gaming VMs (701 and 702) on pve007

---

## The Mission

With two boys needing separate gaming VMs, we needed to configure pve007 with dual GPU passthrough. VM 701 (Seb) would get the RTX 3080 Ti, and VM 702 (RTB) would get the RTX 3080. Each GPU would be exclusively passed through to its respective VM, allowing both boys to game simultaneously.

---

## The Journey

### The "System Won't Boot" Mystery

It started with a panicked message: "the system is not booting, it hangs on linux is there a setting the bios for 2 video cards?"

But something didn't add up. When asked to check BIOS access, the response came back: "I can access the bios." If the BIOS was accessible, the system was clearly POSTing and initializing hardware successfully.

The real clue came next: "it does boot... I just can't see it" followed by "I can ping the host... it just does not display over display port."

**Aha moment**: This wasn't a boot failure. This was a display routing issue.

### Understanding the Display Output Problem

The issue made perfect sense once we understood what was happening:

1. The RTX 3080 Ti at **0000:3e:00.0** was already configured for VM 701
2. It was bound to `vfio-pci` driver for passthrough
3. GPUs bound to vfio-pci don't provide console output - they're reserved for VMs
4. The monitor was connected to the wrong GPU

The RTX 3080 at **0000:3f:00.0** was available and should provide console output, but the monitor wasn't connected to it.

**Solution**: Connect the monitor to the RTX 3080 (3f:00.0) for console access, not the RTX 3080 Ti (3e:00.0).

### Verifying Dual GPU Detection

We verified both GPUs were present and detected:

```bash
lspci | grep -i vga
```

Output showed:
- **3e:00.0** VGA compatible controller: NVIDIA RTX 3080 Ti (10de:2208)
- **3f:00.0** VGA compatible controller: NVIDIA RTX 3080 (10de:2206)

Both GPUs were detected correctly. Now we needed to configure VM 702 to use the RTX 3080.

### Configuring VM 702 for RTX 3080

The task: switch VM 702 from sharing the RTX 3080 Ti to using its own dedicated RTX 3080.

**Step 1: Update VM 702 Configuration**

Changed `/etc/pve/qemu-server/702.conf`:
```diff
- hostpci0: 0000:3e:00.0,pcie=1,x-vga=1
- hostpci1: 0000:3e:00.1,pcie=1
+ hostpci0: 0000:3f:00.0,pcie=1,x-vga=1
+ hostpci1: 0000:3f:00.1,pcie=1
```

This assigned both the RTX 3080 video controller (3f:00.0) and its audio controller (3f:00.1) to VM 702.

**Step 2: Update VFIO Driver Binding**

Modified `/etc/modprobe.d/vfio.conf` to include the RTX 3080 PCI ID:

```bash
options vfio-pci ids=10de:2208,10de:2206,10de:1aef disable_vga=1
```

Where:
- **10de:2208** = RTX 3080 Ti (for VM 701)
- **10de:2206** = RTX 3080 (for VM 702)
- **10de:1aef** = GPU audio controller (shared ID for both)

**Step 3: Regenerate initramfs**

The VFIO configuration is loaded during early boot from initramfs:

```bash
update-initramfs -u -k all
```

This rebuilt the initial ramdisk with the updated VFIO PCI IDs.

### BIOS Configuration for Dual GPU

We reviewed the ASUS BIOS settings required for dual GPU passthrough:

**Critical Settings** (ASUS Board):

1. **Above 4G Decoding: Enabled**
   Location: Advanced → PCI Subsystem Settings → Above 4G Decoding
   Why: Allows PCIe devices to use memory addresses above 4GB

2. **Re-Size BAR Support: Disabled**
   Location: Advanced → PCI Subsystem Settings → Re-Size BAR Support
   Why: Can cause issues with passthrough; disable for stability

3. **Primary Display: PCIe** (or Auto)
   Location: Advanced → System Agent Configuration → Graphics Configuration
   Why: Ensures proper display initialization

4. **Intel VT-d: Enabled** (AMD equivalent)
   Location: Advanced → CPU Configuration → Intel VT-d
   Why: Required for IOMMU and PCI passthrough

5. **CSM: Disabled**
   Location: Boot → CSM (Compatibility Support Module)
   Why: UEFI-only boot required for Windows 11 VMs

### Verifying Existing Configuration

Before rebooting, we verified that GRUB and driver blacklist were already properly configured:

**GRUB Configuration** (`/etc/default/grub`):
```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt video=vesafb:off video=efifb:off initcall_blacklist=sysfb_init"
```

Already perfect - no changes needed.

**Driver Blacklist** (`/etc/modprobe.d/blacklist.conf`):
```bash
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
```

Also already configured correctly.

### The Reboot

With everything updated, it was time to reboot and apply the new VFIO bindings:

```bash
reboot
```

A few moments of waiting... then: "it's back"

Success. pve007 returned from reboot with both GPUs configured for passthrough.

---

## Technical Architecture

### GPU Assignment

| VM | VMID | GPU | PCI Address | Purpose |
|----|------|-----|-------------|---------|
| vm-seb | 701 | RTX 3080 Ti | 0000:3e:00.0 | Seb's gaming VM |
| vm-rtb | 702 | RTX 3080 | 0000:3f:00.0 | RTB's gaming VM |

### VM 701 Configuration (vm-seb)

```
agent: 1
bios: ovmf
boot: order=sata0
cores: 6
cpu: host
efidisk0: local-lvm:vm-701-disk-1,efitype=4m,pre-enrolled-keys=1,size=4M
hostpci0: 0000:3e:00.0,pcie=1,x-vga=1    # RTX 3080 Ti
hostpci1: 0000:3e:00.1,pcie=1             # GPU Audio
machine: pc-q35-9.2+pve1
memory: 12288
name: vm-seb
net0: virtio=BC:24:11:ED:73:A5,bridge=vmbr0
ostype: win11
sata0: local-lvm:vm-701-disk-0,discard=on,size=750G
scsihw: virtio-scsi-single
tpmstate0: local-lvm:vm-701-disk-2,size=4M,version=v2.0
vga: none
```

### VM 702 Configuration (vm-rtb)

```
agent: 1
bios: ovmf
boot: order=sata0
cores: 6
cpu: host
efidisk0: local-lvm:vm-702-disk-1,efitype=4m,pre-enrolled-keys=1,size=4M
hostpci0: 0000:3f:00.0,pcie=1,x-vga=1    # RTX 3080
hostpci1: 0000:3f:00.1,pcie=1             # GPU Audio
machine: pc-q35-9.2+pve1
memory: 12288
name: vm-rtb
net0: virtio=BC:24:11:DC:A7:3C,bridge=vmbr0
ostype: win11
sata0: local-lvm:vm-702-disk-0,discard=on,size=750G
scsihw: virtio-scsi-single
tpmstate0: local-lvm:vm-702-disk-2,size=4M,version=v2.0
vga: none
```

### VFIO Configuration

**File**: `/etc/modprobe.d/vfio.conf`
```bash
options vfio-pci ids=10de:2208,10de:2206,10de:1aef disable_vga=1
```

### PCI Device IDs

- **10de:2208** - NVIDIA GeForce RTX 3080 Ti (video controller)
- **10de:2206** - NVIDIA GeForce RTX 3080 (video controller)
- **10de:1aef** - NVIDIA Audio Device (shared by both GPUs)

### IOMMU Groups

Both GPUs are in separate IOMMU groups, allowing independent passthrough:
- RTX 3080 Ti: IOMMU Group (3e:00.0 and 3e:00.1)
- RTX 3080: IOMMU Group (3f:00.0 and 3f:00.1)

---

## Lessons Learned

### 1. "Not Booting" Often Means "Can't See It"

When troubleshooting GPU passthrough issues, if you can ping the host but see no display, it's almost always a display routing problem, not a boot failure. GPUs bound to vfio-pci don't provide console output.

### 2. Console Access with Passthrough GPUs

With GPU passthrough enabled, you need a "spare" GPU for console access, or use:
- Serial console access
- SSH (the reliable standby)
- noVNC via Proxmox web UI (for VMs)

### 3. ASUS BIOS Settings for Dual GPU

The critical setting for dual high-end GPUs: **Above 4G Decoding: Enabled**

Without this, PCIe devices can't access memory above 4GB, causing initialization failures with modern GPUs.

### 4. initramfs Matters

VFIO driver binding happens early in the boot process. After modifying `/etc/modprobe.d/vfio.conf`, you **must** run:

```bash
update-initramfs -u -k all
```

Otherwise your changes won't take effect even after reboot.

### 5. Audio Follows Video

Both GPUs share the same audio controller PCI ID (10de:1aef). Include it in the VFIO configuration once, and both VMs get their GPU audio passthrough automatically.

### 6. Verify Before Assuming

When asked "anything else need to be updated, grub?", the instinct is to say "probably." But verification showed GRUB and blacklist were already correct. Don't make unnecessary changes.

---

## Current Status

**pve007 Configuration**: ✅ Complete

- Two GPUs successfully configured for passthrough
- RTX 3080 Ti assigned to VM 701 (Seb)
- RTX 3080 assigned to VM 702 (RTB)
- VFIO driver binding updated and applied
- System rebooted successfully

**Next Steps**:
1. Test VM 701 boot with RTX 3080 Ti passthrough
2. Test VM 702 boot with RTX 3080 passthrough
3. Verify both VMs can run simultaneously
4. Connect monitors to respective GPU HDMI outputs
5. Begin P2V migration of boys' physical gaming PCs to VMs

**Related Work**:
- VM 701 and 702 restoration from Disk2vhd backups (in progress)
- VHDX to qcow2 conversions running on CephFS
- Migration to pve008 for production deployment

---

## Files Modified

1. **`/etc/modprobe.d/vfio.conf`** - Added RTX 3080 PCI ID (10de:2206)
2. **`/etc/pve/qemu-server/702.conf`** - Changed GPU assignment to RTX 3080

## Commands Executed

```bash
# Updated VFIO configuration
echo 'options vfio-pci ids=10de:2208,10de:2206,10de:1aef disable_vga=1' > /etc/modprobe.d/vfio.conf

# Updated VM 702 to use RTX 3080
qm set 702 --hostpci0 0000:3f:00.0,pcie=1,x-vga=1
qm set 702 --hostpci1 0000:3f:00.1,pcie=1

# Regenerated initramfs
update-initramfs -u -k all

# Rebooted to apply changes
reboot
```

---

**Status**: Configuration complete, ready for VM testing
**Duration**: ~30 minutes from diagnosis to reboot
**Success**: ✅ Both GPUs configured for independent VM passthrough

---

*The beauty of dual GPU passthrough is that two kids can game simultaneously, each with their own dedicated hardware, while the host quietly manages everything in the background. No sharing, no compromises - just pure gaming bliss.*
