---
title: "Journal Entry - 2025-10-24"
date: 2025-10-24
draft: true
tags: ["proxmox", "gpu-passthrough", "media-server"]
---


> **Context**: The "pve007" referenced here later became pve009. The "pve009" in plans became the new pve007. See `dual-gpu-p2v-architecture.md` for final layout.

## P2V Migration Project Started

Started a project to migrate my two boys' physical gaming PCs into VMs on Proxmox, with the eventual goal of running both simultaneously on one host using dual GPU passthrough.

### What We Accomplished Tonight

1. **Discovered the approach:**
   - Can absolutely run 2 VMs with 2 GPUs on one Proxmox host
   - Each VM gets dedicated GPU passthrough
   - Each boy will have their own monitor, keyboard, mouse
   - Audio works through HDMI to monitors

2. **Prepared physical PCs:**
   - Installed VirtIO drivers on both boys' PCs BEFORE cloning (smart!)
   - Verified both are UEFI boot (matches VM config perfectly)
   - This will make the P2V migration much smoother

3. **Created VM 701 (vm-seb) on pve007:**
   - 6 cores, 12GB RAM
   - 250GB C: drive + 500GB D: drive
   - UEFI boot, TPM 2.0 for Windows 11
   - RTX 3080 Ti GPU passthrough configured
   - VirtIO SCSI storage for best performance
   - Ready to receive cloned disk

4. **Planned the full migration:**
   - Phase 1: Clone and test on pve007 (work loaner)
   - Phase 2: Add my 2 Puget workstations to cluster (pve008, pve009)
   - Phase 3: Move GPU from pve009 to pve008 (dual GPU setup)
   - Phase 4: Migrate VMs to pve008, return pve007 to work

### Technical Details

**VM Specs (701 & 702):**
- 6 cores, 12GB RAM each
- 250GB system + 500GB data drives
- VirtIO SCSI with iothread, SSD flags
- UEFI + TPM 2.0
- GPU passthrough with x-vga=1
- VirtIO network

**Hardware:**
- pve007: RTX 3080 Ti (temporary testing host)
- Personal Puget #1 → pve008 (will get 2x RTX 3080s)
- Personal Puget #2 → pve009 (GPU will be moved to pve008)

### VirtIO Driver Install Process

Had some fun getting VirtIO drivers onto a USB stick:
- Initially tried `dd` to write ISO directly - got stuck
- Ended up reformatting USB to FAT32
- Copied just the `virtio-win-guest-tools.exe` installer
- Ran on both physical PCs
- Installed all VirtIO drivers (storage, network, balloon, etc.)
- Rebooted both PCs

This pre-installation means the cloned VMs should boot immediately without driver issues!

### Next Steps

**Immediate next session:**
1. Create Clonezilla Live USB
2. Boot Seb's PC from Clonezilla
3. Clone entire disk over SSH to pve007:/tmp/seb-clone
4. Import cloned disk image to VM 701's scsi0
5. Boot and test VM 701
6. Repeat for RTB's PC → VM 702

**After both VMs working:**
1. Add pve008 and pve009 to cluster
2. Physically move RTX 3080 from pve009 to pve008
3. Configure both GPUs in IOMMU groups
4. Migrate VMs from pve007 to pve008
5. Update GPU passthrough configs for both VMs
6. Set up USB passthrough for keyboards/mice
7. Connect monitors, test simultaneous operation
8. Return pve007 to work

### Challenges Overcome

1. **USB creation:** `dd` got stuck, pivoted to simpler FAT32 + file copy
2. **Pre-installing drivers:** This was key insight - install VirtIO on physical PCs BEFORE migration
3. **Planning dual-GPU setup:** Needed to understand IOMMU groups, GPU assignment, USB passthrough

### Why This is Cool

Instead of buying two separate gaming PCs for my boys, I can:
- Use one powerful host with 2 GPUs
- Each boy gets independent "computer" (VM)
- Can both game/browse simultaneously
- Easier to manage, backup, snapshot
- More economical than 2 physical machines
- Easy to adjust resources (RAM, CPU) as needed

### Lessons Learned

- GPU passthrough requires GPUs in separate IOMMU groups (or pass whole groups)
- Pre-installing VirtIO drivers makes P2V migration much smoother
- UEFI → UEFI migration is cleanest (both PCs matched!)
- VirtIO SCSI with iothread gives best VM storage performance
- Each GPU can only go to ONE VM at a time (no sharing without vGPU)

### Timeline

- Started: 2025-10-24
- VM 701 created and configured
- Ready to clone on next session
- Goal: Complete before pve007 goes back to work next week

---

**Current Status:** VM 701 (vm-seb) created and ready. Need to clone Seb's physical PC using Clonezilla.

**Mood:** Excited! This will be a great setup for the boys. One powerful machine instead of two separate PCs.

**Time spent:** ~2 hours (planning, research, VM creation, driver prep)
