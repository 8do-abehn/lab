# Fix Bluetooth Headset Audio Quality on Ubuntu

## Problem
Bluetooth headsets (Bose QC2, AirPods Pro, etc.) sound awful on Ubuntu because they default to the HSP/HFP "headset" profile instead of the high-quality A2DP profile. This causes audio hiccups, poor quality, and mono sound.

## Technical Details

**Bad Profile (Default):**
- Profile: `headset-head-unit` (HSP/HFP)
- Codec: `msbc` or `cvsd`
- Quality: 16kHz mono
- Why: Enables microphone but terrible audio quality

**Good Profile (What You Want):**
- Profile: `a2dp-sink` (A2DP)
- Codec: `sbc` or `sbc-xq`
- Quality: 48kHz stereo
- Trade-off: No microphone support (Bluetooth can't do high-quality audio + mic simultaneously)

## Quick Fix

### Method 1: Command Line (PipeWire)

1. Connect your Bluetooth headset

2. Find the device ID:
```bash
wpctl status | grep -A 5 "Devices"
```
Look for your headset (e.g., `47. behn bose [bluez5]`)

3. Switch to A2DP profile:
```bash
pw-cli set-param <DEVICE_ID> Profile '{ index = 5, name = "a2dp-sink" }'
```

Example:
```bash
pw-cli set-param 47 Profile '{ index = 5, name = "a2dp-sink" }'
```

4. Verify it worked:
```bash
wpctl status | grep -A 5 "Sinks"
```
Your headset should appear as a sink.

**Quick one-liner:**
```bash
pw-cli set-param $(wpctl status | grep "AirPods\|bose" | grep "bluez5" | grep -oP '\d+' | head -1) Profile '{ index = 5, name = "a2dp-sink" }'
```

### Method 2: GUI (GNOME Settings)

1. Open Settings → Sound
2. Click on your Bluetooth headset
3. Under "Configuration", select "High Fidelity Playback (A2DP Sink)"
4. Avoid "Headset Head Unit (HSP/HFP)" profiles

## Why This Happens

Ubuntu's PipeWire/WirePlumber automatically switches to headset mode when:
- Communication apps are running (Zoom, Teams, etc.)
- Any app requests microphone access
- The system detects an input stream with `media.role = "Communication"`

The policy is defined in `/usr/share/wireplumber/scripts/policy-bluetooth.lua`

## Troubleshooting

### Profile won't switch / PipeWire shows "disconnected"

If `pw-cli info <DEVICE_ID>` shows `bluez5.connection = "disconnected"` even though the device is connected:

1. Restart PipeWire services:
```bash
systemctl --user restart pipewire pipewire-pulse wireplumber
```

2. If that doesn't work, disconnect and reconnect the device:
```bash
bluetoothctl disconnect <MAC_ADDRESS>
bluetoothctl connect <MAC_ADDRESS>
```

3. Try the GUI method (Settings → Sound) which sometimes works better than command line

### Device keeps switching back to headset mode

This is intentional for video calls. When apps like Zoom/Teams start, the system switches to headset mode to enable the microphone. You can manually switch back to A2DP after the call.

## Permanent Fix

To prefer A2DP by default, you could disable the auto-switching behavior, but this requires creating a custom WirePlumber config. The auto-switching is actually useful for video calls, so it's often better to just manually switch when needed.

## Tested Devices

- **Bose QC2** - Tested 2025-10-23
- **AirPods Pro** (Behner's AirPods Pro) - Tested 2025-10-29

## System Info

- **OS**: Ubuntu 24.04 LTS
- **Audio**: PipeWire 1.0.5 with WirePlumber
- **Hardware**: Asus mini computer
- **Bluetooth**: BlueZ 5.x

Works with most Bluetooth headsets that support A2DP profile.
