# Fix Bluetooth Headset Audio Quality on Ubuntu

## Problem
Bose QC2 (and other Bluetooth headsets) sound awful on Ubuntu because they default to the HSP/HFP "headset" profile instead of the high-quality A2DP profile.

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

## Permanent Fix

To prefer A2DP by default, you could disable the auto-switching behavior, but this requires creating a custom WirePlumber config. The auto-switching is actually useful for video calls, so it's often better to just manually switch when needed.

## Notes

- Date: 2025-10-23
- System: Ubuntu with PipeWire 1.0.5
- Works with: Bose QC2, and most other Bluetooth headsets
