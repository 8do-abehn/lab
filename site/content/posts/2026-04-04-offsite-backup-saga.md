---
title: "Moving a Raspberry Pi Offsite: Everything That Went Wrong"
date: 2026-04-04
draft: false
tags: ["homelab", "raspberry-pi", "backup", "tailscale", "restic", "debugging"]
description: "A cautionary tale about moving a backup server to a remote location, featuring router USB ports, client isolation, emergency reflashes, and a CephFS surprise."
---

## The Plan

Move `pi-burg` — my Raspberry Pi 3 running restic as an offsite backup target — from my house to my mom's. Simple, right? It already had Tailscale, so once it was on her wifi it would just appear on the tailnet from wherever.

Total estimated time: 15 minutes.

Total actual time: ~6 hours.

## The Stack

- Raspberry Pi 3 running Raspberry Pi OS Lite
- 8TB USB drive with an existing restic repository
- Tailscale for tailnet connectivity (no static IPs, no port forwarding)
- A long drive to mom's house

## What Was Supposed to Happen

1. Configure wifi on the Pi for mom's network before leaving home
2. Drive to mom's
3. Plug in power, let Tailscale come up
4. Profit

## What Actually Happened

### Chapter 1: Cloud-init Is a Liar

The Pi was already provisioned, so I edited `/boot/firmware/network-config` from my Mac to add mom's wifi. I even recomputed the WPA PSK hash because the stored one was for a different SSID. Saved, ejected, booted.

Nothing. The Pi was a ghost on the network.

**Lesson:** Cloud-init only reads `network-config` on the **first boot**. On a provisioned Pi, that file is inert. NetworkManager owns wifi at runtime, and editing the boot partition does nothing.

### Chapter 2: Maybe It'll Just Work

At mom's, I plugged the Pi into her Calix EXOS router via ethernet. Green link lights on both sides. Surely DHCP would hand out an address and Tailscale would come up.

Nothing in the router's DHCP client list. No Raspberry Pi OUI (`b8:27:eb`). `nmap -sn` on her `192.168.1.0/24` showed the same 4 devices before and after plugging in the Pi.

I moved ports. I logged into the EXOS admin panel and scrolled through the connected devices and DHCP client list. The Pi was plugged in, powered on, link lights on — and completely invisible to the network.

### Chapter 3: The Headless Nightmare

OK, I needed console access. But:

- No USB keyboard at mom's
- She doesn't own one
- The Pi is headless, so SSH is my only path — and SSH requires networking, which requires wifi, which requires... a keyboard

I tried everything:

1. **iPhone hotspot** — configured the Pi during reimaging to connect directly. Hotspot client isolation blocked Mac-to-Pi traffic even with "Maximize Compatibility" enabled.
2. **Mac Internet Sharing** — shared my Mac's wifi connection to the Belkin USB-C LAN dongle, plugged the Pi into the dongle. This worked. The Pi got `192.168.2.2` on the shared subnet.

Finally, SSH access.

### Chapter 4: The Wifi That Didn't Stick

Connected to the Pi, I ran:

```
sudo nmcli device wifi connect "Mom's Wifi" password 'redacted'
```

(Single quotes — `bash` history expansion eats `!` with double quotes. Another lesson.)

NetworkManager reported success. `nmcli device status` showed wlan0 as connected with a real `192.168.1.x` IP. I installed Tailscale, ran `sudo tailscale up`, authorized on my phone, and verified the Pi was on the tailnet.

Then I unplugged the ethernet, moved the Pi to its permanent spot by the router, and plugged in the power.

**Nothing.** No ping. No tailnet presence. Dead again.

### Chapter 5: The Real Bug

I was powering the Pi from the Calix router's USB port. Convenient — one power strip instead of two. Except router USB ports typically deliver **500mA max**. A Raspberry Pi 3 needs at least **2A**. The Pi had been undervolted the entire time, which explains every flaky symptom I'd been chasing.

Swapped in a 5A travel power supply I had with me. The Pi came up, Tailscale connected, and it's been rock solid since. Need to grab a simpler dedicated 3A wall wart to leave there next time — that travel brick is too good to lose.

**Lesson:** Router USB ports are decorative. Never power a Pi from them.

### Chapter 6: The CephFS Surprise

With the Pi online, I ran the backup script from my media server. It failed with `Host key verification failed` — the reflashed Pi had a new SSH host key. Cleared the old key, retried.

Now `Permission denied` — the `backup` user's `authorized_keys` was gone because I reflashed the whole OS. The original SSH key had been set up manually months ago and never codified in Ansible.

Codified it properly: the `backup_client` role now generates an SSH key and registers its pubkey as a host fact. The `backup_server` role walks `groups['backup_clients']` via `hostvars` to collect all pubkeys and deploy them to the `backup` user's `authorized_keys`. Reordered `backup-setup.yml` so clients run first.

Backup script ran. Restic started hashing files. I expected it to be fast since all the existing data was in the repo.

Instead, it started reading every movie in the library from scratch. over a terabyte of media being re-hashed.

**Lesson:** Restic's "unchanged file" detection uses inode + ctime + size. The media library lives on **CephFS**, and something about the path — remount, cache invalidation, metadata churn — had caused the inodes to look different. Restic had no choice but to re-chunk everything. Dedup meant almost nothing was actually uploaded, but the read-through of over a terabyte took hours.

First backup after any FS change on CephFS is slow. That's the cost.

### Chapter 7: The Accidental Unplug

About 30 minutes into the re-hash, 26% done, someone bumped the power and it came out. Restic died with `context canceled`.

Restic is resumable, sort of. Checking the next run with lsof, it started back at the A's and worked forward again rather than jumping to the 26% mark. The local cache speeds up metadata checks but doesn't let you resume mid-snapshot — you re-walk the filesystem from the start.

## The Accidental Win: A Credential Leak

While debugging the backup script with `bash -x`, I noticed the notify function printing the Apprise URL — which contains the Gmail app password in plaintext. `set -x` traces variable expansions, so every `apprise -t "..." "$APPRISE_URLS"` call dumped the password to stdout.

Rotated the Gmail app password immediately, updated vault.yml, and patched the script template:

```bash
notify() {
    { set +x; } 2>/dev/null  # Avoid leaking APPRISE_URLS in xtrace output
    ...
}
```

Wouldn't have found this without the saga. So there's that.

## What I'd Do Differently

1. **Test the full procedure at home before traveling.** Reflash the SD card, boot with wifi preconfigured, verify Tailscale comes up automatically — all on my own network where I have tools. Don't debug remotely.
2. **Bring a USB keyboard in the go-bag.** Even a cheap one. Headless recovery without console access is miserable.
3. **Never power a Pi from a router USB port.** Ever.
4. **Codify everything in Ansible from day one.** Manual SSH key setup is a time bomb that goes off the moment you reflash anything.
5. **Check restic cache state after any filesystem changes.** A one-time slow backup is fine if you know it's coming; a surprise 4-hour re-hash mid-debugging is not.

## The Payoff

`pi-burg` is now on mom's wifi, reachable via Tailscale at a stable hostname, running daily restic backups of the media library and Jellyfin config. First offsite backup is grinding through its re-hash. If my house burns down, the backup survives.

Worth it. Mostly.
