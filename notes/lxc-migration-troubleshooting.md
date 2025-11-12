# LXC Migration Troubleshooting - Jellyfin CT 3001

## Problem Summary

Needed to migrate Jellyfin LXC 3001 from pve007 back to pve005. The container had been improperly migrated previously, resulting in a broken configuration with mismatched storage references.

## Initial State

**Container 3001 on pve007 had:**
- Config pointing to non-existent rootfs: `local-lvm:vm-3001-disk-0`
- Actual rootfs on shared storage: `infra_storage:vm-3001-disk-0` (marked as unused0)
- Missing mount point: `temp:subvol-3001-disk-0` (1.2TB media library)
- GPU device references that didn't exist on pve007

## Root Cause

The container was improperly migrated from pve005 to pve007 at some point, which:
1. Left the rootfs on shared storage but updated the config to point to local-lvm (which didn't exist)
2. Removed the mp1 mount point for the media library
3. Added GPU device references that didn't exist on pve007

## Migration Errors Encountered

### Error 1: Storage not available
```
ERROR: migration aborted: storage 'temp' is not available on node 'pve007'
```
**Cause:** Config referenced temp storage (for mp1) which only exists on pve005

### Error 2: Device validation failures
```
Device /dev/dri/renderD129 does not exist
Device /dev/dri/card0 does not exist
```
**Cause:** Any config change triggered validation of ALL devices, which didn't exist on pve007

### Error 3: Missing rootfs
```
ERROR: no such logical volume pve/vm-3001-disk-0
ERROR: found stale volume copy 'local-lvm:vm-3001-disk-0' on node 'pve005'
```
**Cause:** Config pointed to non-existent local-lvm volume instead of actual infra_storage volume

## Solution Steps

### 1. Verify Actual Storage Locations

```bash
# Check what volumes actually exist
lvs | grep 3001
pvesm list local-lvm | grep 3001
pvesm list infra_storage | grep 3001
pvesm list temp | grep 3001
```

**Found:**
- Rootfs: `infra_storage:vm-3001-disk-0` (50GB, shared)
- Media library: `temp:subvol-3001-disk-0` (1.2TB, on pve005)

### 2. Fix the Rootfs Configuration

Manually edit the config to point to the correct storage:

```bash
vi /etc/pve/lxc/3001.conf
```

**Change:**
```
rootfs: local-lvm:vm-3001-disk-0,size=50G
unused0: infra_storage:vm-3001-disk-0
```

**To:**
```
rootfs: infra_storage:vm-3001-disk-0,size=50G
```

### 3. Migrate to pve005

Since rootfs is now on shared storage (infra_storage), migration is simple:

```bash
pct migrate 3001 pve005 --restart 0 --online 0
```

### 4. Restore Mount Points and Devices

After migration to pve005, re-add the missing components:

```bash
# Re-add media library mount point
pct set 3001 --mp1 temp:subvol-3001-disk-0,mp=/mnt/library,backup=1,size=1274G

# Add RX 580 GPU card device
pct set 3001 --dev2 /dev/dri/card1,gid=44

# Add render node for hardware transcoding
pct set 3001 --dev3 /dev/dri/renderD128,gid=104
```

### 5. Start and Verify

```bash
# Start container
pct start 3001

# Verify status
pct status 3001

# Verify mount point
pct exec 3001 -- df -h | grep library

# Verify GPU devices
pct exec 3001 -- ls -la /dev/dri/
```

## Final Configuration

**Storage:**
- Rootfs: `infra_storage:vm-3001-disk-0` (50GB, shared)
- Media: `temp:subvol-3001-disk-0` (1.2TB, mounted at `/mnt/library`)

**GPU Devices:**
- `dev2`: `/dev/dri/card1` (RX 580 card interface)
- `dev3`: `/dev/dri/renderD128` (render node for VAAPI transcoding)

**Network:**
- DHCP on vmbr0
- Tailscale enabled

## Key Lessons

1. **Check actual storage locations before trusting config**
   - Use `pvesm list <storage>` to verify volumes exist
   - Config can reference non-existent volumes

2. **Shared storage simplifies migration**
   - When rootfs is on shared storage, no disk transfer needed
   - Only metadata/config moves between nodes

3. **Device validation blocks config changes**
   - Any `pct set` command validates ALL devices
   - Must remove non-existent devices before making any changes

4. **GPU passthrough requires both card and render node**
   - Card device: `/dev/dri/card*` (interface)
   - Render node: `/dev/dri/renderD*` (compute/transcoding)
   - Check association: `ls -la /sys/class/drm/card*/device/drm/`

5. **Manual config editing is sometimes necessary**
   - Direct editing of `/etc/pve/lxc/*.conf` when CLI tools fail
   - Useful for fixing broken storage references

## Verification Commands

```bash
# Check storage availability
pvesm status

# Check volume locations
pvesm list <storage> | grep <vmid>

# Check GPU devices on host
ls -la /dev/dri/

# Check GPU association
ls -la /sys/class/drm/card*/device/drm/

# Check container config
pct config <vmid>

# Test container access
pct exec <vmid> -- ls -la /mnt/library
pct exec <vmid> -- ls -la /dev/dri/
```

## Related Hardware Notes

**pve005 Hardware:**
- RX 580 GPU installed
- Has 'temp' ZFS storage pool for media
- Shared 'infra_storage' for container rootfs

**pve007 Hardware:**
- Ryzen 9 5900X (12-core, 24-thread)
- 128GB RAM
- No integrated GPU (standard Ryzen, not 'G' series)
- Best suited for CPU-based workloads (AI inference, etc.)

## References

- Proxmox LXC migration: https://pve.proxmox.com/wiki/Linux_Container#pct_migration
- GPU passthrough to LXC: https://pve.proxmox.com/wiki/Linux_Container#_device_pass_through
- VAAPI in Jellyfin: https://jellyfin.org/docs/general/administration/hardware-acceleration/
