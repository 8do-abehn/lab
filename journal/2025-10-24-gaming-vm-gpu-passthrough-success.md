# Lab Journal - October 24, 2025: The GPU Passthrough Gaming Quest

## Mission: Create a Windows Gaming VM with NVIDIA RTX 3080 Ti Passthrough for Sunshine/Moonlight Streaming

Started with "let's set up gaming with GPU passthrough" and ended with a working Windows 11 VM streaming games. Along the way: discovered LXC limitations, learned why preparation matters, and proved that sometimes the documentation you need is scattered across multiple sources.

## The Journey

### Act 1: The LXC Dream (and Nightmare)

**The Plan:** Use an LXC container for gaming
- Lighter than VMs
- Better resource sharing
- GPU passthrough "should work"
- Found in our notes: LXC 500 (gaming-poc) already existed from previous attempts

**The Setup:**
- Ubuntu 24.04 LXC container
- 16GB RAM, 8 cores, 100GB storage
- GPU devices passed through: `/dev/nvidia*`
- NVIDIA drivers installed (535.183.01)
- XFCE desktop environment

**What Worked:**
```bash
nvidia-smi
# RTX 3080 Ti detected! 12GB VRAM, CUDA 12.2
```
✅ GPU passthrough to container successful
✅ NVIDIA kernel drivers working
✅ Device files accessible

**What Didn't Work:**
```
(EE) NVIDIA: Failed to initialize the NVIDIA kernel module
(EE) no screens found
Fatal server error
```

❌ X server couldn't initialize NVIDIA in container
❌ Xvfb crashed with EGL library conflicts
❌ Sunshine needs X server to capture display

**The Problem Discovered:**
LXC containers can access GPU devices, but the NVIDIA X server driver can't initialize the kernel module through the container's device access layer. This is fundamentally different from bare metal or VMs.

**Symptoms:**
- `nvidia-smi` works (uses different code path)
- X server with NVIDIA driver fails to initialize
- Multiple attempts with different X configurations all failed
- Library conflicts between container Mesa/EGL and NVIDIA libraries

**Time Spent:** ~6 hours of troubleshooting X server crashes

**The Realization:**
From research: "Most successful Proxmox gaming setups use VMs, not LXC for exactly this reason."

**Decision:** Abandon LXC approach, switch to VM

### Act 2: The First VM Attempts (Missing the Foundation)

**Attempt 1: CLI VM Creation (VM 501)**
Created Windows 11 VM via command line:
- UEFI BIOS, Q35 machine
- TPM 2.0, EFI disk
- GPU passthrough configured: `hostpci0: 3e:00,pcie=1,x-vga=1`
- Display set to none

**Result:** VM wouldn't start
- Lock files
- Silent failures
- No error messages in logs

**Attempt 2: GUI VM Creation (VM 500)**
Created via Proxmox web UI:
- Same configuration
- Added QEMU guest agent
- GPU passthrough with Primary GPU enabled

**Result:** Same failures
- Stuck on "starting"
- Lock file timeouts
- Something fundamentally wrong

**The Missing Piece:**
After reading https://forum.proxmox.com/threads/2025-proxmox-pcie-gpu-passthrough-with-nvidia.169543/

We discovered: **The Proxmox HOST wasn't configured for GPU passthrough!**

### Act 3: The Host Configuration (The Actual Solution)

**The Investigation:**
```bash
lspci -nnk -s 3e:00.0
# No "Kernel driver in use" line
# NVIDIA drivers available but not bound to VFIO
```

**The Missing Configuration:**

**1. GRUB Parameters** (Already configured from previous work)
```bash
cat /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt video=vesafb:off video=efifb:off initcall_blacklist=sysfb_init"
```
✅ IOMMU enabled
✅ Framebuffer disabled

**2. VFIO Modules** (Already loaded)
```bash
cat /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```
✅ Modules configured

**3. Driver Blacklist** (MISSING!)
```bash
cat /etc/modprobe.d/blacklist.conf
# File didn't exist!
```
❌ NVIDIA drivers not blacklisted on host

**4. VFIO Device Binding** (MISSING!)
```bash
cat /etc/modprobe.d/vfio.conf
# File didn't exist!
```
❌ GPU not bound to vfio-pci driver

**The Fix:**

Created `/etc/modprobe.d/blacklist.conf`:
```
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
```

Created `/etc/modprobe.d/vfio.conf`:
```
options vfio-pci ids=10de:2208,10de:1aef disable_vga=1
```
- `10de:2208` = RTX 3080 Ti GPU
- `10de:1aef` = GPU HDMI Audio

Updated initramfs:
```bash
update-initramfs -u -k all
```

Rebooted pve007.

**Verification After Reboot:**
```bash
lspci -nnk -s 3e:00
3e:00.0 VGA compatible controller...
	Kernel driver in use: vfio-pci  ← SUCCESS!
3e:00.1 Audio device...
	Kernel driver in use: vfio-pci  ← SUCCESS!
```

**Important Side Effect:**
`nvidia-smi` no longer works on the host (expected - host doesn't control GPU anymore)

### Act 4: The Third Time's the Charm (Working VM)

**The Approach:**
Since we kept failing with CLI/config, used the GUI to see exactly what was happening.

**Key Decision:** Keep virtual display during Windows installation
- NOT setting GPU as "Primary GPU" initially
- Keep Display as "Default"
- This lets us see the Windows installer in Proxmox console
- Switch to GPU-only after drivers installed

**VM 500 Configuration (via Proxmox GUI):**

**General:**
- VM ID: 500
- Name: gaming-windows

**System:**
- Machine: q35
- BIOS: OVMF (UEFI)
- EFI Disk: ✅ on local-lvm
- TPM: ✅ v2.0 on local-lvm
- SCSI Controller: VirtIO SCSI single

**Hardware:**
- CPU: 8 cores, type: host
- Memory: 16384 MB (16GB)
- Disk: SCSI 0, 100GB on local-lvm
- Network: VirtIO on vmbr0
- CD/DVD 1: Windows 11 ISO (cephfs:iso/Win11_25H2_English_x64.iso)
- CD/DVD 2: VirtIO drivers ISO (local:iso/virtio-win.iso)
- PCI Device: RTX 3080 Ti (3e:00.0)
  - PCI-Express: ✅
  - Primary GPU: ❌ (initially - will enable later)
  - All Functions: ❌
- Display: Default (initially - will change to none later)

**Options:**
- QEMU Guest Agent: ✅ enabled

**Start VM:**
✅ VM started successfully!
✅ Display appeared on physical monitor connected to RTX 3080 Ti!

### Act 5: The Windows Installation Journey

**Challenge 1: No Keyboard/Mouse**
**Problem:** Windows installer running on monitor but no keyboard input

**Solution:** USB passthrough
- Hardware → Add → USB Device
- Selected USB keyboard by vendor/device ID
- Selected USB mouse by vendor/device ID
- ✅ Keyboard and mouse immediately worked in installer

**Challenge 2: No Disk Visible**
**Problem:** Windows installer "Where do you want to install Windows?" showed no disks

**Reason:** VirtIO SCSI controller needs drivers
**Solution:**
1. Downloaded VirtIO ISO to pve007:
   ```bash
   cd /var/lib/vz/template/iso
   wget -O virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso
   ```
2. Added to VM: `qm set 500 --ide0 local:iso/virtio-win.iso,media=cdrom`
3. In Windows installer:
   - Click "Load driver"
   - Browse to VirtIO CD → vioscsi → w11 → amd64
   - Select "Red Hat VirtIO SCSI controller"
   - Click Next
4. ✅ 100GB disk appeared!

**Windows Installation:**
- Selected disk, clicked Next
- Installation in progress (~10-20 minutes)
- Create local account (skipped internet setup)

**Challenge 3: No Network**
**Problem:** After Windows installed, no network connectivity

**Reason:** VirtIO network adapter needs drivers too
**Solution:** Install VirtIO network driver
- Browse VirtIO CD → NetKVM → w11 → amd64
- Right-click netkvm.inf → Install
- Or run virtio-win-guest-tools.exe to install all VirtIO drivers at once

**Status:** Windows 11 installed and running with GPU!

### Act 6: What Comes Next

**Remaining Steps:**
1. Install NVIDIA drivers in Windows
   - Download from nvidia.com
   - GeForce RTX 3080 Ti + Windows 11
   - Game Ready Driver
2. Install VirtIO guest tools (QEMU agent, balloon driver, etc.)
3. Switch to GPU-only mode:
   - Edit PCI device → Enable "Primary GPU"
   - Edit Display → Change to "none"
   - Proxmox console won't work anymore (expected)
4. Install Sunshine streaming server
   - Access via RDP or physical monitor
   - Configure at https://localhost:47990
5. Test Moonlight from laptop

## What We Learned

### LXC Limitations for GPU Gaming
- LXC GPU passthrough works for compute (CUDA, encoding)
- LXC GPU passthrough FAILS for graphics (X server, gaming)
- X server cannot initialize NVIDIA driver in LXC containers
- Library conflicts are unfixable (container Mesa vs NVIDIA)
- VMs are the proven path for GPU gaming

### Proxmox GPU Passthrough Requirements
Three critical components must ALL be configured:

**1. GRUB/Kernel Parameters:**
- Enable IOMMU: `amd_iommu=on` (AMD) or `intel_iommu=on` (Intel)
- Passthrough mode: `iommu=pt`
- Disable framebuffers: `video=vesafb:off video=efifb:off`
- Optional: `initcall_blacklist=sysfb_init`

**2. Blacklist Host Drivers:**
Create `/etc/modprobe.d/blacklist.conf`:
```
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
```

**3. Bind GPU to VFIO:**
Create `/etc/modprobe.d/vfio.conf`:
```
options vfio-pci ids=<GPU_ID>,<AUDIO_ID> disable_vga=1
```

**Then:** `update-initramfs -u -k all` and reboot

**Verify:** `lspci -nnk` should show `Kernel driver in use: vfio-pci`

### Windows VM Best Practices

**VirtIO is worth it but needs drivers:**
- VirtIO SCSI = best disk performance
- VirtIO Network = best network performance
- BUT requires loading drivers during Windows install
- Keep VirtIO ISO handy: https://fedorapeople.org/groups/virt/virtio-win/

**Two approaches to GPU passthrough:**

**Approach A: Virtual Display During Setup (Easier)**
- Don't set GPU as "Primary GPU" initially
- Keep Display as "Default" or "VGA"
- Install Windows via Proxmox console
- Install NVIDIA drivers
- THEN enable Primary GPU + set Display to none
- Switch to physical/streaming access

**Approach B: GPU Only from Start**
- Set GPU as "Primary GPU"
- Set Display to "none"
- Requires physical monitor connected to GPU
- Complete install on physical monitor

**Recommendation:** Use Approach A - see everything in Proxmox console during setup

### USB Passthrough for Input
- Use "USB Vendor/Device ID" method (not "USB Port")
- More flexible (can move devices to different ports)
- Keyboard and mouse passthrough works immediately
- No reboot needed

### Common Mistakes We Made

1. **Assuming LXC would work like VM** - It doesn't for graphics
2. **Not configuring host for passthrough first** - GPU must be bound to vfio-pci
3. **Trying to start VM with GPU before host config** - Silent failures, lock files
4. **Not having VirtIO drivers ready** - Windows can't see VirtIO disks/network
5. **Setting Display to none too early** - Can't see what's happening during install

### Research Sources That Helped

**LXC Attempts:**
- https://docs.lizardbyte.dev/projects/sunshine/latest/ (Sunshine docs)
- https://markhamilton.info/headless-nvidia-4k120hz-streaming-on-ubuntu-24-04/ (Headless NVIDIA streaming)
- Forum discussions about Sunshine on Proxmox LXC

**VM Success:**
- https://forum.proxmox.com/threads/2025-proxmox-pcie-gpu-passthrough-with-nvidia.169543/ (THE KEY GUIDE!)
- https://pve.proxmox.com/wiki/PCI_Passthrough (Official Proxmox docs)
- Various Proxmox forum threads about GPU passthrough

## Current State

**Working:**
- ✅ Proxmox host configured for GPU passthrough
- ✅ GPU bound to vfio-pci driver
- ✅ Windows 11 VM created (VM 500)
- ✅ RTX 3080 Ti passed through to VM
- ✅ Windows 11 installed
- ✅ Display output on physical monitor
- ✅ USB keyboard/mouse working
- ✅ VirtIO SCSI disk working
- ✅ Network driver being installed

**In Progress:**
- 🚧 Installing VirtIO network driver
- 🚧 Need to install NVIDIA drivers
- 🚧 Need to install Sunshine
- 🚧 Need to test Moonlight streaming

**Blocked:**
- ⛔ LXC approach abandoned (fundamental limitations)
- ⛔ VMs 500 and 501 cleaned up (lock file issues)

## Next Steps

### Immediate (Today)
1. ✅ Install VirtIO network driver
2. Install NVIDIA GeForce drivers
3. Install VirtIO guest tools (QEMU agent)
4. Reboot and verify GPU working in Windows

### Short-term (This Evening)
5. Enable GPU as Primary GPU
6. Set Display to none (GPU-only mode)
7. Install Sunshine streaming server
8. Configure Sunshine web UI
9. Test Moonlight connection from X1 Carbon laptop

### Medium-term (This Week)
10. Install Steam
11. Test Portal (native Linux game via Proton)
12. Test other games from boys' list
13. Document performance metrics

### Long-term (Future)
14. Create Ansible playbook for gaming VM setup
15. Deploy to remaining Puget systems (pve008, pve009)
16. Each boy gets dedicated gaming VM

## Technical Artifacts

**System Information:**
```
Host: pve007 (Proxmox VE)
CPU: AMD Ryzen 9 5900X (24 cores)
RAM: 64GB
GPU: NVIDIA GeForce RTX 3080 Ti (12GB)
Kernel: 6.8.12-15-pve
```

**VM 500 Configuration:**
```
Name: gaming-windows
OS: Windows 11 Pro 25H2
Machine: q35
BIOS: OVMF (UEFI)
CPU: 8 cores (host type)
RAM: 16GB
Disk: 100GB (VirtIO SCSI on local-lvm)
Network: VirtIO on vmbr0
GPU: RTX 3080 Ti (PCI 3e:00.0) passthrough
USB: Keyboard + Mouse passthrough
TPM: 2.0
EFI: Enabled
```

**Host GRUB Configuration:**
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt video=vesafb:off video=efifb:off initcall_blacklist=sysfb_init"
```

**VFIO Configuration:**
```bash
# /etc/modprobe.d/blacklist.conf
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm

# /etc/modprobe.d/vfio.conf
options vfio-pci ids=10de:2208,10de:1aef disable_vga=1

# /etc/modules
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
```

**GPU Verification:**
```bash
lspci -nnk -s 3e:00
3e:00.0 VGA compatible controller: NVIDIA Corporation GA102 [GeForce RTX 3080 Ti] [10de:2208]
	Kernel driver in use: vfio-pci
3e:00.1 Audio device: NVIDIA Corporation GA102 High Definition Audio Controller [10de:1aef]
	Kernel driver in use: vfio-pci
```

## Lessons Learned

### Technical Lessons
1. **LXC vs VM for GPU graphics** - VMs are required for GPU gaming/graphics
2. **Host configuration is critical** - GPU must be bound to vfio-pci FIRST
3. **VirtIO requires drivers** - But performance is worth it
4. **Proxmox console limitations** - With GPU passthrough, console shows nothing
5. **USB passthrough is easy** - Vendor/Device ID method works great

### Process Lessons
6. **Read the right guides** - Intel SR-IOV guide ≠ NVIDIA passthrough guide
7. **Verify each layer** - Host config → VM config → Guest drivers
8. **GUI can be easier** - Sometimes clicking through UI shows what's wrong
9. **Research pays off** - Found the key forum post that had the missing steps
10. **Document as you go** - This journal captures valuable trial-and-error

### Project Management Lessons
11. **LXC was a 6-hour detour** - Should have researched VM vs LXC first
12. **Missing host config = 2 hours debugging VMs** - Check prerequisites first
13. **Total time: ~8 hours** - But now we have reproducible process
14. **Value of documentation** - Can deploy to 2 more Puget systems easily

## Random Insights

- The X1 Carbon 3rd Gen setup (zram) from earlier today feels like a different century
- GPU passthrough has layers: BIOS → Kernel → Host drivers → VFIO → VM config → Guest drivers
- Every layer must be correct or silent failures occur
- Proxmox forums have better info than scattered blog posts
- Sometimes "it should work" (LXC) means "it works for compute, not graphics"
- The boys' game list (Fortnite, Roblox, Minecraft) heavily favors Windows
- Physical monitor made debugging 10x easier than blind VNC attempts

## Success Metrics

### Minimum Viable (Achieved!)
- [x] GPU passthrough configured on host
- [x] Windows 11 VM created
- [x] GPU working in VM (display output)
- [x] Keyboard/mouse input working
- [ ] NVIDIA drivers installed (next step)

### Target Goals
- [ ] Sunshine streaming working
- [ ] Moonlight connects from laptop
- [ ] One game runs successfully
- [ ] Performance documented

### Stretch Goals
- [ ] All boys' games tested
- [ ] Ansible playbook created
- [ ] Deployed to 2 Puget systems
- [ ] Both boys gaming simultaneously

## The Turning Point

The moment everything clicked was reading:
```
options vfio-pci ids=10de:2208,10de:1aef disable_vga=1
```

And realizing: **We never told the host to give up the GPU!**

The host had IOMMU enabled, VFIO modules loaded, but still had claim to the GPU through the NVIDIA drivers. Only after blacklisting those drivers and explicitly binding the GPU to vfio-pci did passthrough actually work.

Everything before that was trying to pass through a GPU the host was still using.

---

*"The difference between 'enabled' and 'working' is configuration."* - Today's Hard-Won Wisdom
