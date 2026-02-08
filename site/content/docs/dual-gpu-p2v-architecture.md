---
title: "Dual GPU P2V Architecture - Boys' Gaming VMs"
date: 2025-12-22
draft: true
tags: ["proxmox", "tailscale", "gpu-passthrough", "kubernetes", "media-server", "lxc"]
---


**Date**: 2025-10-24
**Status**: In Progress
**Approach**: Physical-to-Virtual migration with dedicated GPU passthrough per VM

## Executive Summary

Migrating two physical Windows gaming PCs to VMs running on a single Proxmox host (pve008) with dual RTX 3080 GPU passthrough. Each boy gets their own dedicated VM, GPU, monitor, keyboard, and mouse - running simultaneously on one physical server.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    pve008 (Puget Workstation)               │
│             AMD Ryzen 9 5900X, 64GB RAM, 2x RTX 3080        │
└─────────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
            ▼                               ▼
┌─────────────────────┐         ┌─────────────────────┐
│   VM 701 (vm-seb)   │         │   VM 702 (vm-rtb)   │
│                     │         │                     │
│ Windows 11 (UEFI)   │         │ Windows 11 (UEFI)  │
│ 6 cores, 12GB RAM   │         │ 6 cores, 12GB RAM  │
│ 250GB C: + 500GB D: │         │ 250GB C: + 500GB D:│
│                     │         │                     │
│ RTX 3080 #1         │         │ RTX 3080 #2        │
│ USB: KB+Mouse #1    │         │ USB: KB+Mouse #2   │
│ Monitor #1 (HDMI)   │         │ Monitor #2 (HDMI)  │
│ Audio via HDMI      │         │ Audio via HDMI     │
└─────────────────────┘         └─────────────────────┘
```

## Hardware Architecture

### Gaming Host: pve008
**Source**: Personal Puget Workstation
- CPU: AMD Ryzen 9 5900X (24 threads)
- RAM: 64GB DDR4
- GPU: 2x RTX 3080
- Storage: Local LVM + shared storage
- Purpose: Dual-GPU gaming VMs (vm-seb, vm-rtb)

### Support Host: pve007
**Source**: Puget Workstation (was planned as pve009, renumbered)
- CPU: AMD Ryzen 9 5900X
- RAM: 64GB DDR4
- GPU: 2x AMD RX 570
- Purpose: Other VMs, K8s workers, LXC GPU workloads

### Additional Host: pve009 (pending)
**Source**: Original work loaner (keeping it)
- CPU: AMD Ryzen 9 5900X
- RAM: 64GB DDR4
- GPU: RTX 3080 Ti
- Purpose: Additional compute, GPU workloads
- Status: To be added to cluster

## VM Specifications

### VM 701 (vm-seb) - Seb's Gaming VM

**Hardware Configuration**:
```
VMID: 701
Name: vm-seb
Memory: 12GB (12288 MB)
CPU: 6 cores, 1 socket, host type
Boot: UEFI (OVMF)
TPM: 2.0
Machine Type: q35
BIOS: OVMF

Storage:
- scsi0: 250GB (C: drive) - VirtIO SCSI, iothread
- scsi1: 500GB (D: drive) - VirtIO SCSI, iothread, SSD flag
- efidisk0: 4MB EFI partition
- tpmstate0: 4MB TPM 2.0 state

GPU: PCI passthrough (x-vga=1, PCIe=1)
Network: VirtIO (bridge vmbr0)
Storage Controller: VirtIO SCSI Single

Peripherals:
- Dedicated keyboard (USB passthrough)
- Dedicated mouse (USB passthrough)
- Monitor via HDMI (direct GPU output)
- Audio via HDMI to monitor
```

**Software**:
- Windows 11 (cloned from physical PC)
- VirtIO drivers pre-installed
- Existing games, Steam library, saves preserved
- All user data and settings intact

**GPU Assignment (on pve008)**:
- PCI Address: TBD (first RTX 3080)
- x-vga=1 for primary display
- Direct HDMI output to monitor

### VM 702 (vm-rtb) - RTB's Gaming VM

**Hardware Configuration**:
```
VMID: 702
Name: vm-rtb
[Identical specs to VM 701]

GPU Assignment (on pve008):
- PCI Address: TBD (second RTX 3080)
- x-vga=1 for primary display
- Direct HDMI output to monitor
```

## Migration Strategy

### Phase 1: P2V on pve007 (Current Phase)

**Status**: In Progress

**Steps**:
1. ✅ Install VirtIO drivers on both physical PCs
2. ✅ Verify both PCs are UEFI boot
3. ✅ Create VM 701 (vm-seb) on pve007
4. ⏳ Clone Seb's PC → VM 701 using Clonezilla
5. ⏳ Test VM 701 boots and works
6. ⏳ Create VM 702 (vm-rtb) on pve007
7. ⏳ Clone RTB's PC → VM 702 using Clonezilla
8. ⏳ Test VM 702 boots and works

**Testing on pve007**:
- Each VM tested individually (only one GPU available)
- Verify boot, drivers, games work
- Confirm all data migrated correctly
- Test performance, GPU passthrough

### Phase 2: Cluster Setup (Completed)

**What happened**:
1. pve008 added to cluster (dual RTX 3080 gaming host)
2. New pve007 added to cluster (2x RX 570, was originally planned as pve009)
3. Original pve007 (work loaner) removed from cluster, will be re-added as pve009

### Phase 3: Dual GPU Configuration (Completed)

**Steps**:
1. Installed 2x RTX 3080 in pve008
   - Both GPUs detected
2. Configure IOMMU groups on pve008
   - Verify each GPU in separate IOMMU group
   - Or prepare to pass entire groups
3. Bind GPUs to vfio-pci driver
   - Prevent host from loading nvidia/nouveau
   - Enable passthrough
4. Test GPU detection in Proxmox

**IOMMU Configuration**:
```bash
# Enable IOMMU in GRUB
nano /etc/default/grub
# Add: intel_iommu=on iommu=pt (or amd_iommu=on for AMD)

# Update GRUB
update-grub

# Load vfio modules
nano /etc/modules
# Add:
# vfio
# vfio_iommu_type1
# vfio_pci
# vfio_virqfd

# Blacklist nvidia drivers on host
nano /etc/modprobe.d/blacklist.conf
# Add:
# blacklist nouveau
# blacklist nvidia
# blacklist nvidiafb

# Update initramfs
update-initramfs -u -k all

# Reboot
reboot
```

### Phase 4: VM Migration and Configuration

**Steps**:
1. Migrate VM 701 from pve007 → pve008
   - Use Proxmox migration tool
   - Or export/import if needed
2. Migrate VM 702 from pve007 → pve008
3. Update VM 701 GPU passthrough config
   - Assign first RTX 3080
   - Update PCI address
4. Update VM 702 GPU passthrough config
   - Assign second RTX 3080
   - Update PCI address
5. Configure USB passthrough
   - Identify USB device IDs (lsusb)
   - Assign Seb's keyboard/mouse to VM 701
   - Assign RTB's keyboard/mouse to VM 702

**VM Update Commands**:
```bash
# On pve008, update GPU passthrough
qm set 701 -hostpci0 0000:XX:00.0,pcie=1,x-vga=1
qm set 702 -hostpci0 0000:YY:00.0,pcie=1,x-vga=1

# Add USB devices (get IDs from lsusb)
qm set 701 -usb0 host=XXXX:YYYY  # Seb's keyboard
qm set 701 -usb1 host=XXXX:YYYY  # Seb's mouse
qm set 702 -usb0 host=XXXX:YYYY  # RTB's keyboard
qm set 702 -usb1 host=XXXX:YYYY  # RTB's mouse
```

### Phase 5: Physical Setup and Testing

**Steps**:
1. Connect monitors
   - Monitor #1 → HDMI → GPU #1 (VM 701)
   - Monitor #2 → HDMI → GPU #2 (VM 702)
2. Connect keyboards and mice
   - Seb's KB+Mouse → USB ports (note which ports)
   - RTB's KB+Mouse → USB ports (note which ports)
3. Start both VMs simultaneously
4. Verify both boot to Windows
5. Test gaming on both VMs
6. Test audio through HDMI
7. Verify no conflicts or performance issues

### Phase 6: Production Deployment

**Steps**:
1. Return pve007 to work
2. Configure VM autostart on pve008
3. Set up backups for both VMs
4. Create restore/disaster recovery plan
5. Document for boys how to use
6. Monitor performance over time

## Key Technical Decisions

### Why P2V Instead of Fresh Install?

**Advantages**:
- Preserves all games, saves, settings
- No re-download of game libraries (100s of GB)
- Boys' setup exactly as they know it
- Faster deployment
- Less disruption

**Challenges**:
- VirtIO driver installation (solved: pre-installed)
- UEFI/BIOS matching (solved: both UEFI)
- Windows activation (may need to reactivate)
- Disk sizing (250GB + 500GB should be enough)

### Why VirtIO SCSI Storage?

**Benefits**:
- Best performance for VMs
- Native paravirtualization
- iothread support for parallel I/O
- Trim/discard support (SSD optimization)

**Requirements**:
- VirtIO drivers must be installed
- ✅ Pre-installed on physical PCs before migration

### Why UEFI + TPM 2.0?

**Requirements**:
- Windows 11 requires TPM 2.0
- UEFI provides better boot support
- Physical PCs are UEFI (clean migration)

**Benefits**:
- Modern boot process
- Secure Boot support (if needed)
- Better hardware compatibility

### Why Separate GPUs Instead of vGPU?

**Reasons**:
- vGPU requires enterprise GPUs (Tesla/A-series)
- vGPU requires expensive NVIDIA licensing
- Consumer RTX 3080s cannot do vGPU
- Dedicated GPU gives full performance

**Approach**:
- Each VM gets exclusive access to one physical GPU
- Simple, proven, high performance
- No sharing overhead

## Resource Allocation

### pve008 Total Resources
- CPU: 24 threads (12 cores, SMT)
- RAM: 64GB DDR4
- GPU: 2x RTX 3080
- Storage: Local LVM + network storage

### Allocation Plan
```
VM 701 (vm-seb):      6 cores,  12GB RAM,  1x RTX 3080
VM 702 (vm-rtb):      6 cores,  12GB RAM,  1x RTX 3080
Other VMs/LXCs:       8 cores,  32GB RAM
Proxmox overhead:     4 cores,   8GB RAM
──────────────────────────────────────────────────────
TOTAL:               24 cores,  64GB RAM,  2x RTX 3080
```

**Note**: This is a reasonable allocation with some CPU oversubscription acceptable for non-simultaneous peak loads.

## Network Configuration

### VM Network Setup
- Bridge: vmbr0 (connected to physical network)
- Each VM gets DHCP or static IP
- Firewall: Enabled on Proxmox bridge
- Accessible from local network

### Considerations
- May want to set static IPs for each VM
- Configure port forwarding if needed
- Tailscale on VMs for remote access (optional)

## Backup Strategy

### VM Backups
```bash
# Proxmox backup configuration
# Schedule: Daily at 2 AM
# Retention: 7 daily, 4 weekly, 3 monthly
# Mode: Snapshot (if supported) or stop
# Compression: ZSTD
```

### Important Data
- Game saves (usually in user profile)
- Steam library (can be re-downloaded)
- Custom configurations
- Screenshots, recordings

### Recovery Plan
- Keep physical PCs intact initially
- Test restore process
- Document restore steps
- After 30 days of successful operation, repurpose physical PCs

## Monitoring and Management

### GPU Monitoring
```bash
# Install nvidia-smi on host (if possible with vfio)
# Or monitor from VMs

# Check GPU usage
nvidia-smi

# Watch in real-time
watch -n 1 nvidia-smi
```

### VM Monitoring
- Proxmox web UI shows CPU, RAM, disk, network
- Set up alerts for high resource usage
- Monitor disk space on VMs
- Check for Windows updates

### Performance Metrics
- Track FPS in games (before vs after migration)
- Monitor boot times
- Check for any lag or stuttering
- Verify audio quality

## Troubleshooting Guide

### Issue: VM Won't Boot After Migration
**Possible Causes**:
- Missing VirtIO drivers
- Boot order incorrect
- EFI partition issues

**Solutions**:
```bash
# Check boot order
qm config 701 | grep boot

# Update boot order if needed
qm set 701 -boot order=scsi0

# Try booting from Windows install media to repair boot
```

### Issue: GPU Not Detected in VM
**Possible Causes**:
- IOMMU not enabled
- GPU not bound to vfio-pci
- IOMMU groups overlapping

**Solutions**:
```bash
# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l

# Verify GPU bound to vfio
lspci -nnk | grep -A 3 NVIDIA

# Check VM config
qm config 701 | grep hostpci
```

### Issue: Windows Requires Reactivation
**Solutions**:
- Use existing product key
- Digital licenses usually survive hardware changes
- Contact Microsoft support if needed
- Worst case: Purchase new Windows 11 license

### Issue: USB Devices Not Working
**Solutions**:
```bash
# List USB devices
lsusb

# Verify USB passthrough config
qm config 701 | grep usb

# Try different USB ports
# May need to use USB controller passthrough instead
```

### Issue: Performance Lower Than Expected
**Checks**:
- Verify both VMs not competing for same resources
- Check CPU pinning (may want to pin cores)
- Verify RAM is allocated, not ballooning
- Check GPU temperatures
- Ensure VirtIO drivers installed
- Verify iothread enabled on disks

## Success Criteria

### Must Have (Critical)
- ✅ Both VMs boot successfully
- ✅ Each VM has working GPU passthrough
- ✅ Games run at acceptable performance
- ✅ Keyboard/mouse work for each boy
- ✅ Monitors display correctly via HDMI
- ✅ Audio works through HDMI

### Should Have (Important)
- ✅ Both VMs can run simultaneously
- ✅ No performance degradation when both active
- ✅ All existing games and saves work
- ✅ Backups configured
- ✅ Autostart on boot

### Nice to Have (Optional)
- ✅ Performance equal to or better than physical PCs
- ✅ Easy for boys to use
- ✅ Remote access capability
- ✅ Snapshot capability for "undo" if issues
- ✅ Monitoring dashboard

## Timeline

**Phase 1 (Current)**: P2V Migration on pve007
- Started: 2025-10-24
- Duration: 2-3 days
- Goal: Both VMs working individually

**Phase 2**: Cluster Setup ✓
- pve007 (2x RX 570) and pve008 (2x RTX 3080) in cluster
- pve009 (RTX 3080 Ti) pending addition

**Phase 3**: Dual GPU Setup
- Duration: 1 day
- Goal: Both GPUs accessible in pve008

**Phase 4**: VM Migration
- Duration: 1 day
- Goal: Both VMs on pve008 with GPU passthrough

**Phase 5**: Physical Setup
- Duration: 1 day
- Goal: Monitors, keyboards, mice connected and working

**Phase 6**: Production
- Duration: 1 day
- Goal: Return pve007, finalize setup

**Total Estimated Time**: 7-10 days

## Future Enhancements

### Potential Upgrades
- More RAM per VM if needed (8-12GB → 16GB)
- More CPU cores if games require it
- Additional storage for game libraries
- Faster network for Steam downloads

### Advanced Features
- GPU passthrough to other VMs when boys not gaming
- Automated VM suspend/resume
- Performance optimization (CPU pinning, huge pages)
- Advanced monitoring (Grafana dashboards)

### Expansion Options
- Add third VM for dad with passed-through GPU (when boys not gaming)
- USB hub passthrough for easier peripheral management
- Looking Glass for zero-latency remote access
- PCI USB controller passthrough for full USB control

## Related Documentation

- **Migration Guide**: `p2v-migration-notes.md`
- **Session Journal**: `journal/2025-10-24-p2v-migration-project-started.md`
- **Original Plan (Superseded)**: `pve007-gpu-architecture-recommendation.md`

## References

- [Proxmox GPU Passthrough Guide](https://pve.proxmox.com/wiki/PCI_Passthrough)
- [VirtIO Drivers](https://fedorapeople.org/groups/virt/virtio-win/)
- [IOMMU Groups Explained](https://vfio.blogspot.com/)
- Clonezilla Documentation
