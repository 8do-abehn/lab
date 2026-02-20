---
title: "Replacing a Discrete GPU with Intel iGPU for Jellyfin Transcoding"
date: 2025-11-30
draft: false
tags: ["proxmox", "gpu-passthrough", "jellyfin", "media-server", "lxc"]
description: "Migrating Jellyfin from an AMD RX 570 to Intel HD 630 iGPU — 90% less power, same transcoding performance."
---

I migrated Jellyfin from an AMD RX 570 to the Intel HD Graphics 630 integrated into the host CPU. The result: 4 simultaneous HEVC transcodes at ~10% CPU each, with a ~105-135W power reduction.

## Why Switch

The AMD RX 570 was overkill for transcoding. It pulled 50-70W at idle and 120-150W under load — running 24/7 in a media server that mostly handles a few streams at a time. The Intel iGPU built into the i5-7500 has Quick Sync Video, which is purpose-built for exactly this workload.

## Hardware Changes

Shut down the host, physically removed the RX 570, and enabled the iGPU in BIOS under Advanced > Graphics > "Internal Graphics."

After reboot, verified detection:

```bash
lspci | grep VGA
# 00:02.0 VGA compatible controller: Intel Corporation HD Graphics 630 (rev 04)

ls -la /dev/dri/
# crw-rw---- 1 root video  226,   1 card1
# crw-rw---- 1 root render 226, 128 renderD128
```

## LXC Configuration

The Jellyfin container already had GPU passthrough configured. The LXC config passes both device nodes with the correct group IDs:

```ini
dev2: /dev/dri/card1,gid=44
dev3: /dev/dri/renderD128,gid=104
```

The Intel VAAPI driver (`i965-va-driver`) was already installed in the container. Verified with `vainfo`:

```bash
vainfo
# Driver: Intel i965 driver for Intel(R) Kaby Lake - 2.4.1
# Supports: H.264, HEVC, VP9 encode/decode
```

## Jellyfin Settings

In the Jellyfin encoding config, the key setting is using **VAAPI** — not QSV. On Linux, QSV uses the VAAPI backend anyway, so VAAPI is the right choice for Intel iGPUs:

```xml
<HardwareAccelerationType>vaapi</HardwareAccelerationType>
<VaapiDevice>/dev/dri/renderD128</VaapiDevice>
```

## Performance Results

Tested with 4 simultaneous transcodes, all requiring HEVC encoding with resolution scaling. All ffmpeg processes showed hardware acceleration active (`hevc_vaapi`):

| Metric | RX 570 | Intel HD 630 |
|--------|--------|--------------|
| Idle power | 50-70W | ~15W |
| Transcoding power | 120-150W | 15-20W |
| CPU per stream | N/A | ~10% |
| 4-stream load avg | N/A | 2.90 |
| Memory usage | N/A | 1.4 GB / 4 GB |

The I/O wait was 83% during the test — the bottleneck was disk reads, not encoding. The iGPU had headroom to spare.

**Estimated annual savings:** ~920-1,180 kWh (~$100-150/year at $0.11/kWh), plus a cooler, quieter system.

## VAAPI vs QSV on Linux

This tripped me up initially. Intel offers two APIs:

- **VAAPI**: Native Linux video acceleration API
- **QSV (Quick Sync Video)**: Intel's proprietary API

On Linux, QSV uses the VAAPI backend under the hood. Use VAAPI directly — it's simpler and avoids an unnecessary abstraction layer.

There are also two driver options for the HD 630:

- **i965**: Older, stable driver for Gen 4-9.5 Intel GPUs
- **iHD**: Newer Intel Media Driver for Gen 8+

Both work. The ffmpeg processes chose iHD (`driver=iHD`), which may have newer codec support.

## When iGPU Makes Sense

Intel iGPU is ideal for:
- 24/7 media server transcoding (power efficiency)
- Up to 5-7 simultaneous 1080p transcodes
- Setups where power and heat matter

Keep the discrete GPU for:
- Gaming VMs with GPU passthrough
- Heavy compute (AI inference, rendering)
- More than 7 simultaneous transcodes
- AV1 encoding (newer iGPUs support this)

## Outcome

The RX 570 was freed up for gaming VMs on another host where it actually makes sense. The i5-7500's iGPU handles Jellyfin's transcoding workload at a fraction of the power draw. Right hardware for the right job.
