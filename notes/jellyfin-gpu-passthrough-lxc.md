# Jellyfin GPU Passthrough in Proxmox LXC Container

## Overview
This guide documents the process of passing through AMD GPUs to a Jellyfin LXC container on Proxmox for hardware-accelerated transcoding using VAAPI.

## Hardware
- **Host**: Proxmox VE
- **GPUs**: 2x AMD Radeon RX 570 Series (Ellesmere)
- **Container**: Unprivileged LXC running Ubuntu 24.04
- **Container ID**: 3001

## Problem
Jellyfin was using CPU transcoding (100% CPU usage) instead of GPU hardware acceleration. Initial error showed:
```
Device creation failed: -542398533.
Failed to set value 'vaapi=va:,vendor_id=0x8086,driver=iHD'
```

Issue was caused by:
1. Intel media drivers installed instead of AMD drivers
2. No GPU devices passed through to container
3. Container running in LXC without `/dev/dri/` access

## Solution

### 1. Identify GPU Devices on Host

On Proxmox host:
```bash
# Check GPU hardware
lspci | grep -i vga

# Verify DRI devices exist
ls -la /dev/dri/
```

Output should show:
```
/dev/dri/card0       # First GPU
/dev/dri/card1       # Second GPU
/dev/dri/renderD128  # First GPU render node
/dev/dri/renderD129  # Second GPU render node
```

### 2. Check Host Group IDs

```bash
getent group video
getent group render
```

Expected output:
- `video:x:44:root`
- `render:x:104:root`

These GIDs are needed for device passthrough configuration.

### 3. Configure LXC Container for GPU Passthrough

Edit container config on Proxmox host:
```bash
vi /etc/pve/lxc/3001.conf
```

Add these lines after the existing `dev0` line:
```ini
dev1: /dev/dri/card0,gid=44
dev2: /dev/dri/card1,gid=44
dev3: /dev/dri/renderD128,gid=104
dev4: /dev/dri/renderD129,gid=104
```

Where:
- `gid=44` maps to host's `video` group
- `gid=104` maps to host's `render` group

### 4. Restart Container

```bash
pct restart 3001
pct enter 3001
```

Verify devices inside container:
```bash
ls -la /dev/dri/
```

Expected output:
```
crw-rw---- 1 root video 226,   0 card0
crw-rw---- 1 root video 226,   1 card1
crw-rw---- 1 root _ssh  226, 128 renderD128
crw-rw---- 1 root _ssh  226, 129 renderD129
```

Note: `_ssh` is how GID 104 maps inside the unprivileged container.

### 5. Install AMD VAAPI Drivers in Container

Remove Intel drivers (if present):
```bash
apt remove --purge intel-media-va-driver intel-media-va-driver-non-free i965-va-driver
```

Install AMD drivers:
```bash
apt update
apt install mesa-va-drivers vainfo libva2 libva-drm2
```

### 6. Configure User Permissions

Add jellyfin user to required groups:
```bash
usermod -aG video jellyfin
usermod -aG _ssh jellyfin

# Verify
id jellyfin
```

### 7. Test VAAPI

Test as jellyfin user:
```bash
su - jellyfin -c "vainfo --display drm --device /dev/dri/renderD128"
```

Expected output:
```
vainfo: VA-API version: 1.20 (libva 2.12.0)
vainfo: Driver version: Mesa Gallium driver 25.0.7 for AMD Radeon RX 570 Series
vainfo: Supported profile and entrypoints
      VAProfileH264ConstrainedBaseline:    VAEntrypointVLD
      VAProfileH264ConstrainedBaseline:    VAEntrypointEncSlice
      VAProfileH264Main               :    VAEntrypointVLD
      VAProfileH264Main               :    VAEntrypointEncSlice
      VAProfileH264High               :    VAEntrypointVLD
      VAProfileH264High               :    VAEntrypointEncSlice
      VAProfileHEVCMain               :    VAEntrypointVLD
      VAProfileHEVCMain               :    VAEntrypointEncSlice
      VAProfileHEVCMain10             :    VAEntrypointVLD
      ...
```

### 8. Configure Jellyfin

In Jellyfin web UI, go to **Dashboard → Playback → Transcoding**:

**Settings:**
- **Hardware acceleration**: `Video Acceleration API (VAAPI)`
- **VA-API Device**: `/dev/dri/renderD128`
- **Enable hardware decoding for**: Check all supported codecs
  - H264
  - HEVC
  - MPEG2
  - VC1
- **Enable hardware encoding**: ✓ Checked
- **Allow encoding in HEVC format**: ✓ Checked
- **Encoding preset**: `Medium` or `Fast`

**Important**: Leave "Advanced" options empty. Do NOT specify vendor_id or driver parameters.

### 9. Restart Jellyfin

```bash
systemctl restart jellyfin
```

### 10. Monitor GPU Usage

Install monitoring tool:
```bash
apt install radeontop
```

Run while transcoding:
```bash
radeontop
```

You should see GPU usage increase during video transcoding. CPU usage should be minimal.

## Verification

### Check FFmpeg VAAPI Support
```bash
/usr/lib/jellyfin-ffmpeg/ffmpeg -hwaccels
```

Should list `vaapi` in hardware acceleration methods.

### Check Jellyfin Logs
```bash
tail -f /var/log/jellyfin/jellyfin.log
```

Look for successful VAAPI initialization, not errors like:
- ❌ `Device creation failed`
- ❌ `FFmpeg exited with code 134`
- ✓ Lines showing hardware acceleration in use

## Multiple GPU Notes

Jellyfin **cannot use multiple GPUs simultaneously**. You can only configure one device at a time (`/dev/dri/renderD128` or `/dev/dri/renderD129`).

A single RX 570 can typically handle 3-5+ concurrent 1080p transcodes, so one GPU is usually sufficient.

To use the second GPU:
- Switch the VA-API Device to `/dev/dri/renderD129` in Jellyfin settings
- Use the second GPU for other services (Plex, Emby, etc.)

## Troubleshooting

### Container Won't Start After Config Changes
Rollback to snapshot:
```bash
pct rollback 3001 justcuz
pct start 3001
```

### "Failed to open the given device"
- Check user is in correct groups: `id jellyfin`
- Verify device permissions: `ls -la /dev/dri/`
- Restart container: `pct restart 3001`

### CPU Still at 100%
- Verify GPU usage with `radeontop` (should show activity)
- Check Jellyfin logs for VAAPI errors
- Ensure hardware encoding is enabled in Jellyfin settings
- Restart Jellyfin service after config changes

### Wrong Driver Error (Intel/iHD)
- Remove Intel drivers completely
- Install only AMD mesa drivers
- Clear any advanced options in Jellyfin VAAPI config
- Use only device path: `/dev/dri/renderD128`

## References

- [Jellyfin Hardware Acceleration Docs](https://jellyfin.org/docs/general/administration/hardware-acceleration/)
- [Proxmox LXC Device Passthrough](https://pve.proxmox.com/wiki/Linux_Container#_bind_mount_points)
- AMD VAAPI with Mesa: Uses open-source `radeonsi` driver

## Final Configuration

### LXC Config (`/etc/pve/lxc/3001.conf`)
```ini
arch: amd64
cores: 2
dev0: /dev/sr0,gid=24,uid=0
dev1: /dev/dri/card0,gid=44
dev2: /dev/dri/card1,gid=44
dev3: /dev/dri/renderD128,gid=104
dev4: /dev/dri/renderD129,gid=104
features: keyctl=1,nesting=1,fuse=1
hostname: jellyfin
memory: 4096
# ... other settings ...
unprivileged: 1
```

### Installed Packages (Container)
- `mesa-va-drivers` - AMD VAAPI drivers
- `vainfo` - VAAPI info tool
- `libva2` - VA-API runtime library
- `libva-drm2` - VA-API DRM backend
- `radeontop` - AMD GPU monitoring

### User Groups (Container)
```bash
jellyfin : jellyfin video _ssh
```

Where `_ssh` (GID 104) provides access to render nodes.
