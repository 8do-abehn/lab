# PVE007 GPU Passthrough Architecture Recommendation

**Date**: 2025-10-23
**System**: pve007 (AMD Ryzen 9 5900X, RTX 3080 Ti)
**Deadline**: Before Puget workstation return (next week)

## Executive Summary

Based on hardware inventory of pve007, **recommend LXC-only approach** for GPU sharing across gaming, AI, and media workloads. This is the most practical solution given the single-GPU constraint and tight timeline.

## Hardware Constraints Recap

- ✅ Single RTX 3080 Ti (excellent performance)
- ❌ No integrated graphics (no fallback GPU)
- ❌ No second discrete GPU
- ⚠️  Already running 7 K8s VMs (resource constrained)
- ✅ IOMMU already configured (quick start)

## Final Architecture: LXC Multi-Container GPU Sharing

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      PVE007 Host                         │
│            AMD Ryzen 9 5900X, 64GB RAM                   │
│                 NVIDIA Drivers Installed                 │
└─────────────────────────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
┌─────────────────┐ ┌──────────────┐ ┌─────────────────┐
│  Gaming LXC     │ │  AI LXC      │ │ Media LXC       │
│                 │ │              │ │                 │
│ • Ubuntu 24.04  │ │ • Ubuntu     │ │ • Jellyfin      │
│ • Steam         │ │ • PyTorch    │ │ • Handbrake     │
│ • Proton/Wine   │ │ • CUDA       │ │ • NVENC/NVDEC   │
│ • Sunshine      │ │ • Ollama     │ │ • ffmpeg        │
│ • Moonlight SDK │ │              │ │                 │
└─────────────────┘ └──────────────┘ └─────────────────┘
         │                  │                  │
         └──────────────────┼──────────────────┘
                            │
                    GPU Device Passthrough
                   /dev/nvidia0, /dev/nvidiactl,
                   /dev/nvidia-uvm, /dev/nvidia-modeset
                            │
                            ▼
              ┌─────────────────────────────┐
              │   NVIDIA RTX 3080 Ti        │
              │   (Shared across all LXCs)  │
              └─────────────────────────────┘
```

### Container Specifications

#### Gaming Container (LXC 500)
**Purpose**: Gaming for two boys via Moonlight streaming

**Specifications**:
- **OS**: Ubuntu 24.04 LTS (privileged container for now, test unprivileged later)
- **RAM**: 16 GB
- **CPU**: 8 cores
- **Storage**: 100 GB
- **Network**: Bridge to main network

**Software Stack**:
- NVIDIA drivers (matching host version)
- Steam + Proton Experimental
- Wine/Lutris for non-Steam games
- Sunshine (GameStream host for Moonlight)
- X11/Xorg (required for gaming)
- PulseAudio for audio

**GPU Access**: Full CUDA + OpenGL + Vulkan + NVENC

**Usage Pattern**:
- Primary use: After school/evenings/weekends
- Two boys time-share (one plays, one watches stream or waits turn)
- Games stream to their devices via Moonlight

#### AI Workload Container (LXC 501)
**Purpose**: Machine learning and AI tasks

**Specifications**:
- **OS**: Ubuntu 22.04 LTS
- **RAM**: 16 GB
- **CPU**: 8 cores
- **Storage**: 200 GB
- **Network**: Bridge to main network

**Software Stack**:
- NVIDIA drivers + CUDA toolkit
- nvidia-container-toolkit
- Docker (for Ollama, etc.)
- PyTorch / TensorFlow
- Jupyter Lab

**GPU Access**: CUDA compute

**Usage Pattern**:
- Batch processing, can queue jobs
- Primarily daytime use
- Can share GPU time with other containers

#### Media Container (LXC 502)
**Purpose**: Jellyfin transcoding + Handbrake encoding

**Specifications**:
- **OS**: Ubuntu 22.04 LTS
- **RAM**: 8 GB
- **CPU**: 4 cores
- **Storage**: 50 GB (media on shared storage)
- **Network**: Bridge + Tailscale

**Software Stack**:
- Jellyfin (migrate from current LXC 3001 on pve005)
- Handbrake CLI
- ffmpeg with NVENC support
- NVIDIA drivers

**GPU Access**: NVENC/NVDEC hardware acceleration

**Usage Pattern**:
- Jellyfin: 24/7 streaming (limited by 3-5 concurrent streams)
- Handbrake: Batch encoding jobs
- Lower GPU priority than gaming

### Resource Allocation

#### Total Resource Pool (pve007)
- **CPU**: 24 threads
- **RAM**: 64 GB
- **GPU**: RTX 3080 Ti (shared)

#### Allocation Plan
```
Current K8s VMs:      ~20 threads, ~30 GB RAM
Gaming LXC:            8 threads,  16 GB RAM, GPU shared
AI LXC:                8 threads,  16 GB RAM, GPU shared
Media LXC:             4 threads,   8 GB RAM, GPU shared
Proxmox overhead:      2 threads,   4 GB RAM
────────────────────────────────────────────
TOTAL (max):          42 threads,  74 GB RAM (oversubscribed)
```

**Note**: This is an oversubscription model - not all VMs/containers will use max resources simultaneously. Monitor and adjust as needed.

#### Potential Optimization
- Migrate 2-3 K8s workers to pve001-006 to free up resources
- This would provide comfortable headroom for GPU workloads

## Implementation Plan

### Phase 1: Preparation (Day 1)
1. ✅ Hardware inventory complete
2. Backup current pve007 configuration
3. Snapshot all running VMs
4. Install NVIDIA drivers on pve007 host
5. Verify GPU detection and basic functionality

### Phase 2: Gaming Container (Days 2-3)
1. Create LXC 500 (Ubuntu 24.04, privileged)
2. Install NVIDIA drivers in container
3. Configure GPU device passthrough
4. Install Steam + Proton
5. Install Sunshine for game streaming
6. Test with simple game (e.g., Portal 2)
7. Configure Moonlight clients for boys
8. Test streaming to their devices
9. Document any game-specific issues

### Phase 3: AI Container (Day 4)
1. Create LXC 501 (Ubuntu 22.04)
2. Install NVIDIA drivers + CUDA toolkit
3. Install Docker + nvidia-container-toolkit
4. Test with simple CUDA program
5. Install Ollama or other AI tools
6. Verify GPU sharing with gaming container

### Phase 4: Media Container (Day 5)
1. Create LXC 502 (Ubuntu 22.04)
2. Install NVIDIA drivers
3. Install Jellyfin
4. Migrate configuration from LXC 3001 (pve005)
5. Test hardware transcoding
6. Install Handbrake
7. Test encoding with NVENC

### Phase 5: Integration Testing (Day 6)
1. Test all three containers running simultaneously
2. Monitor GPU utilization (`nvidia-smi`)
3. Test gaming while Jellyfin is streaming
4. Test AI workload while gaming
5. Tune resource allocations
6. Document performance metrics

### Phase 6: Documentation & Handoff (Day 7)
1. Create user guide for boys (how to connect via Moonlight)
2. Document GPU sharing behavior
3. Create troubleshooting guide
4. Set up monitoring/alerts
5. Final backup

## Gaming Compatibility Considerations

### Proven to Work (Steam + Proton)
- Most single-player games
- Many multiplayer games
- Native Linux games

### May Have Issues
- Games with kernel-level anti-cheat (EasyAntiCheat, BattlEye)
  - Some work, some don't - requires testing
- Games requiring specific Windows services
- VR games (requires additional passthrough setup)

### Recommended Testing Games
1. **Portal 2** - Simple, well-supported, good test case
2. **Minecraft** - Boys likely play this, works well
3. **Whatever games they actually play** - Test their library

### Fallback Plan
If critical games don't work in LXC:
1. Create Windows 11 VM with GPU passthrough
2. Use VM for incompatible games only
3. Keep LXC for compatible games + other workloads
4. Requires manual GPU switching (stop LXC, start VM)

## GPU Sharing Behavior

### How Multiple Containers Share GPU

**Good News**:
- NVIDIA GPUs naturally support multiple processes
- CUDA contexts can run concurrently
- NVENC/NVDEC have hardware queues

**Limitations**:
- GPU memory is shared (12 GB on 3080 Ti)
- Compute time is time-sliced
- NVENC limited to 3-5 simultaneous sessions
- Gaming takes priority when active (time-sensitive)

### Expected Performance

#### Gaming Only
- 100% GPU utilization for game
- Full NVENC for Sunshine streaming
- Excellent performance (~5% overhead vs bare metal)

#### Gaming + AI
- Gaming gets time slices for frames
- AI workload fits in between frames
- Minimal impact on gaming (<10 FPS loss)
- AI workload slows down (~30-50% throughput)

#### Gaming + Jellyfin
- Gaming uses GPU compute
- Jellyfin uses NVENC (separate hardware)
- Minimal conflict (both can run full speed)
- Limited by 3-5 NVENC sessions

#### All Three Simultaneous
- Workable, but gaming performance may dip
- Monitor with `nvidia-smi`
- May need to limit AI container when gaming active

## Monitoring & Management

### Tools
```bash
# Watch GPU utilization
watch -n 1 nvidia-smi

# Monitor from containers
# In each LXC, run:
nvidia-smi dmon -s pucm

# Check processes using GPU
nvidia-smi pmon

# Detailed GPU memory usage
nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

### Alerts
- Set up Prometheus/Grafana GPU monitoring
- Alert if GPU temperature > 85°C
- Alert if GPU memory > 90% used
- Alert if any container can't access GPU

## Migration Tasks

### Jellyfin Migration (LXC 3001 → LXC 502)
1. Stop Jellyfin on pve005 (LXC 3001)
2. Export configuration and database
3. Create LXC 502 on pve007 with GPU access
4. Import configuration
5. Point to same media storage
6. Test hardware transcoding
7. Update DNS/reverse proxy
8. Decommission old container

### K8s Worker Migration (Optional)
If resources tight, migrate workers:
- k3s-worker-01 → pve002
- k3s-worker-02 → pve003
- Keep master + high-memory workers on pve007

## Risk Mitigation

### Risk: Gaming doesn't work well in LXC
**Mitigation**:
- Test early (Day 2-3)
- Have VM fallback plan
- May need dual approach (LXC + VM)

### Risk: GPU passthrough breaks K8s VMs
**Mitigation**:
- Full backups before starting
- Snapshots of each VM
- LXC doesn't affect VMs (isolated)

### Risk: Performance degradation when all workloads active
**Mitigation**:
- Monitor during testing phase
- Set container CPU/memory limits
- Consider cron-based AI job scheduling
- Game time priority system

### Risk: Timeline too tight
**Mitigation**:
- Focus on gaming first (boys' priority)
- Jellyfin migration can happen after return
- AI workloads lowest priority
- Document as you go for later completion

## Success Criteria

### Must Have (Critical)
- ✅ Gaming works via Moonlight streaming
- ✅ Both boys can play (time-shared or sequential)
- ✅ Stable configuration that survives reboots
- ✅ Basic monitoring in place

### Should Have (Important)
- ✅ Jellyfin with hardware transcoding
- ✅ AI container functional
- ✅ All three can run simultaneously
- ✅ Documentation complete

### Nice to Have (Optional)
- ✅ Automated failover/recovery
- ✅ Advanced monitoring dashboards
- ✅ Optimized game library pre-installed
- ✅ K8s worker migration complete

## Next Steps

**Immediate**: Answer remaining questions
1. Do boys need simultaneous gaming or time-share OK?
2. What games do they play? (for compatibility testing)
3. Priority order of workloads?

**Then**: Begin Phase 1 (Preparation)
- Backup everything
- Install NVIDIA drivers on pve007 host
- Begin gaming container setup

## Alternative Architecture (If LXC Gaming Fails)

### Hybrid: VM Gaming + LXC Media/AI

If gaming compatibility issues arise:

```
Gaming VM (Windows 11)
  └─ Full GPU passthrough
     └─ Used during gaming hours only

Media/AI LXCs
  └─ GPU access when VM is stopped
     └─ Used during non-gaming hours
```

**Requires**:
- Scripts to stop LXCs before starting gaming VM
- Manual or scheduled switching
- More complex, but guaranteed game compatibility

**Consider this only if**: LXC gaming proves incompatible with boys' games

## Resources & Documentation

- Main planning: `nvidia-3080-gpu-passthrough-planning.md`
- Hardware inventory: `pve007-hardware-inventory.md`
- Implementation guides: [Forum tutorials linked in planning doc]
