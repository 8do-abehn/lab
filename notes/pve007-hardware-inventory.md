# PVE007 Hardware Inventory

**Date**: 2025-10-23
**Purpose**: GPU passthrough planning for gaming, AI, and media workloads

## Hardware Specifications

### System
- **Node**: pve007
- **OS**: Debian GNU/Linux 12 (bookworm) / Proxmox VE
- **Kernel**: 6.8.12-15-pve
- **Uptime**: 10+ days

### CPU
- **Model**: AMD Ryzen 9 5900X 12-Core Processor
- **Cores**: 12 physical cores
- **Threads**: 24 (SMT enabled)
- **Socket**: 1
- **Max CPU**: 24 threads available
- **Features**: AMD-Vi (AMD IOMMU) enabled
- **Integrated Graphics**: None

### Memory
- **Total RAM**: 62 GiB (67.3 GB)
- **Used**: 34 GiB
- **Available**: 28 GiB
- **Swap**: 8 GiB (unused)

### Storage
- **Root**: 94 GB LVM volume (10% used - 8.2 GB)
- **Total Disk**: ~100 GB

### GPU
- **Model**: NVIDIA GeForce RTX 3080 Ti
- **Chip**: GA102 (rev a1)
- **PCI Bus**: 3e:00.0
- **IOMMU Group**: 33
- **Audio Controller**: NVIDIA GA102 High Definition Audio (3e:00.1, same IOMMU group)
- **Current Driver Status**: No NVIDIA drivers installed on host
- **Count**: 1 GPU only (no integrated graphics, no secondary GPU)

### IOMMU Configuration
- **Status**: ✅ Enabled and configured
- **Boot Parameters**: `amd_iommu=on iommu=pt`
- **Additional Flags**: `nomodeset video=vesafb:off video=efifb:off initcall_blacklist=sysfb_init`
- **IOMMU Groups**: 53 total groups
- **GPU Group**: Group 33 (GPU + Audio clean isolation)

### Current Workload on pve007

#### VMs (7 running)
- **301**: k3s-master-01 (6GB RAM, 4 vCPU)
- **401**: k3s-worker-01 (2GB RAM, 2 vCPU)
- **402**: k3s-worker-02 (2GB RAM, 2 vCPU)
- **403**: k3s-worker-03 (2GB RAM, 2 vCPU)
- **404**: k3s-worker-04 (2GB RAM, 2 vCPU)
- **405**: k3s-worker-05 (8GB RAM, 4 vCPU)
- **406**: k3s-worker-06 (8GB RAM, 4 vCPU)
- **9000**: ubuntu-22.04-template (stopped)

**Total VM allocation**: ~30GB RAM, ~20 vCPUs in use

#### LXC Containers
- None currently on pve007

## Proxmox Cluster Overview

### Nodes (7 total)
1. **pve001**: 4 CPU, 16 GB RAM
2. **pve002**: 4 CPU, 16 GB RAM
3. **pve003**: 4 CPU, 16 GB RAM
4. **pve004**: 4 CPU, 16 GB RAM
5. **pve005**: 4 CPU, 16 GB RAM
6. **pve006**: 4 CPU, 16 GB RAM
7. **pve007**: 24 CPU, 64 GB RAM ⭐ (RTX 3080 Ti)

**Note**: pve007 is the only node with a discrete GPU and significantly more resources than the others.

### Other Workloads in Cluster
- **LXC 101** (pve003): Docker container host
- **LXC 102** (pve004): UniFi controller
- **LXC 3001** (pve005): Jellyfin (currently running without GPU acceleration)
- **LXC 103** (pve001): Dev environment
- Various other containers on other nodes

## GPU Passthrough Feasibility Analysis

### ✅ Strengths
1. **IOMMU Already Configured**: AMD-Vi enabled, 53 IOMMU groups
2. **Clean GPU Isolation**: GPU + Audio in single IOMMU group 33 (ideal)
3. **Powerful Host**: 24 threads, 64 GB RAM - plenty of headroom
4. **Boot Parameters**: Already optimized for passthrough (`nomodeset`, etc.)

### ⚠️ Constraints
1. **Single GPU**: Only one RTX 3080 Ti, no integrated graphics
2. **No NVIDIA Drivers**: Currently not installed (good starting point)
3. **Active K8s Cluster**: 7 VMs running on this node
4. **No Console Fallback**: AMD CPU has no iGPU for Proxmox console access

### ❌ Limitations
1. **Cannot use vGPU**: RTX 3080 Ti is consumer card (no vGPU support)
2. **LXC vs VM conflict**: Must choose one passthrough method
3. **NVENC Limits**: Consumer cards limited to 3-5 simultaneous encode streams

## Architecture Constraints

Given the hardware inventory, here are the viable options:

### Option A: LXC-Only Approach ✅ RECOMMENDED
Multiple LXC containers sharing the single RTX 3080 Ti:
- Gaming container (Steam/Proton + Sunshine/Moonlight)
- AI workload container
- Jellyfin container (migrate from pve005)
- Handbrake container

**Pros**:
- All workloads can run simultaneously
- Efficient GPU sharing
- Simple to manage
- Works with single GPU

**Cons**:
- Gaming in LXC less common (but proven to work)
- Some game anti-cheat may not work
- Requires testing game compatibility

### Option B: VM Gaming + LXC Media/AI ⚠️ COMPLEX
Requires time-sharing or switching modes:
- Gaming hours: GPU passed to Windows VM
- Work hours: GPU available to LXC containers
- Need scripts to switch between modes

**Pros**:
- Best gaming compatibility
- Full Windows gaming experience

**Cons**:
- Cannot run gaming + other workloads simultaneously
- Complex mode switching
- Downtime during transitions
- Requires host driver reconfiguration

### Option C: Add Second GPU ❌ NOT FEASIBLE
Would need to install a second GPU for clean separation.

**Status**: Check if hardware supports / has slot available

## Migration Considerations

### Before Returning Puget Systems
1. **Current Jellyfin** (LXC 3001 on pve005): Migrate to pve007 with GPU
2. **K8s Workers**: May need to migrate some workers to other nodes if resources tight
3. **Backup Configuration**: Save current pve007 state before GPU changes

### After Removing 2 Puget Nodes
- Cluster will have 5 remaining nodes (pve001-006)
- pve007 becomes the only high-performance node
- GPU becomes critical shared resource

## Recommendations

1. **Primary Recommendation**: LXC-only approach (Option A)
   - Install NVIDIA drivers on pve007 host
   - Create LXC containers for all use cases
   - Test gaming with Steam + Proton first
   - Migrate Jellyfin from pve005 to pve007

2. **Fallback**: If gaming compatibility issues arise
   - Switch to VM for gaming
   - Use time-sharing approach
   - Schedule gaming hours vs. compute hours

3. **Resource Planning**:
   - Keep K8s master on pve007 (critical)
   - Migrate some K8s workers to pve001-006
   - Reserve ~32GB RAM for new GPU workloads
   - Reserve ~8 CPU threads for GPU containers

## Next Steps

1. ✅ Hardware inventory complete
2. Choose architecture (LXC vs VM approach)
3. Create detailed implementation guide
4. Test gaming container setup
5. Configure and test all workloads
6. Migrate Jellyfin
7. Document and backup
