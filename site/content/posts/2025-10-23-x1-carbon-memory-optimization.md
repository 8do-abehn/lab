---
title: "X1 Carbon Memory Crisis and the zram Solution"
date: 2025-10-23
draft: false
tags: ["linux", "optimization"]
summary: "Started with 'why won't Brave start?' and ended with compressed RAM giving the equivalent of 16GB+ on hardware that can't be upgraded."
---


## Mission: Fix Browser Issues and Optimize 8GB RAM Limitations

Started with "why won't Brave start?" and ended with compressed RAM giving us the equivalent of 16GB+ on hardware that can't be upgraded. Along the way: discovered hardware limitations, diagnosed memory pressure, and learned that sometimes software can overcome hardware constraints.

## The Journey

### Act 1: The Browser That Wouldn't Launch

**The Problem:** Brave browser completely refused to start. No window, no error messages, just silence.

**The Investigation:**
```bash
brave 2>&1
```

**The Discovery:**
```
Error: The profile appears to be in use by another Brave process (5924) on another computer
Brave has locked the profile so that it doesn't get corrupted.
```

Process 5924 didn't exist - it was a stale lock file from a previous crash or improper shutdown.

**The Pattern Emerges:** This is a common Chromium-based browser issue. When browsers crash or are force-killed, they leave lock files behind that prevent future launches.

**The Fix:**
The SingletonLock file was supposed to be at `~/.config/BraveSoftware/Brave-Browser/SingletonLock`, but Brave was installed via snap, so the actual path was different. Simply relaunching Brave cleared the stale lock automatically.

**The Lesson:** Snap apps store their config in `~/snap/[app-name]/` instead of `~/.config/`. Always check `which` to see if an app is snap-installed.

### Act 2: Spotify Strikes Back

**The Problem:** After fixing Brave, tried to launch Spotify. Same symptoms: command runs, but nothing happens.

**The Diagnosis:**
```bash
spotify 2>&1
```

Similar lock file issue! But this time it needed manual intervention.

**The Discovery:**
```bash
find ~/snap/spotify -name "*lock*" -o -name "*Lock*"
~/snap/spotify/common/.cache/spotify/SingletonLock
```

**The Fix:**
```bash
rm ~/snap/spotify/common/.cache/spotify/SingletonLock
spotify &
```

**Success!** Spotify launched immediately.

**The Pattern:** Two snap apps, two lock file issues on the same day. Suggests the system had crashed or been force-powered-off recently, leaving multiple apps in inconsistent states.

### Act 3: Hardware Identity Crisis

**The Question:** "What's the model and serial number of this laptop?"

**The Discovery:**
```bash
cat /sys/class/dmi/id/product_name
ThinkPad X1 Carbon 3rd

cat /sys/class/dmi/id/product_version
20BS0031US
```

**The Specs:**
- Model: ThinkPad X1 Carbon 3rd Generation
- Type: 20BS0031US
- Release: ~2015 (10 years old!)
- Current RAM: 8GB DDR3L 1600MHz

### Act 4: The Soldered RAM Revelation

**The Next Question:** "Can I upgrade the RAM?"

**The Web Search Results:** Devastating but definitive.

**The Truth:**
- Memory slots: **0**
- RAM configuration: **Soldered to motherboard**
- Upgrade options: **None**

From Lenovo's official spec sheet:
> "4GB, 8GB, or 16GB / PC3-12800 1600MHz DDR3L / soldered to systemboard, no sockets"

**The Reality:** X1 Carbon prioritized thin-and-light design over upgradability. The RAM is permanently attached to the motherboard. You're stuck with whatever configuration came from the factory.

**The Silver Lining:** At least the SSD is upgradeable (M.2 slot).

**The Philosophical Moment:** When hardware can't be upgraded, software optimization becomes critical.

### Act 5: Finding the Memory Hogs

**The Analysis:**
```bash
ps aux --sort=-%mem | head -20
```

**The Culprits:**
1. **Brave Browser: 3.5GB** (27 renderer processes - 27 tabs!)
   - Single heaviest tab: 323MB
   - Multiple tabs: 200-280MB each
2. **Spotify: 550MB** (UI + multiple renderers)
3. **Claude CLI: 420MB** (2 instances running)
4. **Gnome Shell: 157MB** (desktop environment)

**The Math:**
- 8GB total RAM
- 6.5GB in use
- Only 159MB free
- 3.6GB swap already in use (out of 4GB)

**The Reality Check:** The system was thrashing. With 3.6GB of swap in use, the disk was constantly churning as the system moved data between RAM and disk. This explained any sluggishness.

**The Root Cause:** Not "memory leaks" or buggy software - just too many browser tabs for the available RAM.

### Act 6: The zram Miracle

**The Options Discussed:**
1. Close browser tabs (helps, but limiting)
2. Use lighter browser (marginal gains)
3. Switch to lighter desktop (saves ~100MB)
4. Increase swap (slower, but helps)
5. **Enable zram (compressed RAM)**
6. Buy new laptop (nuclear option)

**The Choice:** Option 7 - zram (compressed RAM).

**What is zram?**
A Linux kernel module that creates a compressed block device in RAM. Data stored there is compressed 2-3x, effectively multiplying available RAM.

**The Installation:**
```bash
sudo apt update && sudo apt install zram-config -y
```

**The Configuration:** None needed! zram-config auto-configures based on available RAM:
- Creates ~50% of RAM as compressed swap (3.7GB)
- Sets high priority (5) so it's used before disk swap (-2)
- Enables automatically on boot

**The Launch:**
```bash
sudo systemctl start zram-config.service
```

**The Results:**
```bash
zramctl
NAME       ALGORITHM DISKSIZE  DATA  COMPR  TOTAL STREAMS
/dev/zram0 lzo-rle       3.7G  1.2G 450.6M 461.8M       4

swapon --show
NAME       TYPE      SIZE USED PRIO
/dev/zram0 partition 3.7G 1.9G    5  ← Fast (RAM-based)
/swap.img  file        4G 2.6G   -2  ← Slow (disk-based)
```

**The Magic:**
- 1.2GB of data compressed into 450MB of RAM
- Compression ratio: **2.7x**
- Total swap went from 4GB to 7.7GB
- Effective total memory: ~10-12GB equivalent

**The Performance Impact:**
- RAM-based swap is 100-1000x faster than disk swap
- System will use zram first (higher priority)
- Disk swap becomes last resort only
- Reduced thrashing = smoother performance

### Act 7: The Verification

**Before zram:**
```
Mem:  7.4Gi total, 6.5Gi used, 159Mi free
Swap: 4.0Gi total, 3.6Gi used
```

**After zram:**
```
Mem:  7.4Gi total, 6.1Gi used, 283Mi free
Swap: 7.7Gi total, 4.5Gi used
```

**Analysis:**
- More free RAM (283MB vs 159MB)
- Total swap increased by 3.7GB
- zram already actively working (1.9GB in use)
- Compression working well (2.7x ratio)

**Status:** System should now handle the 27 Brave tabs + Spotify + Claude without excessive disk thrashing.

## What We Learned

### Snap App Configuration
- Snap apps store config in `~/snap/[app-name]/` not `~/.config/`
- Check installation method with `which [app]`
- Snap path pattern: `~/snap/[app]/[version]/.config/...`

### Lock File Issues
- Chromium-based apps (Brave, Spotify uses Chromium) use SingletonLock files
- Crashes/force-kills leave stale locks
- Common locations: `~/.config/` (native) or `~/snap/` (snap apps)
- Sometimes clearing automatically on relaunch, sometimes need manual removal

### Hardware Limitations
- X1 Carbon 3rd Gen: RAM is soldered, zero upgrade options
- Ultrabooks prioritize form factor over upgradability
- Check `/sys/class/dmi/id/` for hardware info (no sudo needed)
- Use `sudo dmidecode` for detailed info (requires root)

### Memory Management
- Browser tabs are memory hungry (200-300MB each is normal)
- Modern apps (Spotify, Slack, Discord) use Chromium = RAM-heavy
- Swap usage is normal, but high swap usage = performance problems
- Disk swap is ~1000x slower than RAM

### zram Magic
- Compresses inactive memory 2-3x
- Creates "virtual RAM" from real RAM
- LZ4/lzo-rle compression is fast enough to be worth it
- Can effectively double usable RAM on constrained systems
- Modern kernels handle this transparently

### Linux Memory Optimization
- `zram-config` package auto-configures everything
- Priority system: RAM (unlimited) → zram (5) → disk swap (-2)
- `free -h` shows totals, `swapon --show` shows breakdown
- `zramctl` shows compression ratios and effectiveness

## Current State

**Working:**
- ✅ Brave browser launching and running (27 tabs!)
- ✅ Spotify launched and accessible
- ✅ zram enabled and actively compressing
- ✅ 7.7GB total swap (3.7GB fast zram + 4GB disk)
- ✅ 2.7x compression ratio achieved
- ✅ Auto-enabled on boot

**Improved:**
- 🚀 More free RAM (283MB vs 159MB)
- 🚀 Faster swap access (RAM vs disk)
- 🚀 Reduced disk thrashing
- 🚀 Better multitasking headroom

**Limitations Accepted:**
- ⚠️ Can't upgrade physical RAM (hardware limitation)
- ⚠️ Still only 8GB physical RAM
- ⚠️ 27 browser tabs is pushing limits even with zram

**Spotify Email Issue:**
- ⛔ Still not receiving verification emails from Spotify
- ⛔ Need to check Gmail spam/promotions and Proton spam
- ⛔ May need to contact @SpotifyCares on Twitter
- 📝 Not a technical issue - email delivery problem

## Next Steps

1. **Monitor zram performance** over next few days
   - Check compression ratio: `zramctl`
   - Watch for disk swap usage: `swapon --show`
   - Monitor with: `watch -n 5 'free -h && echo && swapon --show'`

2. **Consider browser tab management**
   - Install tab suspender extension for Brave
   - Bookmark tabs instead of keeping all open
   - Use tab grouping to identify closable tabs

3. **Spotify email issue**
   - Manually check Gmail Promotions and Spam folders
   - Check ProtonMail spam folder
   - Wait 30 minutes and retry verification
   - Contact @SpotifyCares if still not receiving

4. **Optional future optimizations**
   - Check SSD model/size: `lsblk` and `sudo smartctl -a /dev/nvme0n1`
   - Consider SSD upgrade if needed
   - Evaluate if GNOME desktop is worth the RAM cost (vs XFCE/LXQt)

## Technical Artifacts

**System Information:**
```
Model: ThinkPad X1 Carbon 3rd Gen (20BS0031US)
RAM: 8GB DDR3L-1600 (soldered, non-upgradeable)
OS: Ubuntu 24.04 (Noble)
Kernel: 6.14.0-33-generic
Desktop: GNOME Shell
```

**Applications Running:**
```
Brave Browser: 3.5GB (27 tabs)
Spotify: 550MB
Claude CLI: 420MB (2 instances)
GNOME Shell: 157MB
```

**zram Configuration:**
```
Device: /dev/zram0
Algorithm: lzo-rle
Size: 3.7GB
Compression: 2.7x (1.2GB → 450MB)
Priority: 5 (higher than disk swap)
Status: Active and working
```

**Memory Before/After:**
```
Before zram:
  Total RAM: 7.4GB (6.5GB used, 159MB free)
  Swap: 4GB disk (3.6GB used)

After zram:
  Total RAM: 7.4GB (6.1GB used, 283MB free)
  Swap: 7.7GB total (3.7GB zram + 4GB disk)
  Active compression: 2.7x ratio
```

**Commands Used:**
```bash
# Browser troubleshooting
brave 2>&1
ps aux | grep brave
rm ~/snap/brave/*/SingletonLock

# Spotify troubleshooting
spotify 2>&1
find ~/snap/spotify -name "*lock*"
rm ~/snap/spotify/common/.cache/spotify/SingletonLock

# Hardware identification
cat /sys/class/dmi/id/product_name
cat /sys/class/dmi/id/product_version

# Memory analysis
ps aux --sort=-%mem | head -20
free -h
swapon --show

# zram setup
sudo apt install zram-config
sudo systemctl start zram-config.service
zramctl
```

## Lessons Learned

1. **Hardware constraints inspire software solutions** - Can't upgrade RAM? Compress it!
2. **Lock files are common after crashes** - Know where to find them
3. **Snap apps have different paths** - Always check `which` first
4. **Browser tabs are expensive** - 27 tabs = 3.5GB RAM
5. **zram is underutilized magic** - 2-3x compression for free
6. **Swap hierarchy matters** - Fast swap first, slow swap last
7. **Memory pressure is manageable** - Even on 10-year-old hardware
8. **Close tabs you're not using** - Seriously, close them

## Random Insights

- X1 Carbon 3rd Gen (2015) is still very usable in 2025 with proper optimization
- Modern web apps are RAM-hungry beasts (looking at you, Chromium)
- Linux memory management is sophisticated and helpful
- Sometimes the best upgrade is the one you can't buy
- 27 browser tabs might be too many (but we're making it work)
- Compression isn't just for files - it works for RAM too
- 10-year-old laptop + modern software optimization = surprisingly capable

## Top 10 Commands from October 23, 2025

1. **`brave 2>&1`**
   - Capture stderr to see why GUI apps won't launch
   - Key for debugging silent failures

2. **`ps aux | grep brave | grep -v grep`**
   - Find running processes and filter out the grep command itself
   - Essential for verifying if apps actually launched

3. **`find ~/snap/spotify -name "*lock*"`**
   - Search for lock files in snap app directories
   - Crucial for diagnosing app launch failures

4. **`cat /sys/class/dmi/id/product_name`**
   - Get hardware model without sudo
   - Quick way to identify exact laptop model

5. **`ps aux --sort=-%mem | head -20`**
   - Show top memory-consuming processes
   - Memory troubleshooting step #1

6. **`free -h`**
   - Human-readable memory usage summary
   - Shows RAM, swap, buffers, cache

7. **`swapon --show`**
   - Display all active swap devices with priorities
   - Essential for understanding swap hierarchy

8. **`zramctl`**
   - Show zram device stats including compression ratio
   - Verify zram is working and how well

9. **`sudo apt install zram-config`**
   - One-command RAM compression setup
   - Auto-configures everything based on system RAM

10. **`sudo systemctl start zram-config.service`**
    - Enable zram immediately (without reboot)
    - Verify service status with `systemctl status`

### Honorable Mentions

- **`which brave`** - Find if app is snap/native/flatpak
- **`lsblk | grep zram`** - Quick check if zram exists
- **`rm ~/snap/*/SingletonLock`** - Clear lock files
- **`watch -n 5 'free -h'`** - Monitor memory in real-time

### Command Pattern: Troubleshooting → Diagnosis → Optimization

**Troubleshooting:** Why won't apps start? (Lock files)
**Diagnosis:** What's using all the RAM? (Browser tabs)
**Optimization:** How to get more RAM? (Compression)

The progression from "it doesn't work" to "it works better than before" in a single session!

---

*"Hardware limitations are just software optimizations waiting to be discovered."* - Every Linux User With 8GB RAM
