---
title: "Two Kids, One Server: Building a Dual-GPU Gaming Setup on Proxmox"
date: 2025-11-12
draft: false
tags: ["proxmox", "gpu-passthrough", "gaming"]
description: "How I replaced two physical gaming PCs with a single Proxmox host running dual Windows VMs, each with its own dedicated NVIDIA GPU passthrough."
---

## The Problem

My two boys each had their own gaming PC. Two towers, two sets of peripherals, two machines to maintain, update, and troubleshoot. When I started consolidating everything into a Proxmox homelab, it seemed wasteful to keep two standalone gaming rigs around.

The plan: one host, two GPUs, two Windows VMs. Each boy gets a dedicated GPU, their own monitor, keyboard, and mouse. They can game simultaneously without knowing they're on virtual machines.

## The LXC Detour

I started where most container enthusiasts start: trying to do it in LXC. Lighter than VMs, better resource sharing, GPU passthrough "should work."

Six hours later, I had an Ubuntu LXC container where `nvidia-smi` detected the RTX 3080 Ti perfectly, but X server refused to initialize. The NVIDIA kernel module works through a different code path in containers than on bare metal. Compute workloads (CUDA, encoding) work fine in LXC. Graphics don't.

The takeaway was clear: VMs are the proven path for GPU gaming on Proxmox.

## Configuring the Host

The first VM attempts failed silently. Lock files, timeouts, no error messages. After chasing ghosts for two hours, I found the problem: the Proxmox host wasn't actually configured for GPU passthrough.

IOMMU was enabled and VFIO modules were loaded, but the host still had claim to the GPU through NVIDIA drivers. Three things need to be in place before a GPU can pass through to a VM:

**1. Kernel parameters** for IOMMU and framebuffer disabling:
```
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on iommu=pt video=vesafb:off video=efifb:off"
```

**2. Driver blacklist** so the host doesn't grab the GPU:
```
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
```

**3. VFIO device binding** to reserve the GPU for VM passthrough:
```
options vfio-pci ids=10de:2208,10de:1aef disable_vga=1
```

After `update-initramfs -u -k all` and a reboot, `lspci -nnk` showed `Kernel driver in use: vfio-pci`. The GPU was ready.

## The First Gaming VM

With the host configured, building the VM went smoothly using the Proxmox GUI: Q35 machine, OVMF UEFI, TPM 2.0, VirtIO SCSI storage, and the RTX 3080 Ti as a PCI passthrough device.

One key decision: don't set the GPU as "Primary GPU" during Windows installation. Keep the virtual display active so you can watch the installer through the Proxmox console. Switch to GPU-only after drivers are installed.

Windows 11 needed VirtIO drivers to see the disk (load the `vioscsi` driver during install) and another for networking (`NetKVM`). Both come from the VirtIO drivers ISO. USB passthrough for keyboard and mouse worked immediately using the vendor/device ID method.

## Going Dual-GPU

The second GPU (RTX 3080) went into the same host. Both cards landed in separate IOMMU groups, which is the key requirement for independent passthrough.

The only real hiccup was a display routing confusion. After binding the first GPU to VFIO, the host appeared to "not boot" when a monitor was connected to it. The system was running fine, just outputting video through the wrong card. SSH confirmed it was up the whole time.

Updated VFIO config to include both GPU PCI IDs, regenerated initramfs, rebooted. Two GPUs bound to `vfio-pci`, two VMs each with a dedicated card.

## Migration to the Permanent Host

The initial setup was on a loaner machine. Moving to the permanent host (AMD Ryzen 9 5900X, 64GB RAM, dual RTX 3080s) meant offline-migrating 750GB VMs across the cluster.

The migration process for VMs with passthrough devices:
1. Remove GPU and USB passthrough from the VM config
2. Set VGA back to `std`
3. Offline migrate with target storage specified
4. Re-add passthrough devices using the new host's PCI addresses
5. Set VGA back to `none`

The 5900X has no integrated GPU, so with both discrete cards passed to VMs, the host runs headless. SSH-only management from here on.

TPM state didn't survive the migration cleanly. Both VMs prompted for BitLocker recovery keys (retrieved from Microsoft accounts), and one needed its TPM logical volume recreated. Worth knowing before you start.

## The Final Setup

Each boy's VM runs with 8 CPU cores, 32GB RAM, a dedicated RTX 3080, 750GB of storage, and USB-passthrough peripherals. Both VMs start simultaneously from the Proxmox interface.

The boys don't know they're on VMs. Performance is native-level since each GPU is exclusively assigned. Fortnite, Roblox, and Minecraft all run without issues.

## What I'd Do Differently

**Skip the LXC experiment.** Every GPU gaming success story on Proxmox uses VMs. I should have researched this before spending six hours on it.

**Configure the host first.** The silent failures from trying to start VMs before binding GPUs to VFIO wasted two hours. Verify `lspci -nnk` shows `vfio-pci` before creating any VM.

**Pre-install VirtIO drivers.** For P2V migrations, installing VirtIO guest tools on the physical machines before cloning made the transition seamless. The cloned VMs booted without driver issues.

**Keep a spare display output.** With all GPUs bound to VFIO, you lose console access. Plan for SSH-only management or keep an iGPU-equipped CPU if you want local console.

## Why It Works

Instead of maintaining two physical gaming PCs:
- One host handles both VMs with dedicated GPUs
- Backups and snapshots are trivial through Proxmox
- Resource allocation (RAM, CPU cores) is adjustable without opening a case
- The whole thing integrates with the rest of the homelab infrastructure
- Management happens from any browser on the network

The consolidation pays for itself in reduced maintenance alone.
