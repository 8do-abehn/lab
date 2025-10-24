# Puget Gaming System - Proof of Concept Plan

**Date**: 2025-10-23
**Timeline**: This week (before workstation return)
**Goal**: Prove GPU passthrough gaming works, then replicate to 2 remaining Puget systems

## The Strategy

### Current Situation
- **Returning**: 1 Puget workstation (pve007) with RTX 3080 Ti - due next week
- **Keeping**: 2 other Puget workstations with RTX 3080s
- **Need**: Gaming solution for two boys via Moonlight streaming

### The Plan
1. **Week 1 (This Week)**: Use pve007 as proof-of-concept
   - Test GPU passthrough gaming (LXC or VM)
   - Prove Moonlight streaming works
   - Document the setup
   - Create Ansible playbook for automation

2. **Week 2 (After Return)**: Deploy to remaining 2 Puget systems
   - Use Ansible playbook to set up both systems
   - Each boy gets dedicated Puget + RTX 3080
   - Both can game simultaneously
   - Systems remain in Proxmox cluster

### Benefits of This Approach
- ✅ Each boy gets **dedicated** RTX 3080 (no sharing/conflicts)
- ✅ Both can play **simultaneously** (different games, different systems)
- ✅ **2 more nodes** remain in Proxmox cluster (don't lose compute)
- ✅ **2 more GPUs** available for AI/Jellyfin/k8s when not gaming
- ✅ **Reproducible** setup via Ansible (consistency, easy maintenance)
- ✅ Future-proof: Easy to rebuild or add more systems

## Proof-of-Concept Scope

### Primary Goal
**Prove**: Gaming via GPU passthrough + Moonlight streaming works reliably

### Test System
- **Node**: pve007 (AMD Ryzen 9 5900X, RTX 3080 Ti, 64GB RAM)
- **Method**: LXC container (preferred) OR VM (fallback)
- **Test Window**: 3-5 days

### Success Criteria
- ✅ Gaming container/VM successfully uses GPU
- ✅ Games launch and run at good framerates
- ✅ Moonlight streaming works from client device
- ✅ Acceptable latency/quality for gaming
- ✅ System stable after reboot
- ✅ Setup documented and automated via Ansible

### Out of Scope for POC
- ❌ Multi-workload GPU sharing (not needed - dedicated systems)
- ❌ AI workload testing (different goal, test later)
- ❌ Production Jellyfin setup (can add after gaming proven)
- ❌ Extensive game compatibility testing (test 2-3 games max)

## Implementation Timeline

### Day 1: Preparation & Planning
- [x] Hardware inventory
- [x] Research and architecture
- [ ] Get list of games boys play (for compatibility check)
- [ ] Backup pve007 configuration
- [ ] Snapshot all VMs on pve007
- [ ] Install NVIDIA drivers on pve007 host
- [ ] Verify `nvidia-smi` works

### Day 2: LXC Gaming Container Attempt
- [ ] Create privileged LXC container (Ubuntu 24.04)
- [ ] Configure GPU device passthrough to container
- [ ] Install NVIDIA drivers in container
- [ ] Verify GPU access with `nvidia-smi`
- [ ] Install basic desktop environment (XFCE or similar)
- [ ] Install Steam
- [ ] Test launching Steam

### Day 3: Gaming & Streaming Setup
- [ ] Install Sunshine (GameStream host)
- [ ] Configure Sunshine for streaming
- [ ] Test with simple game (Portal 2 or similar)
- [ ] Set up Moonlight client on test device
- [ ] Test streaming quality and latency
- [ ] Document any issues

**Decision Point**: If LXC works, continue. If not, pivot to VM.

### Day 4: Testing & Refinement
- [ ] Test 2-3 games boys actually play
- [ ] Measure performance (FPS, latency, quality)
- [ ] Test container/VM restart/reboot
- [ ] Optimize settings if needed
- [ ] Document the working configuration

### Day 5: Ansible Automation
- [ ] Create Ansible role for gaming setup
- [ ] Automate:
  - NVIDIA driver installation (host + container/VM)
  - Container/VM creation and configuration
  - GPU device passthrough
  - Gaming software installation (Steam, Sunshine)
  - Network and storage configuration
- [ ] Test playbook on pve007 from scratch
- [ ] Document variables and customization

### Day 6-7: Documentation & Preparation
- [ ] Create user guide for boys
- [ ] Document troubleshooting steps
- [ ] Prepare deployment plan for 2 remaining Pugets
- [ ] Identify any hardware differences between systems
- [ ] Create inventory for Ansible (2 Puget systems)

## Technical Approach

### Option A: LXC Container (Preferred)

**Why LXC**:
- Lower overhead
- Easier to manage
- Simpler resource allocation
- Better for multiple workloads later

**Setup**:
```yaml
Container: LXC (privileged)
OS: Ubuntu 24.04 LTS
RAM: 16 GB
CPU: 8 cores
Storage: 100 GB
GPU: Full passthrough via device mapping

Software:
- NVIDIA drivers (match host version)
- X11/Xorg
- Desktop environment (XFCE)
- Steam + Proton
- Sunshine (GameStream)
- PulseAudio
```

**Device Passthrough**:
```bash
# In container config (/etc/pve/lxc/XXX.conf):
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 509:* rwm
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
```

### Option B: VM with GPU Passthrough (Fallback)

**When to use**:
- If LXC gaming compatibility fails
- If boys need Windows-specific games
- If anti-cheat requires Windows

**Setup**:
```yaml
VM: Windows 11 Pro
RAM: 16 GB
CPU: 8 cores (host CPU type)
Storage: 150 GB
GPU: PCIe passthrough
Audio: GPU audio + virtual audio

Software:
- NVIDIA drivers
- Steam
- Sunshine or Parsec
- VirtIO drivers for performance
```

**PCIe Passthrough**:
```bash
# Host changes:
# /etc/modprobe.d/vfio.conf
options vfio-pci ids=10de:2208,10de:1aef

# VM config:
hostpci0: 0000:3e:00,pcie=1,x-vga=1
```

## Ansible Playbook Structure

### Proposed Role Structure
```
ansible/roles/proxmox-gaming-node/
├── defaults/
│   └── main.yml          # Default variables
├── tasks/
│   ├── main.yml          # Main task orchestration
│   ├── host-prep.yml     # Install NVIDIA drivers on host
│   ├── lxc-create.yml    # Create and configure LXC
│   ├── lxc-gpu.yml       # Configure GPU passthrough
│   ├── gaming-software.yml # Install Steam, Sunshine, etc.
│   └── vm-create.yml     # Alternative: VM setup
├── templates/
│   ├── lxc.conf.j2       # LXC configuration template
│   ├── sunshine.conf.j2  # Sunshine configuration
│   └── sources.list.j2   # APT sources if needed
├── files/
│   └── scripts/          # Helper scripts
├── handlers/
│   └── main.yml          # Restart services, etc.
└── README.md
```

### Key Variables
```yaml
# Gaming node configuration
gaming_container_id: 500
gaming_container_memory: 16384  # MB
gaming_container_cores: 8
gaming_container_storage: 100   # GB

# GPU configuration
gpu_pci_id: "0000:3e:00"
nvidia_driver_version: "535"    # Match across systems

# User configuration
gaming_user: "gamer"
gaming_password: "{{ vault_gaming_password }}"

# Network
gaming_container_ip: "dhcp"     # Or static IP
gaming_bridge: "vmbr0"

# Software versions
sunshine_version: "latest"
steam_install: true
```

### Playbook Example
```yaml
---
- name: Configure Proxmox Gaming Node
  hosts: gaming_nodes
  become: yes
  roles:
    - proxmox-gaming-node

  vars:
    gaming_container_id: "{{ puget_lxc_id }}"
    gaming_user: "{{ boy_name }}"
    # Other vars from inventory
```

### Inventory for Final Deployment
```yaml
# inventory/gaming.yml
all:
  children:
    gaming_nodes:
      hosts:
        puget-01:
          ansible_host: pve008  # Or whatever they're named
          puget_lxc_id: 500
          boy_name: "boy1"
          gaming_container_ip: "192.168.1.50"

        puget-02:
          ansible_host: pve009
          puget_lxc_id: 501
          boy_name: "boy2"
          gaming_container_ip: "192.168.1.51"
```

## Testing Checklist

### Initial GPU Passthrough Test
- [ ] Host recognizes GPU (`lspci | grep NVIDIA`)
- [ ] NVIDIA drivers load on host (`nvidia-smi`)
- [ ] Container/VM sees GPU (`nvidia-smi` inside container/VM)
- [ ] CUDA test passes
- [ ] OpenGL test passes
- [ ] Vulkan test passes

### Gaming Tests
- [ ] Steam launches
- [ ] Steam can download games
- [ ] Test Game 1: _________________ (simple game)
- [ ] Test Game 2: _________________ (boy's favorite)
- [ ] Test Game 3: _________________ (multiplayer/online)
- [ ] Frame rates acceptable (>60 FPS on medium/high)
- [ ] No artifacts or glitches
- [ ] Audio works

### Streaming Tests
- [ ] Sunshine server starts
- [ ] Sunshine accessible on network
- [ ] Moonlight client connects
- [ ] Game streams with good quality
- [ ] Latency acceptable (<20ms on LAN)
- [ ] Input lag acceptable
- [ ] Can play game via stream
- [ ] Multiple stream quality settings work

### Stability Tests
- [ ] Container/VM survives restart
- [ ] Container/VM survives host reboot
- [ ] GPU re-attaches after restart
- [ ] Steam auto-starts (if desired)
- [ ] Sunshine auto-starts
- [ ] No memory leaks over 24hr test

## Hardware Inventory Needed

### For the 2 Remaining Puget Systems

**Information to collect**:
- [ ] Hostname/IP of each system
- [ ] GPU model (RTX 3080 or 3080 Ti?)
- [ ] CPU model
- [ ] RAM amount
- [ ] Current Proxmox node names
- [ ] Currently running workloads (need to migrate?)
- [ ] Network configuration
- [ ] Storage configuration
- [ ] Any differences from pve007

### Games to Test

**Boys' Game List** (confirmed):
- [x] **Minecraft** - EASY: Native Linux, Java edition works perfectly
- [x] **Portal franchise** - EASY: Native Linux support (Valve)
- [x] **Half-Life franchise** - EASY: Native Linux support (Valve)
- [x] **It Takes Two** - MEDIUM: Co-op game (they play together!), good Proton support
- [x] **Farm Simulator** - MEDIUM: Works well with Proton
- [x] **Paw Patrol** - MEDIUM: Should work, depends on version
- [x] **Fortnite** - HARD: Easy Anti-Cheat, problematic on Linux
- [x] **Roblox** (future want) - HARD: Requires wine/compatibility layers

**Testing Priority**:
1. Portal (easiest, guaranteed to work - perfect first test)
2. Minecraft (must-have, easy)
3. It Takes Two (co-op favorite, good Proton test)
4. Farm Simulator (Proton test)
5. Fortnite (hardest, anti-cheat challenge)

**Compatibility Assessment**:

✅ **Will Definitely Work (LXC or VM)**:
- Portal series - Native Linux, perfect
- Half-Life series - Native Linux, perfect
- Minecraft Java Edition - Native Linux, flawless

⚠️ **Should Work (via Proton)**:
- It Takes Two - ProtonDB: Gold rating, works great (important: co-op game they play together!)
- Farm Simulator - ProtonDB reports good compatibility
- Paw Patrol games - Most work via Proton

❌ **May Require Windows VM**:
- Fortnite - Easy Anti-Cheat can block Linux (though some support exists)
- Roblox - Tricky on Linux, wine required, may need VM

**Strategy**:
- Start with LXC + Steam + Proton
- If Fortnite doesn't work, may need Windows VM as fallback
- Most games (including It Takes Two co-op) will work great in LXC!
- Note: For "It Takes Two" co-op, both boys need access - perfect use case for 2 separate Puget systems!

## Decision Tree

```
Start POC
    │
    ├─> Install NVIDIA drivers on host
    │   ├─> Success → Continue
    │   └─> Fail → Debug driver installation
    │
    ├─> Create LXC container
    │   ├─> Success → Continue
    │   └─> Fail → Try VM instead
    │
    ├─> Passthrough GPU to LXC
    │   ├─> Success → Continue with LXC
    │   └─> Fail → Pivot to VM approach
    │
    ├─> Install Steam & test game
    │   ├─> Works well → LXC is the solution
    │   └─> Issues → Try VM
    │
    ├─> Install Sunshine & test streaming
    │   ├─> Works well → Success!
    │   └─> Issues → Debug streaming config
    │
    └─> Create Ansible playbook → Deploy to 2 Pugets
```

## Risk Mitigation

### Risk: Gaming doesn't work in LXC
**Mitigation**: VM fallback ready, proven to work

### Risk: Specific games have anti-cheat issues
**Mitigation**:
- Test boys' actual games
- May need Windows VM for some games
- Most games work fine

### Risk: Moonlight streaming has too much latency
**Mitigation**:
- Test on local network first
- Optimize Sunshine settings
- Alternative: Parsec

### Risk: Timeline too tight (return deadline)
**Mitigation**:
- Focus only on proof-of-concept
- Don't perfect everything
- Good enough > perfect
- Can refine after proving it works

### Risk: Can't finish Ansible playbook in time
**Mitigation**:
- Manual documentation acceptable for POC
- Ansible can be created after return
- Use pve007 manual setup as reference

## Success Metrics

### Minimum Viable POC
- ✅ One game runs successfully
- ✅ Moonlight streaming works
- ✅ Setup is reproducible (documented or automated)
- ✅ Proves the concept for final deployment

### Ideal Outcome
- ✅ Multiple games tested and working
- ✅ Great streaming quality and latency
- ✅ Full Ansible playbook ready
- ✅ Boys tested and approved
- ✅ Ready to deploy to 2 Pugets immediately

## Next Actions

**Immediate (Today)**:
1. Ask boys what games they play
2. Backup pve007
3. Install NVIDIA drivers on pve007 host
4. Start Day 2 tasks (create gaming container)

**This Week**:
- Follow day-by-day plan
- Document everything
- Start Ansible role

**After Return**:
- Deploy to 2 remaining Puget systems
- Each boy gets their own system
- Monitor and refine

## Questions for Boys

Before testing, find out:
1. What games do you play most?
2. Do you play together or separately?
3. What devices do you use for Moonlight? (tablets, laptops, phones?)
4. Any games that are "must work"?
5. How often do you game? (helps with power management)

## Future Enhancements (Post-POC)

Once gaming is proven:
- Add AI workload containers (when not gaming)
- Add Jellyfin with GPU transcoding
- Set up automated game library sync
- Add monitoring for GPU usage
- Power management (shut down when idle)
- Backup/snapshot automation
- Game save backup/sync

## Documentation Deliverables

1. **Technical Setup Guide**: Step-by-step for reproducing setup
2. **Ansible Playbook**: Automated deployment
3. **User Guide**: How boys connect and play
4. **Troubleshooting Guide**: Common issues and fixes
5. **Performance Metrics**: FPS, latency measurements
6. **Game Compatibility List**: What works, what doesn't

---

**Status**: Planning complete, ready to begin Day 1 tasks
**Timeline**: 5-7 days to POC completion
**Next**: Install NVIDIA drivers on pve007 and begin LXC testing
