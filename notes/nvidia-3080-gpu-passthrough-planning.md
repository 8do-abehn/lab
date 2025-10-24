# NVIDIA 3080 GPU Passthrough Planning for Proxmox

## Objective

Configure GPU passthrough for RTX 3080 to support multiple use cases:
- **Gaming**: Moonlight streaming for two boys
- **AI Workloads**: Machine learning tasks
- **Jellyfin**: Media transcoding
- **Handbrake**: Video encoding

**Timeline**: Implementation needed before Puget workstation return next week

## Key Findings from Research

### LXC vs VM Passthrough

#### LXC Container Passthrough (Recommended for Sharing)
- **Pros**:
  - Multiple LXC containers can share the same GPU simultaneously
  - Lower overhead than VMs
  - Easier to manage and configure
  - Perfect for AI, Jellyfin, Handbrake workloads
  - Host NVIDIA drivers remain installed
- **Cons**:
  - Less isolation than VMs
  - Gaming support requires running Steam/Proton in container (less common)
  - Cannot mix with VM passthrough on same GPU easily

#### VM Passthrough (Traditional Gaming Approach)
- **Pros**:
  - Full GPU isolation for single VM
  - Native gaming performance (5% overhead, 1-3ms latency)
  - Works perfectly with Moonlight/Sunshine streaming
  - Well-documented for Windows gaming VMs
- **Cons**:
  - Exclusive access - only one VM can use GPU at a time
  - Conflicts with LXC passthrough (requires blacklisting NVIDIA drivers)
  - Cannot share with other workloads simultaneously

### Critical Limitation

**You must choose**: LXC passthrough OR VM passthrough per GPU. The configuration methods conflict:
- VM passthrough: Blacklist NVIDIA drivers on host
- LXC passthrough: Requires NVIDIA drivers installed on host

## Architecture Options

### Option 1: LXC-Only Approach (Single GPU)

**Setup**:
- Install NVIDIA drivers on Proxmox host
- Create multiple LXC containers sharing the single 3080:
  - Gaming container (Steam + Proton + Moonlight server)
  - AI workload container
  - Jellyfin container
  - Handbrake container

**Pros**:
- Simplest sharing model
- All workloads can run concurrently
- Efficient resource usage

**Cons**:
- Gaming in LXC less common/tested
- May have compatibility issues with some games
- NVIDIA limits simultaneous encode/decode streams to 3-5

### Option 2: VM Gaming + Separate GPU for LXC

**Setup** (if you have 2 GPUs):
- GPU 1: Dedicated to Windows gaming VM with full passthrough
- GPU 2: Shared among LXC containers for AI/Jellyfin/Handbrake

**Pros**:
- Best gaming performance
- Clean separation of concerns
- Well-documented approach
- LXC containers still share resources efficiently

**Cons**:
- Requires 2 GPUs in the system
- More complex if you only have one 3080

### Option 3: Time-Sharing VM/LXC (Single GPU, Advanced)

**Setup**:
- Gaming VM with passthrough (for specific gaming times)
- LXC containers for other workloads (when gaming VM is off)
- Script to switch between modes

**Pros**:
- Works with single GPU
- Best gaming performance when gaming
- GPU available for other tasks when not gaming

**Cons**:
- Complex setup - requires reconfiguring host drivers
- Cannot run gaming and AI/media tasks simultaneously
- Requires scripting and automation
- Downtime when switching modes

### Option 4: VM Gaming with vGPU (If Available)

**Setup**:
- Use NVIDIA vGPU to slice GPU into multiple virtual GPUs
- Gaming VM gets larger slice
- Other VMs/containers get smaller slices

**Pros**:
- True simultaneous GPU sharing
- Best of both worlds

**Cons**:
- RTX 3080 consumer cards DO NOT support vGPU
- Only works with NVIDIA datacenter cards (Tesla, A-series)
- Expensive licensing costs
- **NOT APPLICABLE FOR THIS USE CASE**

## Recommended Approach

### Primary Recommendation: Option 2 (Two-GPU Setup)

**If you have or can install a second GPU (even a cheaper one)**:

1. **RTX 3080**: Dedicated to Windows gaming VM
   - Full PCIe passthrough
   - Moonlight/Sunshine server for streaming
   - Maximum gaming performance

2. **Second GPU** (could be older/cheaper like 1060, 1070, or even Intel iGPU): LXC containers
   - AI workloads
   - Jellyfin transcoding
   - Handbrake encoding

This is the cleanest architecture and well-supported.

### Alternative Recommendation: Option 1 (LXC-Only)

**If you only have the single RTX 3080 and want all workloads running**:

1. Use LXC containers for everything
2. Set up gaming container with:
   - Ubuntu/Debian base
   - Steam + Proton/Wine
   - Sunshine server (Moonlight host)
3. Separate containers for AI, Jellyfin, Handbrake
4. All containers share the 3080 via device passthrough

**Caveats**:
- Less tested for gaming
- Some anti-cheat may not work
- Need to test game compatibility

### Fallback: Option 3 (Time-Sharing)

**If you need VM gaming but only have one GPU**:
- Use gaming VM during "gaming hours"
- Switch to LXC mode during the day for AI/media work
- Requires automation scripts

## Hardware Check Needed

Before proceeding, we need to know:

1. **How many GPUs** are in the Puget system?
   - Just the RTX 3080?
   - Any integrated graphics (Intel iGPU)?
   - Any other discrete GPUs?

2. **CPU**: Does it have integrated graphics as a fallback for Proxmox console?

3. **What other nodes** will remain in the cluster after removing the two Pugets?

## Next Steps

1. **Inventory current hardware** - How many GPUs available?
2. **Choose architecture** based on GPU availability
3. **Create detailed implementation guide** for chosen option
4. **Test gaming VM or LXC gaming container** with Moonlight
5. **Configure AI/media containers**
6. **Document and create snapshots/backups**

## Use Case Requirements Analysis

### Gaming (Moonlight Streaming)
- **Need**: Full DirectX/Vulkan support
- **GPU Load**: High during gaming sessions
- **Concurrent Use**: 2 users (two boys) - may need streaming queue or time slots
- **Best Solution**: Windows VM with GPU passthrough OR LXC with Steam/Proton

### AI Workloads
- **Need**: CUDA support
- **GPU Load**: Variable, often batch processing
- **Concurrent Use**: Can share GPU time
- **Best Solution**: LXC container with NVIDIA Container Toolkit

### Jellyfin Transcoding
- **Need**: NVENC/NVDEC hardware acceleration
- **GPU Load**: Low to medium, depends on concurrent streams
- **Concurrent Use**: Limited to 3-5 streams (NVIDIA restriction on consumer cards)
- **Best Solution**: LXC container with NVIDIA drivers

### Handbrake Encoding
- **Need**: NVENC hardware acceleration
- **GPU Load**: High during encoding, but typically batch jobs
- **Concurrent Use**: Can be queued
- **Best Solution**: LXC container with NVIDIA drivers

## NVIDIA Consumer Card Limitations

**Important**: RTX 3080 has artificial limits:
- Maximum 3-5 simultaneous NVENC encode sessions
- This affects Jellyfin (multiple concurrent transcodes) and Handbrake
- Workarounds exist but may violate NVIDIA EULA

## Hardware Inventory Results (pve007)

✅ **Completed** - See `pve007-hardware-inventory.md` for full details

### Key Findings:
- **GPU**: Single NVIDIA GeForce RTX 3080 Ti (GA102)
- **CPU**: AMD Ryzen 9 5900X (12-core/24-thread, NO integrated graphics)
- **RAM**: 64 GB
- **IOMMU**: ✅ Already enabled and configured (Group 33)
- **Current Load**: Running 7 K8s VMs (~30GB RAM)
- **Cluster**: 7 nodes total, pve007 is the only high-performance node

### Critical Constraint:
**Single GPU, No iGPU** - This eliminates the two-GPU approach and makes the choice between:
1. LXC-only (all workloads share GPU)
2. VM gaming with time-sharing (complex switching)

## Remaining Questions

1. Do the boys need **simultaneous** gaming access, or can they time-share one gaming session?
2. What's the priority order: Gaming > AI > Media, or different?
3. What times of day are gaming sessions needed? (helps determine if time-sharing is viable)
4. Are there any specific games that MUST work? (for compatibility testing)

## Resources for Implementation

- [2025 Proxmox PCIe/GPU Passthrough with NVIDIA Tutorial](https://forum.proxmox.com/threads/2025-proxmox-pcie-gpu-passthrough-with-nvidia.169543/)
- [How to Enable GPU Passthrough to LXC Containers](https://www.virtualizationhowto.com/2025/05/how-to-enable-gpu-passthrough-to-lxc-containers-in-proxmox/)
- [GPU Passthrough for Desktop Streaming](https://portegi.es/blog/proxmox-gpu-streaming)
- [LXC NVIDIA Passthrough Discussion](https://forum.proxmox.com/threads/lxc-nvidia-passthrough.131929/)
