---
title: "BadBox in the Living Room: Forensic Analysis of a VSeeBox V3 Plus"
date: 2026-07-06
draft: false
tags: ["security", "malware", "badbox", "android", "homelab", "forensics", "iptv"]
description: "A VSeeBox Android TV box sat quarantined on VLAN 666 for months. When I finally turned it on to investigate, the traffic capture told a story I didn't expect: VSeeBox is running the malware infrastructure themselves."
---

A VSeeBox V3 Plus had been sitting on a quarantine VLAN in my living room since last year. I'd isolated it after suspecting a BadBox infection and hadn't gotten around to pulling it apart. This weekend I finally did.

The short version: the device is infected with BadBox 2.0 malware. The SOCKS5 proxy was live and accepting connections from residential IPs. The DNS blocklist was being bypassed with encrypted DNS. And one domain in the traffic trace points directly back to VSeeBox's own infrastructure.

## What is BadBox?

BadBox is a family of malware pre-installed in the firmware of cheap Android devices (TV boxes, tablets, digital picture frames) before they ship. The infected devices become residential SOCKS5 proxies, routing arbitrary third-party traffic through your home IP address. Operators sell that bandwidth by the gigabyte to customers who want traffic that looks like it comes from real homes.

BadBox 2.0 (documented by HUMAN Security and others in 2024) significantly expanded the scope. Millions of devices were found infected. The malware survives factory resets because it lives in the system partition, not user storage.

## The Setup

My homelab runs an EdgeRouter X SFP with VLANs. VLAN 666 is a DMZ I use for untrusted devices: no RFC1918 lateral access to other VLANs, DNS forced through AdGuard Home, internet access allowed for streaming to work.

When I first suspected the VSeeBox, I moved it to VLAN 666 (`10.150.66.108`) and left it off. AdGuard Home logs showed the beacon traffic when it was last powered on: `aats.amlogic.com` resolving every 31 minutes, which is a documented BadBox C2 indicator.

## Turning It On and Watching

With the device contained on VLAN 666, I powered it on and started a packet capture on the EdgeRouter:

```
sudo tcpdump -i switch0.666 -n host 10.150.66.108 -w /tmp/vsee.pcap
```

After a few minutes I pulled the pcap and opened it in Wireshark, then ran tshark to extract the interesting fields:

```
tshark -r vsee.pcap -T fields -e ip.dst -e dns.qry.name \
  -e tls.handshake.extensions_server_name 2>/dev/null | sort -u
```

## What Was in the Traffic

**Known C2 domains from prior BadBox reports:**

- `aats.amlogic.com`: the original beacon, still firing
- `calon.dyndns.tv`, `weather.dyndns.tv`, `wz.gotdns.com`, `wq.dyndns.tv`: DDNS C2 cluster

**New C2 clusters not in public BadBox IOC feeds:**

The capture showed two new DDNS fallback clusters I hadn't seen documented before. Each uses the same hostname registered across five different DDNS providers, a redundancy technique so the botnet survives takedowns of any single provider.

**DNS bypass:**

```
8.8.8.8:443   (Google DoH)
1.1.1.1:443   (Cloudflare DoH)
185.222.222.222:443   (third DoH provider)
```

The device wasn't using the system DNS at all. It was making encrypted DNS-over-HTTPS queries directly to bypass AdGuard Home entirely. This is why DNS-level blocklists aren't sufficient containment for this malware.

**The smoking gun:**

```
vtcc_authn2.vseetvbox.com
```

That domain belongs to VSeeBox. The naming convention matches exactly how the app constructs auth URLs: take the base domain (`vtcc.vseetvbox.com`), insert `_authn2` before the first dot, append `/v1/auth`. The device was authenticating to VSeeBox's own servers as part of the malware call chain.

**Active SOCKS5 proxy:**

The connection table showed dozens of residential IP addresses (Comcast, Charter, AT&T ranges) communicating with the VSeeBox on high ephemeral ports. Those aren't streaming CDN servers. They're proxy clients. Other people's traffic was routing through my home connection.

## Decompiling the App

The device came with a pre-installed app called Heat Live. Curious about its relationship to the malware, I pulled the APK URL from unencrypted traffic:

```
http://static.vseetvbox.com/app/HeatLiveBackup.json
```

The response included an APK download URL and a package name: `com.google.heatlivebackup`. The `com.google` namespace is deliberately chosen to impersonate a Google package and bypass Android security audits that flag unknown publishers.

I decompiled the APK with jadx for static analysis. Key findings:

**DoH hardcoded in the player:**
```java
this.f2509a.setOption("doh_url", "https://dns.google/dns-query");
```

The DoH bypass isn't a malware component patched in after the fact. It's written into the app's video player. Every device running this app is deliberately bypassing system DNS.

**Victim geolocation on every launch:**

The app calls `pro.ip-api.com` with a hardcoded API key on startup to geolocate the user. Standard botnet victim profiling.

**Crash reporting to a custom server:**

Firebase Crashlytics would be the normal choice. Instead the app reports to `acrarium.tv1633.com` with a raw IP fallback, another VSeeBox-controlled endpoint.

**Streaming and SOCKS5 in the same Go library:**

The streaming engine is compiled Go code (via gomobile). The same native library that handles video playback (`libgojni.so`) contains the SOCKS5 proxy strings: `s ap traffic`, `s hs traffic`. The streaming functionality and the residential proxy are not two separate things bundled together. They're built into the same binary. That's an architectural decision, not an accident.

## Who Is Responsible

The narrative around BadBox usually assumes a supply chain attack: a manufacturer builds a legitimate device, a malicious actor compromises the firmware before it ships, and the manufacturer is a victim.

The evidence here doesn't support that framing for VSeeBox:

1. VSeeBox's own domain (`vtcc_authn2.vseetvbox.com`) is in the malware authentication chain.
2. The DoH bypass and SOCKS5 proxy are built into the app's own code, not injected by a third party.
3. VSeeBox does not publish firmware for manual flashing, making it impossible to clean the device without their cooperation.

## Containment and Disposal

VLAN 666 blocked lateral movement to the rest of the network, which is the main thing that mattered. The malware was freely communicating with the internet (DoH bypassed DNS filtering, and the SOCKS5 proxy was accepting connections), but it couldn't reach any other device on the LAN.

The device is being disposed of. Physically destroying the eMMC before disposal so it can't be resold to someone without an AdGuard Home and a packet capture habit.

## IOCs

Domains identified in this investigation not previously in public BadBox feeds:

- `vtcc_authn2.vseetvbox.com`: VSeeBox auth C2
- `vtcc.vseetvbox.com`: VSeeBox base domain
- `mv.vseego.com`: streaming credential broker
- `static.vseetvbox.com`: app/content CDN
- `static.vseego.com`: APK distribution CDN
- `acrarium.tv1633.com`: custom crash reporting
- `desaifvsbb1-5.desaifvsbb.ddns.me/net`: DDNS C2 cluster
- `xevksi3s2dz39.*` (ddns.net, ddnsking.com, myftp.org, myvnc.com, 3utilities.com): DDNS C2 cluster

APK: `com.google.heatlivebackup` v4.7.8, SHA-256 verification recommended before any analysis.

## Takeaways

Cheap Android TV boxes from unknown manufacturers are a persistent risk category. BadBox has been documented since 2023 and the infection volume keeps growing because the economics work: the boxes are cheap, the malware generates revenue, and most buyers never notice.

If you have one of these devices:

- A DNS blocklist alone won't contain it: the malware uses encrypted DNS to bypass it.
- VLAN isolation with no RFC1918 lateral access is the minimum viable containment.
- The only trustworthy path is flashing verified firmware from a known-clean source, which manufacturers like VSeeBox make deliberately difficult.
- When in doubt, dispose of it.

For reference, known-clean Android TV hardware includes devices with locked bootloaders from major manufacturers, or single-board computers running open source media software like LibreELEC where you control the entire software stack.
