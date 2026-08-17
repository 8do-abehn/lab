---
title: "Chasing a FireWire Ghost: Getting a Nikon Scanner Onto a Proxmox Cluster"
date: 2026-08-13
draft: false
tags: ["proxmox", "thunderbolt", "firewire", "hardware", "troubleshooting", "homelab"]
description: "An Apple USB-C to Thunderbolt 2 adapter, a Thunderbolt to FireWire 800 bridge, and a Nikon Coolscan 8000 walk into a Proxmox cluster. Nothing shows up. Here's what a night of dmesg spelunking turned up, including a motherboard manual warning I should have read first."
---

I wanted to get an old Nikon Coolscan 8000 film scanner talking to my Proxmox cluster. The scanner is FireWire 800 only, so the plan was an Apple USB-C to Thunderbolt 2 adapter chained into a Thunderbolt to FireWire 800 adapter, both official Apple parts. Simple enough on paper. It took an entire evening and a trip through a motherboard manual to figure out why nothing was showing up.

## Step One: Which Host Even Has Thunderbolt

The cluster is three nodes, pve01 through pve03, all Ryzen 9 5900X boxes. Before chasing the adapter I checked `lsusb` on all three:

```
for h in pve01 pve02 pve03; do
  ssh root@$h lsusb
done
```

pve01 and pve03 came back clean, no sign of anything Apple. pve02 had it: `05ac:1657 Apple, Inc. Thunderbolt 3 (USB-C) to Thunderbolt 2 Adapter`. Good, at least I knew which host to focus on.

A quick `lspci -nn | grep -i thunderbolt` on pve02 confirmed real hardware: an Intel Maple Ridge Thunderbolt 4 controller, several PCI bridges, and a couple of USB controllers hanging off it. `dmidecode -s baseboard-product-name` showed why: pve02 runs an ASUS ProArt X570-CREATOR WIFI, the only board of the three with native Thunderbolt. pve01 and pve03 are Gigabyte X570S AERO G boards, no Thunderbolt silicon at all. So the other two hosts were never going to see this device no matter what I did.

## The Billboard Trap

With the adapter plugged into pve02, `lsusb` showed it, but as `Class=Billboard, Driver=[none]` sitting on a completely ordinary AMD chipset USB controller, not the Intel Maple Ridge Thunderbolt controller. Checking `/sys/bus/thunderbolt/devices` showed only the host router itself (`domain0` and `0-0`), nothing downstream. `lspci` never showed a FireWire/1394 controller at any point.

Billboard is a real USB-C class, not a bug: when a device requests an Alternate Mode (like a Thunderbolt tunnel) and the host doesn't grant it, USB-C spec has the device fall back to advertising itself as a Billboard device so the OS can at least identify it. That's exactly what kept happening, on every port I tried, hot-plugged, cold-booted, chained or standing alone.

I mapped the actual USB bus topology to be sure I wasn't fooling myself:

```
for b in /sys/bus/usb/devices/usb*; do
  n=$(basename $b)
  busnum=$(cat $b/busnum)
  realpath $b | sed 's#.*/devices/##' | xargs -I{} echo "Bus $busnum -> {}"
done
```

Only Bus 1 and Bus 2 actually traced back through the Maple Ridge PCI path (`...0a:00.0`). Every device I plugged in, including the Apple adapter, landed on the AMD chipset's own controllers instead. Whatever port I thought I was using, the Thunderbolt controller's own buses stayed completely empty.

## RTFM

At that point I pulled the actual ASUS manual for the ProArt X570-CREATOR WIFI and went looking for anything about the Thunderbolt ports specifically. Found this in the Thunderbolt/DisplayPort configuration section:

> DO NOT hot swap the Thunderbolt 4 USB Type-C port E1, and Thunderbolt 4 USB Type-C port E2 ports when your motherboard is powered on.

That explained the entire evening. This board's Thunderbolt controller only enumerates devices at POST. Every hot-plug attempt, correct port or not, was invisible to it by design.

## The Reboot That Wasn't

Since pve02 is a live cluster node, the sane path was to migrate its running LXCs off first. Three were HA-managed at the time: a metube instance, a docker host, and a unifi controller. `pct migrate <ctid> pve01 --restart` for each, confirmed they landed and started cleanly on pve01, then shut pve02 down properly rather than just rebooting it. A warm reboot doesn't necessarily reset a Thunderbolt controller's connection-manager firmware state; a full power-off does.

First attempt at powering back on with the chain connected stalled hard during POST. I ended up holding the power button to force it off, which triggered an "abnormal shutdown, check BIOS settings" prompt on the next boot. Saved and exited, and it hung again, this time part way through the Linux boot sequence at the root filesystem check. A few cycles of that before a full 10 second power drain (unplugging entirely, not just holding the button) got it through a clean boot.

Turned out the chain wasn't even the cause of that particular problem. I disconnected everything and it still stalled the same way. The repeated hard power-offs mid-POST had corrupted enough NVRAM state to cause boot problems that had nothing to do with Thunderbolt. Two separate problems tangled together in one evening: a firmware hot-plug limitation, and a self-inflicted boot loop from fighting it with the power button.

## Still a Ghost

Once pve02 was booting cleanly again with the full chain connected and seated tight before power-on, the result was the same as every hot-plug attempt: `dmesg` logged `thunderbolt 0000:08:00.0: no switch exists at 1, ignoring`, repeated three times during boot, and nothing ever showed up under `/sys/bus/thunderbolt/devices` beyond the host router.

At that point the evidence pointed less at cabling or firmware settings and more at the adapter itself. Apple's official Thunderbolt adapters do a vendor-specific handshake designed around genuine Mac hosts. Non-Apple Thunderbolt controllers, especially under Linux, have a documented history of failing that handshake and falling back to the same Billboard behavior I'd been seeing all night, regardless of hot-plug support.

Worth noting for context: Apple pulled the `IOFireWireFamily` kernel extension entirely in macOS 26 Tahoe, ending FireWire support on the Mac side too. Even on a genuine Mac, this exact adapter chain (USB-C to TB2, then TB2 to FireWire) only ever worked with caveats on Sonoma and earlier, with some pro audio interfaces failing to enumerate under T2/Apple Silicon security policies. The chain was never fully solid, even on hardware Apple designed it for.

## Where It's Headed

The most reliable path forward is probably to skip Thunderbolt entirely. A PCIe FireWire 400/800 card seated directly in pve02 avoids both the hot-plug limitation and the Apple-adapter compatibility question at once, and the Linux `firewire-ohci` driver has been solid for a long time. Testing the Apple adapter on an actual pre-Tahoe Mac would settle whether it's a dead unit or just incompatible with this particular Thunderbolt host, but at this point a five dollar PCIe card is probably less effort than continuing to fight it.

## Takeaways

- Check what hardware actually has Thunderbolt before troubleshooting cabling. Two of my three cluster nodes never had a chance.
- `lsusb -t` plus mapping `/sys/bus/usb/devices/usb*` back to PCI paths is the fastest way to confirm whether a device landed on the controller you think it did.
- A device showing up as USB "Billboard" class means the host refused its requested Alternate Mode. That's diagnostic information, not just noise.
- Read the manual before hot-plugging anything into a motherboard's Thunderbolt ports. Not every implementation supports it, and ASUS says so in plain text if you go looking.
- If you fight a POST hang with the power button, expect a second, unrelated problem from the abrupt power-offs. A full power drain resets more state than holding the button does.
- Apple's Thunderbolt adapters are built for Apple hosts. Don't assume they'll behave the same on a PC Thunderbolt controller, especially under Linux.
