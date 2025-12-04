# pve007 AMD RX 570 LXC GPU Sharing Setup

## Hardware Overview

**Host**: pve007 (Fresh Proxmox installation)
- **CPU**: AMD Ryzen 9 5900X (12c/24HT)
- **RAM**: 128GB
- **Storage**: 2TB NVMe + 4TB SSD
- **GPUs**: 2x AMD Radeon RX 570 (from pve005)
  - Each card: 4GB or 8GB VRAM
  - Open-source drivers (Mesa/RadeonSI)
  - VAAPI hardware acceleration support

## Architecture Decision

**AMD LXC Sharing** (Recommended for RX 570s):
- Multiple LXC containers can share both GPUs simultaneously
- Open-source Mesa drivers (no proprietary driver conflicts)
- Perfect for: AI workloads, Jellyfin, image generation, compute tasks
- No VM passthrough conflicts (unlike NVIDIA)

**Use Cases**:
1. **AI/ML Workloads** - PyTorch ROCm, TensorFlow ROCm
2. **Jellyfin/Media** - VAAPI hardware transcoding
3. **Image Generation** - Stable Diffusion (via ROCm)
4. **General Compute** - OpenCL workloads

---

## Step 1: Host Configuration

### 1.1 Verify GPUs are Detected

SSH to pve007:
```bash
# Check GPU hardware
lspci | grep -i 'vga\|3d\|display'
# Expected: 2x AMD/ATI Ellesmere [Radeon RX 570]

# Check IOMMU groups
find /sys/kernel/iommu_groups/ -type l | grep -i vga
```

### 1.2 Check DRI Device Nodes

```bash
ls -la /dev/dri/
```

Expected output:
```
crw-rw---- 1 root video 226,   0 card0       # GPU 1
crw-rw---- 1 root video 226,   1 card1       # GPU 2
crw-rw---- 1 root render 226, 128 renderD128 # GPU 1 render node
crw-rw---- 1 root render 226, 129 renderD129 # GPU 2 render node
```

### 1.3 Check Group IDs

```bash
getent group video
getent group render
```

Expected:
- `video:x:44:root`
- `render:x:104:root`

These GIDs are needed for LXC device passthrough.

### 1.4 Install AMD Drivers on Host

```bash
apt update
apt install -y \
  mesa-va-drivers \
  mesa-vulkan-drivers \
  libva-drm2 \
  libva2 \
  vainfo \
  radeontop \
  clinfo

# Test VAAPI on host
vainfo --display drm --device /dev/dri/renderD128
vainfo --display drm --device /dev/dri/renderD129

# Test OpenCL
clinfo
```

You should see:
- VA-API support for H264/HEVC encode/decode
- OpenCL platform detected (Mesa/Clover or ROCm if installed)

---

## Step 2: LXC Container Configuration

### 2.1 Container Config Template

For any LXC container that needs GPU access, add these lines to `/etc/pve/lxc/<CTID>.conf`:

```ini
# Pass through both AMD RX 570 GPUs
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/card1,gid=44
dev2: /dev/dri/renderD128,gid=104
dev3: /dev/dri/renderD129,gid=104

# Additional features for containers
features: fuse=1,nesting=1
```

**Note**: Each LXC can access both GPUs simultaneously. The kernel scheduler handles sharing.

### 2.2 Example Container Setup

```bash
# Create Ubuntu LXC for AI workloads
pct create 5000 \
  local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname ai-workload \
  --memory 32768 \
  --cores 8 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1 \
  --features nesting=1,fuse=1

# Add GPU devices
cat >> /etc/pve/lxc/5000.conf <<EOF
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/card1,gid=44
dev2: /dev/dri/renderD128,gid=104
dev3: /dev/dri/renderD129,gid=104
EOF

# Start container
pct start 5000
```

---

## Step 3: Inside LXC Container Setup

### 3.1 Install AMD Drivers in Container

```bash
# Enter container
pct enter 5000

# Install Mesa drivers and tools
apt update
apt install -y \
  mesa-va-drivers \
  mesa-vulkan-drivers \
  libva-drm2 \
  vainfo \
  radeontop

# Verify device access
ls -la /dev/dri/
```

Expected output:
```
crw-rw---- 1 root video  226,   0 card0
crw-rw---- 1 root video  226,   1 card1
crw-rw---- 1 root _ssh   226, 128 renderD128
crw-rw---- 1 root _ssh   226, 129 renderD129
```

Note: `_ssh` is how GID 104 (render) maps inside unprivileged containers.

### 3.2 Test GPU Access

```bash
# Test VAAPI
vainfo --display drm --device /dev/dri/renderD128
vainfo --display drm --device /dev/dri/renderD129

# Monitor GPU usage
radeontop
```

---

## Step 4: Use Case Specific Configurations

### 4.1 AI/ML Workloads (PyTorch ROCm)

**ROCm Support for RX 570**:
- RX 570 is GCN 4.0 (Polaris/gfx803)
- Officially supported by ROCm 5.x+
- Performance: 30-40% slower than NVIDIA for AI

**Install ROCm in LXC** (Ubuntu 22.04/24.04):

```bash
# Add ROCm repository
apt install -y wget gnupg
wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | apt-key add -
echo "deb [arch=amd64] https://repo.radeon.com/rocm/apt/6.2 jammy main" > /etc/apt/sources.list.d/rocm.list

apt update
apt install -y rocm-hip-sdk rocm-opencl-sdk

# Verify ROCm
/opt/rocm/bin/rocminfo
/opt/rocm/bin/clinfo
```

**Install PyTorch with ROCm**:

```bash
# Create Python virtual environment
apt install -y python3-pip python3-venv
python3 -m venv /opt/pytorch-rocm
source /opt/pytorch-rocm/bin/activate

# Install PyTorch ROCm (check https://pytorch.org for latest)
pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2

# Test PyTorch GPU access
python3 -c "import torch; print(f'ROCm available: {torch.cuda.is_available()}'); print(f'GPU count: {torch.cuda.device_count()}'); print(f'GPU name: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else None}')"
```

**Model Capacity (per RX 570 8GB)**:
- Llama 3.2 3B (q4): ✅ 2-3GB VRAM
- Llama 3.1 8B (q4): ✅ 4-5GB VRAM
- Mistral 7B (q4): ✅ 4-5GB VRAM
- LLaMA 13B (q4): ❌ 8-10GB (too tight)
- Stable Diffusion 1.5: ✅ 3-4GB VRAM
- SDXL: ⚠️ 6-8GB (tight fit)

**With 2x RX 570 (8GB each)**:
- Cannot pool VRAM across cards
- Run different models simultaneously (one per GPU)
- Or use both cards for separate inference requests

### 4.2 Jellyfin Hardware Transcoding

See existing guide: `jellyfin-gpu-passthrough-lxc.md`

Quick config:
```bash
# In Jellyfin container
apt install -y mesa-va-drivers vainfo libva-drm2

# Add jellyfin user to groups
usermod -aG video jellyfin
usermod -aG _ssh jellyfin  # For render group access

# Jellyfin settings:
# Hardware acceleration: VAAPI
# Device: /dev/dri/renderD128 (or renderD129)
```

### 4.3 Stable Diffusion / ComfyUI

**Option 1: ROCm Backend**
```bash
# Install ComfyUI with ROCm
apt install -y git python3-pip python3-venv
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

python3 -m venv venv
source venv/bin/activate
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
pip install -r requirements.txt

# Set GPU
export HSA_OVERRIDE_GFX_VERSION=8.0.3  # For RX 570
export PYTORCH_HIP_ALLOC_CONF=garbage_collection_threshold:0.8

python main.py --listen 0.0.0.0 --port 8188
```

**Option 2: ONNX/DirectML** (Alternative, easier setup):
```bash
pip install onnxruntime diffusers transformers
# Use ONNX optimized models
```

### 4.4 Open WebUI with GPU

If you want to run Open WebUI on pve007:

```bash
# Create LXC for Open WebUI
pct create 4101 \
  local:vztmpl/ubuntu-24.04-standard_24.04-2_amd64.tar.zst \
  --hostname openwebui-pve007 \
  --memory 65536 \
  --cores 12 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --unprivileged 1

# Add GPU devices to /etc/pve/lxc/4101.conf
dev0: /dev/dri/card0,gid=44
dev1: /dev/dri/card1,gid=44
dev2: /dev/dri/renderD128,gid=104
dev3: /dev/dri/renderD129,gid=104

# Inside container, install Ollama with ROCm
pct enter 4101
curl -fsSL https://ollama.com/install.sh | sh

# Set ROCm environment
echo 'export HSA_OVERRIDE_GFX_VERSION=8.0.3' >> /etc/environment
echo 'export HIP_VISIBLE_DEVICES=0' >> /etc/environment

# Install Open WebUI
docker run -d -p 3000:8080 \
  --device=/dev/dri/renderD128 \
  --device=/dev/kfd \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

---

## Step 5: Performance Testing

### 5.1 VAAPI Transcoding Test

```bash
# Download test video
wget http://distribution.bbb3d.renderfarming.net/video/mp4/bbb_sunflower_1080p_60fps_normal.mp4

# Test hardware transcode (H264 → H264)
ffmpeg -hwaccel vaapi -hwaccel_device /dev/dri/renderD128 \
  -i bbb_sunflower_1080p_60fps_normal.mp4 \
  -vf 'format=nv12,hwupload' \
  -c:v h264_vaapi -b:v 2M \
  output.mp4

# Monitor GPU usage in another terminal
radeontop
```

### 5.2 AI Inference Benchmark

```bash
# Using Ollama
ollama pull llama3.2:3b
time ollama run llama3.2:3b "Write a short poem about GPUs"

# Check GPU usage
radeontop
```

### 5.3 Multiple GPU Test

```bash
# Terminal 1: GPU 0
HSA_OVERRIDE_GFX_VERSION=8.0.3 HIP_VISIBLE_DEVICES=0 ollama run llama3.2:3b "Tell me about AI"

# Terminal 2: GPU 1
HSA_OVERRIDE_GFX_VERSION=8.0.3 HIP_VISIBLE_DEVICES=1 ollama run mistral "Tell me about ML"

# Monitor both
radeontop
```

---

## Step 6: Resource Planning for pve007

**Total Resources**:
- 128GB RAM
- 24 threads (12c/24HT)
- 2x RX 570 GPUs

**Suggested LXC Allocation**:

| LXC | Purpose | RAM | Cores | GPU Access |
|-----|---------|-----|-------|------------|
| 5000 | AI/ML Primary | 32GB | 8 | Both GPUs |
| 5001 | Image Gen (SD) | 16GB | 4 | GPU 0 |
| 5002 | Jellyfin | 8GB | 4 | GPU 1 |
| 5003 | Open WebUI | 32GB | 8 | Both GPUs |
| Other | K8s workers, etc | 40GB | Remaining | None |

**Leave headroom**: ~20GB RAM, 4-6 threads for host

---

## Troubleshooting

### GPU Not Visible in Container

```bash
# On host: Check devices exist
ls -la /dev/dri/

# Check container config
cat /etc/pve/lxc/<CTID>.conf | grep dev

# Check permissions
pct enter <CTID>
ls -la /dev/dri/
# Should show video and _ssh groups

# Add user to groups
usermod -aG video <username>
usermod -aG _ssh <username>
```

### ROCm Not Detecting GPU

```bash
# Set GFX version override for RX 570
export HSA_OVERRIDE_GFX_VERSION=8.0.3

# Add to system-wide config
echo 'HSA_OVERRIDE_GFX_VERSION=8.0.3' >> /etc/environment

# Check ROCm detection
/opt/rocm/bin/rocminfo | grep -i "name"
```

### VAAPI Errors

```bash
# Check driver installation
vainfo --display drm --device /dev/dri/renderD128

# Should show:
# - Mesa Gallium driver for AMD Radeon RX 570
# - H264/HEVC encode/decode support

# If errors, reinstall Mesa drivers
apt install --reinstall mesa-va-drivers
```

### Performance Issues

**RX 570 Limitations**:
- GCN 4.0 architecture (older)
- 4-8GB VRAM (model size limited)
- Slower than modern GPUs (RTX 3080 is 3-4x faster)
- Good for: Small models (7B and under), media transcoding
- Not ideal for: Large models (13B+), real-time inference at scale

**If performance is insufficient**:
- Use quantized models (q4, q5)
- Run smaller models (3B-7B range)
- Offload to CPU for larger models
- Consider CPU-only inference for 13B+ models with 128GB RAM

---

## Security Considerations

### Unprivileged Containers

All GPU-enabled LXCs should remain unprivileged for security:
- GID mapping handles device permissions
- No root privileges needed
- Maintains container isolation

### Resource Limits

Add cgroup limits to prevent GPU memory exhaustion:

```ini
# In /etc/pve/lxc/<CTID>.conf
# Limit CPU usage
cpulimit: 8
cpuunits: 1024

# Memory limits already set via memory parameter
```

---

## Monitoring

### Real-time GPU Monitoring

```bash
# Install on host
apt install -y radeontop

# Monitor GPU 0
radeontop -d /sys/class/drm/card0/device

# Monitor GPU 1
radeontop -d /sys/class/drm/card1/device
```

### Prometheus Metrics (Optional)

```bash
# Install AMD GPU exporter
git clone https://github.com/platinasystems/amd_smi_exporter
cd amd_smi_exporter
docker build -t amd-gpu-exporter .
docker run -d -p 9101:9101 \
  --device=/dev/dri \
  amd-gpu-exporter
```

---

## Comparison: RX 570 vs RTX 3080

| Feature | RX 570 (8GB) | RTX 3080 (12GB) |
|---------|--------------|-----------------|
| **VRAM** | 8GB | 12GB |
| **Architecture** | GCN 4.0 (2017) | Ampere (2020) |
| **AI Performance** | Baseline | 3-4x faster |
| **VAAPI Transcode** | ✅ H264/HEVC | ✅ NVENC (faster) |
| **LXC Sharing** | ✅ Easy (Mesa) | ⚠️ Complex (proprietary) |
| **VM Passthrough** | ✅ Works | ✅ Works |
| **Power Draw** | 150W | 320W |
| **Best Use** | Media, small AI | Gaming, large AI |

**Verdict**: RX 570 is perfect for LXC sharing, media workloads, and small AI models. Use pve007 for multi-tenant GPU sharing, keep pve008's 3080s for gaming VMs.

---

## Next Steps

1. ✅ Configure pve007 host with AMD drivers
2. ⬜ Create AI workload LXC (CTID 5000)
3. ⬜ Test ROCm installation and PyTorch
4. ⬜ Run benchmark with Llama 3.2 3B
5. ⬜ Configure Jellyfin migration from pve005 (if needed)
6. ⬜ Set up monitoring and resource limits
7. ⬜ Document final architecture in lab repo

---

## References

- [AMD ROCm Documentation](https://rocm.docs.amd.com/)
- [PyTorch ROCm Installation](https://pytorch.org/get-started/locally/)
- [Mesa VAAPI Support](https://www.freedesktop.org/wiki/Software/vaapi/)
- [Proxmox LXC Device Passthrough](https://pve.proxmox.com/wiki/Linux_Container#_bind_mount_points)
- Previous work: `jellyfin-gpu-passthrough-lxc.md`
