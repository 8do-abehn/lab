# GPU Passthrough POC - Progress Report

> **Note**: Historical document. The pve007 referenced here became pve009. See `dual-gpu-p2v-architecture.md` for current setup.

**Date**: 2025-10-23 Evening
**System**: pve007 (AMD Ryzen 9 5900X, RTX 3080 Ti)

## ✅ Completed Today

### 1. Planning & Research
- [x] Researched GPU passthrough options (LXC vs VM)
- [x] Analyzed hardware inventory on pve007
- [x] Created comprehensive POC plan
- [x] Gathered boys' game list (Minecraft, Portal, Half-Life, It Takes Two, Fortnite, Farm Simulator, Paw Patrol)
- [x] Documented game compatibility expectations

### 2. Backup & Safety
- [x] Created backup of pve007 configuration (`/root/backups/pve007-config-backup-20251023-221455.tar.gz`)
- [x] Initiated VM snapshots (running in background)

### 3. NVIDIA Driver Installation (Host)
- [x] Enabled Debian non-free repositories
- [x] Installed Proxmox kernel headers
- [x] Installed build-essential and DKMS
- [x] Downloaded NVIDIA driver 535.183.01 (326MB)
- [x] Installed NVIDIA drivers using runfile installer
- [x] **Verified GPU detection**: RTX 3080 Ti recognized with 12GB VRAM, CUDA 12.2

### 4. LXC Container Setup
- [x] Downloaded Ubuntu 24.04 LXC template
- [x] Created privileged container (ID 500: gaming-poc)
  - 16GB RAM
  - 8 CPU cores
  - 100GB storage
  - Nesting enabled
- [x] Configured GPU device passthrough in `/etc/pve/lxc/500.conf`:
  ```
  lxc.cgroup2.devices.allow: c 195:* rwm
  lxc.cgroup2.devices.allow: c 509:* rwm
  lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
  lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
  lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
  lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file
  lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
  ```
- [x] Started container (currently installing packages)

## ⏳ In Progress

### LXC Container Initialization
- Container is booting and running initial apt update
- Preparing to install NVIDIA drivers inside container

## 📋 Next Steps (Tomorrow/Continuation)

### Immediate (Day 2 Morning)
1. **Install NVIDIA drivers in container**
   - Download same driver version (535.183.01) inside container
   - Install and verify `nvidia-smi` works inside container
   - Confirm GPU access from container

2. **Install Desktop Environment**
   - Install XFCE or minimal DE
   - Install X11/Xorg
   - Configure display

3. **Install Steam & Proton**
   - Add Steam repository
   - Install Steam client
   - Configure Proton/compatibility layer

4. **Test Portal (Proof of Concept)**
   - Download and launch Portal
   - Verify GPU acceleration
   - Measure FPS

### Day 2-3: Testing & Refinement
5. Test other games (Minecraft, It Takes Two, Farm Simulator)
6. Install Sunshine for Moonlight streaming
7. Test streaming to client device
8. Document any issues/solutions

### Day 4-5: Ansible Automation
9. Create Ansible role for gaming node setup
10. Test playbook on pve007
11. Document variables and customization

### Day 6-7: Documentation
12. Create user guide for boys
13. Prepare for deployment to 2 remaining Puget systems

## 💻 System Status

### pve007 Current State
- **Host GPU**: RTX 3080 Ti, NVIDIA Driver 535.183.01, CUDA 12.2
- **LXC 500 (gaming-poc)**: Running, GPU devices mapped
- **K8s VMs**: 7 running (301, 401-406) - 30GB RAM, 20 vCPUs
- **Available Resources**: ~34GB RAM, 14 CPU threads free

### Files Created
- `/root/backups/pve007-config-backup-20251023-221455.tar.gz` - Host config backup
- `/tmp/NVIDIA-Linux-x86_64-535.183.01.run` - NVIDIA installer
- `/etc/pve/lxc/500.conf` - Gaming container config
- `notes/nvidia-3080-gpu-passthrough-planning.md` - Main planning document
- `notes/pve007-hardware-inventory.md` - Hardware details
- `notes/pve007-gpu-architecture-recommendation.md` - Architecture design
- `notes/puget-gaming-poc-plan.md` - POC execution plan
- `notes/poc-progress-2025-10-23.md` - This progress report

## 🎯 POC Success Criteria

### Minimum Viable (Critical)
- [ ] One game runs successfully in LXC
- [ ] Moonlight streaming works from client
- [ ] Setup is documented for reproduction

### Target Goals
- [ ] Portal runs at >60 FPS
- [ ] Minecraft works perfectly
- [ ] It Takes Two co-op functional
- [ ] Ansible playbook created
- [ ] Ready for 2-Puget deployment

### Stretch Goals
- [ ] Fortnite working (anti-cheat challenge)
- [ ] All games tested
- [ ] Full automation complete
- [ ] Performance metrics documented

## 🚧 Known Issues / Considerations

1. **32-bit libraries**: Warning during NVIDIA install (not needed for our use case)
2. **X library path**: Warning about guessing path (normal for server, will resolve with pkg-config in container)
3. **Fortnite anti-cheat**: May require Windows VM if EAC doesn't work in Linux
4. **NVENC limits**: Consumer card limited to 3-5 simultaneous encode streams

## 📝 Notes for Tomorrow

- Container 500 is mid-startup, finish installing wget
- Need to install NVIDIA driver inside container (use same 535.183.01)
- Start with Portal as first test (guaranteed to work)
- Document any driver version mismatches or issues

## 🎮 The End Goal

**After POC proves successful**:
- Deploy to 2 remaining Puget systems (pve008, pve009 presumably)
- Each boy gets dedicated Puget + RTX 3080
- They can play co-op games together (It Takes Two!)
- GPUs available for AI/media workloads when not gaming
- All setup automated via Ansible

---

**Status**: Strong progress! Driver installed, container created with GPU passthrough configured. Ready to continue tomorrow with in-container setup and testing.
