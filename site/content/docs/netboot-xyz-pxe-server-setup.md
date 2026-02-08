---
title: "netboot.xyz PXE Server Setup"
date: 2025-11-05
draft: true
tags: ["proxmox", "gpu-passthrough", "containers", "lxc"]
---


**Date**: 2025-10-26
**Status**: Deployed and Operational
**Purpose**: Network boot server for OS installations, rescue tools, and diagnostics

---

## Overview

Deployed netboot.xyz as a Docker container to provide PXE boot capabilities across the home lab network. Any device on the network can now boot from the network and access 100+ boot options including Linux distributions, rescue tools, and diagnostic utilities.

---

## Architecture

```
Network Clients (PXE Boot)
        ↓
DHCP Server (UXG Router 10.150.10.1)
   - Option 66: TFTP Server = 10.150.10.204
   - Option 67: Boot File = netboot.xyz.efi
        ↓
Docker LXC (10.150.10.204)
   - LXC 101 on pve006
   - Running netboot.xyz container
        ↓
netboot.xyz Container
   - TFTP Server (port 69/UDP)
   - HTTP Server (port 80)
   - Web UI (port 3000)
```

---

## Deployment Details

### Host Information

**Physical Host**: pve006 (10.150.10.46)
**Container**: LXC 101 "docker"
**Container IP**: 10.150.10.204
**Location**: `/root/docker/netboot-xyz/`

### Docker Compose Configuration

**File**: `/root/docker/netboot-xyz/docker-compose.yml`

```yaml
version: "3.8"

services:
  netbootxyz:
    image: ghcr.io/netbootxyz/netbootxyz:latest
    container_name: netbootxyz
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/New_York
      # MENU_VERSION unset = pulls latest (currently 2.0.88)
    volumes:
      - ./config:/config
      - ./assets:/assets      # For custom ISOs/assets
    ports:
      - 3000:3000   # Web UI
      - 69:69/udp   # TFTP
      - 80:80       # HTTP (for boot assets)
    restart: unless-stopped
    networks:
      - netboot

networks:
  netboot:
    driver: bridge
```

### Container Services

**TFTP Server:**
- Port: 69/UDP
- Purpose: Serves PXE boot files (netboot.xyz.efi)
- Root: `/config/menus`

**HTTP Server:**
- Port: 80
- Purpose: Serves boot assets and menu files
- Assets: `/assets` (for local ISOs)

**Web UI:**
- Port: 3000
- URL: http://10.150.10.204:3000
- Purpose: Configuration and menu management

---

## Network Configuration

### DHCP Server (UXG Router)

**Router**: EdgeRouter X SFP (10.150.10.1)
**Network**: `local` (10.150.10.0/24)

**PXE Boot Options Configured:**
```bash
# Commands used to configure:
set service dhcp-server shared-network-name local subnet 10.150.10.0/24 bootfile-server 10.150.10.204
set service dhcp-server shared-network-name local subnet 10.150.10.0/24 bootfile-name netboot.xyz.efi
commit
save
```

**Verification:**
```bash
show service dhcp-server shared-network-name local subnet 10.150.10.0/24
```

Should show:
```
bootfile-name netboot.xyz.efi
bootfile-server 10.150.10.204
```

### Static DHCP Mapping

Docker LXC has static IP reservation:
```
static-mapping docker {
    ip-address 10.150.10.204
    mac-address bc:24:11:50:56:fc
}
```

---

## Available Boot Options

netboot.xyz provides 100+ boot options organized by category:

### Linux Distributions
- Ubuntu (Desktop & Server, all versions)
- Debian
- Fedora / CentOS / Rocky / AlmaLinux
- Arch Linux
- OpenSUSE
- Mint, Pop!_OS, Elementary
- And 50+ more distributions

### Utilities & Tools
- **Clonezilla** - Disk cloning and imaging
- **SystemRescue** - Complete rescue environment
- **GParted Live** - Partition management
- **Memtest86+** - Memory testing
- **Hardware Detection Tool** - System diagnostics
- **DBAN** - Secure disk wiping
- **Trinity Rescue Kit**
- **Ultimate Boot CD utilities**

### Operating System Installers
- Proxmox VE
- ESXi
- Windows PE (with custom configuration)
- FreeBSD / OpenBSD
- pfSense / OPNsense

### Antivirus & Security
- Kaspersky Rescue Disk
- AVG Rescue CD
- Bitdefender Rescue CD
- ESET SysRescue

---

## Usage

### PXE Booting a Client

**1. Enable PXE Boot in BIOS/UEFI:**
- Reboot target machine
- Enter BIOS/UEFI settings (F2, Del, F12, etc.)
- Navigate to Boot Options
- Enable "Network Boot" or "PXE Boot"
- Optionally set as first boot device

**2. Boot from Network:**
- Save BIOS settings and reboot
- Or manually select network boot from boot menu (F12)
- Watch for "Booting from network..." message

**3. netboot.xyz Menu Appears:**
- Colorful menu with multiple categories
- Navigate with arrow keys
- Select desired boot option
- Files download on-demand from internet

### Web UI Management

**Access**: http://10.150.10.204:3000

**Features:**
- **Menus**: Customize boot menu options
- **Local Assets**: Upload and manage custom ISOs
- **Boot Menu Editor**: Create custom menu entries
- **Configuration**: Adjust settings and parameters

---

## Local Assets

Store custom ISOs for offline/fast booting:

**Directory**: `/root/docker/netboot-xyz/assets/`

**Example - Add Clonezilla:**
```bash
# On Docker LXC
cd /root/docker/netboot-xyz/assets/
# Copy ISO file here
# Will be available at http://10.150.10.204/assets/filename.iso
```

**Access in Web UI:**
- Go to http://10.150.10.204:3000
- Click "Local Assets"
- ISOs in `/assets/` will be listed
- Can be added to custom boot menus

---

## Testing

### Test VM on Proxmox

**Create test VM:**
```bash
# On pve006
qm create 999 --name pxe-test --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --boot order=net0 --ostype l26 \
  --bios ovmf --efidisk0 local-lvm:1
qm start 999
```

**Expected Behavior:**
1. VM boots from network
2. DHCP assigns IP from 10.150.10.100-254 range
3. DHCP provides TFTP server (10.150.10.204) and bootfile (netboot.xyz.efi)
4. VM downloads netboot.xyz.efi via TFTP
5. netboot.xyz menu appears
6. User can select boot option

**Cleanup:**
```bash
qm stop 999
qm destroy 999
```

---

## Container Management

### Start/Stop Container

```bash
# On Docker LXC (pve006, LXC 101)
cd /root/docker/netboot-xyz

# Start
docker compose up -d

# Stop
docker compose down

# Restart
docker compose restart

# View logs
docker compose logs -f
```

### Update Container

```bash
cd /root/docker/netboot-xyz

# Pull latest image
docker compose pull

# Restart with new image
docker compose up -d
```

### Update Menu Version

Menu version is set to `latest` for auto-updates. To pin to specific version:

```bash
# Edit docker-compose.yml
nano docker-compose.yml

# Change:
# MENU_VERSION=latest
# To:
# MENU_VERSION=2.0.80  # or desired version

# Restart
docker compose down && docker compose up -d
```

---

## Troubleshooting

### Client Can't PXE Boot

**Check DHCP Configuration:**
```bash
# On UXG router
show service dhcp-server shared-network-name local subnet 10.150.10.0/24

# Should show:
# bootfile-name netboot.xyz.efi
# bootfile-server 10.150.10.204
```

**Check BIOS/UEFI:**
- Network boot enabled?
- UEFI or Legacy mode? (Use netboot.xyz.efi for UEFI, netboot.xyz.kpxe for Legacy)
- Secure Boot disabled? (May block PXE boot)

**Check Network:**
- Client connected to correct VLAN (10.150.10.0/24)?
- Network cable working?
- Switch port configured correctly?

### TFTP Timeout

**Verify Container Running:**
```bash
ssh root@10.150.10.46
pct exec 101 -- docker ps --filter name=netbootxyz
```

Should show status "healthy"

**Check TFTP Port:**
```bash
pct exec 101 -- netstat -tulpn | grep 69
```

**Check Firewall:**
- Port 69/UDP allowed?
- No firewall rules blocking TFTP?

**Check Logs:**
```bash
pct exec 101 -- docker logs netbootxyz --tail 50
```

Look for TFTP transfer messages

### Boot Options Fail to Load

**Symptoms**: Menu loads but distributions fail with "No such file or directory"

**Cause**: Boot options download files from internet on-demand

**Solutions:**

1. **Check Internet Connectivity:**
   ```bash
   # From container
   docker exec netbootxyz ping -c 3 8.8.8.8
   docker exec netbootxyz ping -c 3 github.com
   ```

2. **Use Local Assets:**
   - Download ISOs manually
   - Place in `/root/docker/netboot-xyz/assets/`
   - Configure custom menu entries via Web UI

3. **Update Menu:**
   - Menus update regularly, old versions may have broken links
   - Set `MENU_VERSION=latest` in docker-compose.yml
   - Restart container

4. **Try Different Options:**
   - Some distributions more reliable than others
   - SystemRescue, Memtest86+ usually very stable
   - Clonezilla reliable for rescue work

### Web UI Not Accessible

**Check Container Status:**
```bash
pct exec 101 -- docker ps --filter name=netbootxyz
```

**Check Port 3000:**
```bash
curl -I http://10.150.10.204:3000
```

**Check from Another Host:**
```bash
curl -I http://10.150.10.204:3000
```

**Verify No Port Conflicts:**
```bash
pct exec 101 -- netstat -tlpn | grep 3000
```

---

## Maintenance

### Regular Tasks

**Update Container Monthly:**
```bash
cd /root/docker/netboot-xyz
docker compose pull
docker compose up -d
```

**Check Disk Usage:**
```bash
# Local assets can grow large
du -sh /root/docker/netboot-xyz/assets/
```

**Review Logs:**
```bash
docker compose logs --tail 100
```

### Backup Configuration

**Configuration Location:**
- Docker Compose: `/root/docker/netboot-xyz/docker-compose.yml`
- Container Config: `/root/docker/netboot-xyz/config/`
- Local Assets: `/root/docker/netboot-xyz/assets/`

**Backup Commands:**
```bash
# Backup entire directory
cd /root/docker
tar -czf netboot-xyz-backup-$(date +%Y%m%d).tar.gz netboot-xyz/

# Backup just config
tar -czf netboot-xyz-config-$(date +%Y%m%d).tar.gz netboot-xyz/config/
```

---

## Access Points Summary

| Service | URL/Address | Port | Purpose |
|---------|-------------|------|---------|
| Web UI | http://10.150.10.204:3000 | 3000/TCP | Configuration & Management |
| TFTP | 10.150.10.204 | 69/UDP | PXE Boot Files |
| HTTP | http://10.150.10.204 | 80/TCP | Boot Assets |
| Docker Host | 10.150.10.204 (LXC 101) | - | Container Host |

---

## Use Cases

### OS Installation
- Boot new hardware without USB/DVD
- Install Proxmox, ESXi, Linux, etc.
- Network-based deployment

### Rescue & Recovery
- SystemRescue for emergency repairs
- GParted for partition work
- Clonezilla for disk imaging/recovery
- Password reset tools

### Diagnostics
- Memtest86+ for RAM testing
- Hardware detection tools
- Network diagnostics
- Disk testing utilities

### P2V Migration
- Boot Clonezilla from network
- Clone physical disks
- Restore to VMs
- (Note: USB boot preferred for large transfers due to speed)

---

## Known Limitations

1. **Internet Required**: Most boot options download files on-demand
   - **Workaround**: Use local assets for offline booting

2. **UEFI vs Legacy**: Different bootfiles needed
   - Current config: UEFI only (netboot.xyz.efi)
   - For Legacy BIOS: Change bootfile-name to netboot.xyz.kpxe

3. **Network Speed**: Large ISOs download slowly over network
   - SystemRescue: ~800MB
   - Ubuntu Desktop: ~3-4GB
   - **Workaround**: Use local assets for frequently used ISOs

4. **Secure Boot**: May block network boot
   - **Workaround**: Disable Secure Boot in UEFI

---

## Future Enhancements

### Planned Improvements

1. **Dual Boot Support** (UEFI + Legacy)
   - Configure conditional bootfile based on client mode
   - Requires advanced DHCP configuration

2. **Local Mirror**
   - Host frequently-used ISOs locally
   - Faster boot times
   - Offline capability

3. **Custom Menus**
   - Add lab-specific tools
   - Proxmox installers
   - Custom rescue environments

4. **High Availability**
   - Run on multiple hosts
   - DHCP failover configuration

---

## Related Documentation

- **Docker Host**: LXC 101 on pve006
- **Network Config**: UXG Router DHCP configuration
- **Clonezilla P2V**: `clonezilla-p2v-clone-instructions.md`
- **P2V Architecture**: `dual-gpu-p2v-architecture.md`

---

## References

- netboot.xyz Official: https://netboot.xyz/
- netboot.xyz Docker: https://hub.docker.com/r/netbootxyz/netbootxyz
- iPXE Documentation: https://ipxe.org/
- GitHub Repository: https://github.com/netbootxyz/netboot.xyz

---

## Change Log

**2025-10-26**: Initial deployment
- Deployed netboot.xyz container on pve006 Docker LXC
- Configured UXG DHCP for PXE boot (10.150.10.0/24 network)
- Set MENU_VERSION=latest for auto-updates
- Tested with VM 999 - successful PXE boot
- Web UI accessible at http://10.150.10.204:3000
- TFTP and HTTP services operational
