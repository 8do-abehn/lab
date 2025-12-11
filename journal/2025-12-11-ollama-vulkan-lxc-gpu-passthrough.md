# Journal Entry - 2025-12-11

## Ollama Vulkan GPU Passthrough in LXC Container

Successfully configured Ollama to use dual AMD RX 570 GPUs via **Vulkan** in an unprivileged LXC container on pve007. This enables GPU-accelerated LLM inference for Open WebUI.

## Problem

Ollama in LXC container 4100 was running CPU-only inference despite GPU device passthrough being configured. Logs showed:
```
"total vram"="0 B"
entering low vram mode
```

## Root Cause

Multiple issues:
1. Missing `/dev/kfd` device (required for ROCm/Vulkan GPU access)
2. Missing `LD_LIBRARY_PATH` for Ollama's bundled GPU libraries
3. Ollama user not in correct group to access render devices (GID 104 maps to `postdrop` inside container)

## Solution

### 1. LXC Device Passthrough

Added to `/etc/pve/lxc/4100.conf`:
```ini
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/card1,gid=44
dev2: /dev/dri/renderD128,gid=104
dev3: /dev/dri/renderD129,gid=104
dev4: /dev/kfd,gid=104
```

The `/dev/kfd` device is **critical** - required for both ROCm and Vulkan GPU compute access.

### 2. Install Ollama

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

This installs Ollama with CUDA, ROCm, and Vulkan libraries.

### 3. Install Vulkan tools (for verification)

```bash
apt install -y vulkan-tools rocminfo
```

Verify GPUs are detected:
```bash
vulkaninfo --summary | grep -i radeon
rocminfo | grep -i radeon
```

### 4. Configure Ollama systemd service

Create override file `/etc/systemd/system/ollama.service.d/override.conf`:
```ini
[Service]
Environment=OLLAMA_VULKAN=1
Environment=LD_LIBRARY_PATH=/usr/lib/ollama:/usr/lib/ollama/vulkan
Environment=HSA_OVERRIDE_GFX_VERSION=8.0.3
```

The `LD_LIBRARY_PATH` is **critical** - without it, Ollama's Vulkan library can't find `libggml-base.so`.

### 5. Add ollama user to postdrop group

Inside the container, GID 104 (render group from host) maps to `postdrop`. The ollama user needs access:

```bash
usermod -aG postdrop ollama
```

This was the **final missing piece** - without this, the ollama service user couldn't access the render devices.

### 6. Reload and restart

```bash
systemctl daemon-reload
systemctl restart ollama
```

## Verification

### Check Ollama sees GPU VRAM

```bash
journalctl -u ollama | grep -i 'vram\|vulkan'
```

Should show:
```
"total vram"="8.0 GiB"
library=Vulkan ... "AMD Radeon RX 570 Series (RADV POLARIS10)" ... total="4.0 GiB"
```

### Monitor GPU usage on host

```bash
# Simple loop
while true; do
  echo "GPU0: $(cat /sys/class/drm/card0/device/gpu_busy_percent)%"
  echo "GPU1: $(cat /sys/class/drm/card1/device/gpu_busy_percent)%"
  sleep 1
done

```

Run a query and watch GPU % spike.

## Final Configuration Summary

### LXC Config (`/etc/pve/lxc/4100.conf`)
```ini
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/card1,gid=44
dev2: /dev/dri/renderD128,gid=104
dev3: /dev/dri/renderD129,gid=104
dev4: /dev/kfd,gid=104
```

### Ollama systemd override (`/etc/systemd/system/ollama.service.d/override.conf`)
```ini
[Service]
Environment=OLLAMA_VULKAN=1
Environment=LD_LIBRARY_PATH=/usr/lib/ollama:/usr/lib/ollama/vulkan
Environment=HSA_OVERRIDE_GFX_VERSION=8.0.3
```

### User permissions
```bash
usermod -aG postdrop ollama
```

## Hardware

- **Host**: pve007 (AMD Ryzen 9 5900X, 128GB RAM)
- **GPUs**: 2x AMD Radeon RX 570 (4GB each = 8GB total)
- **Container**: LXC 4100 (Debian 13/trixie, unprivileged)
- **Ollama**: 0.13.2

## Troubleshooting

### "total vram"="0 B"
1. Check `/dev/kfd` is passed through
2. Check `LD_LIBRARY_PATH` is set in systemd override
3. Check ollama user is in `postdrop` group (or whatever GID 104 maps to)
4. Run manually as root to verify GPU detection works at all

### Works as root but not as service
- Almost always a permissions issue
- Check `id ollama` and compare groups to device ownership in `ls -la /dev/dri/ /dev/kfd`

### ROCm crashes but Vulkan works
- Use `OLLAMA_VULKAN=1` instead of ROCm
- Vulkan is simpler and works well for RX 570

## Related Documentation

- `notes/pve007-amd-rx570-lxc-setup.md` - General RX 570 LXC architecture
- `notes/lxc-migration-troubleshooting.md` - LXC migration tips

## Lessons Learned

1. **`/dev/kfd` is required for GPU compute** - both ROCm and Vulkan need it
2. **`LD_LIBRARY_PATH` must be set** - Ollama's bundled libs need to find each other
3. **Check user group permissions** - GID 104 maps to `postdrop` in this container, not `render`
4. **Vulkan is easier than ROCm** - for RX 570, Vulkan "just works" once permissions are right
5. **Test manually as root first** - isolates permission issues from config issues
