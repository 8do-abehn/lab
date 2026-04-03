---
title: "AdGuard Home on Proxmox with EdgeRouter X-SFP: DNS, Ad Blocking, and Reverse DNS"
date: 2026-03-25
draft: false
tags: ["adguard", "dns", "edgerouter", "homelab", "proxmox", "tailscale"]
description: "How I set up AdGuard Home in an LXC container as the primary DNS server for my homelab, integrated it with an EdgeRouter X-SFP for DHCP-based reverse DNS, and enabled non-Tailscale devices to reach Tailscale services via subnet routing."
---

## The Problem

My homelab has multiple VLANs, a Tailscale overlay network, and no ad blocking. DNS was handled entirely by the EdgeRouter X-SFP forwarding to Cloudflare. I wanted:

1. Network-wide ad blocking without per-device configuration
2. Conditional DNS forwarding so LAN clients can resolve Tailscale hostnames
3. Non-Tailscale devices (Rokus, smart TVs) able to reach Tailscale services like Jellyfin
4. Client names on the DNS dashboard instead of raw IPs

## The Architecture

```
LAN Clients (10.150.10.0/24)
  │
  ├─ DNS ──→ dns01 (AdGuard Home, 10.150.60.11)
  │            ├─ Upstream: Cloudflare DoH, Google DoH
  │            ├─ Conditional: *.<tailnet>.ts.net → 100.100.100.100
  │            └─ Reverse DNS: PTR queries → EdgeRouter (10.150.10.1)
  │
  ├─ DHCP ──→ EdgeRouter X-SFP (dnsmasq)
  │            ├─ Primary DNS: 10.150.60.11 (AdGuard)
  │            ├─ Secondary DNS: 10.150.10.1 (router fallback)
  │            └─ Search domain: <tailnet>.ts.net
  │
  └─ 100.x.x.x traffic ──→ static route → dns01 → MASQUERADE → tailscale0
```

dns01 is an LXC container on pve01 running AdGuard Home and acting as a Tailscale subnet router advertising all four LAN subnets.

## Deploying dns01

The LXC runs Ubuntu 24.04 on Proxmox's VLAN 60 (management). A few gotchas:

**systemd-resolved blocks port 53.** Ubuntu 24.04 has it running by default. AdGuard Home can't bind to port 53 until you disable it:

```bash
systemctl disable --now systemd-resolved
rm /etc/resolv.conf
echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf
```

**MagicDNS leaks into LXC containers.** If the Proxmox host runs Tailscale with MagicDNS, it leaks `100.100.100.100` into the LXC's resolv.conf even with `pct set --nameserver`. The fix is disabling systemd-resolved before installing Tailscale, and running Tailscale with `--accept-dns=false`.

**Minimal LXC templates lack curl and gnupg.** Both are needed to add the Tailscale apt repo. Install them as prerequisites in your automation.

## Routing Non-Tailscale Devices to Tailscale Services

The streaming devices on the default VLAN don't run Tailscale, but they need to reach Jellyfin at its Tailscale IP (<tailscale-ip>). This took three pieces:

**Static route on the router** pointing the Tailscale CGNAT range at dns01:

```
set protocols static route 100.64.0.0/10 next-hop 10.150.60.11
```

**IP forwarding on dns01** so it actually forwards packets between eth0 and tailscale0:

```bash
sysctl -w net.ipv4.ip_forward=1
```

**iptables MASQUERADE** so return traffic routes correctly. Without NAT, Jellyfin sees the source as a LAN IP (10.150.10.x) and has no route back. MASQUERADE rewrites the source to dns01's Tailscale IP:

```bash
iptables -t nat -A POSTROUTING -o tailscale0 -j MASQUERADE
```

I used `iptables-persistent` to survive reboots and added idempotent Ansible tasks for the whole chain.

## DHCP and DNS Integration

EdgeRouter X-SFP runs dnsmasq for both DHCP and DNS forwarding. Pointing DHCP clients at AdGuard was straightforward — set dns01 as primary, router as fallback:

```
set service dhcp-server shared-network-name local subnet 10.150.10.0/24 dns-server 10.150.60.11
set service dhcp-server shared-network-name local subnet 10.150.10.0/24 dns-server 10.150.10.1
```

Order matters — the first entry becomes the primary DNS server.

## Getting Client Names in AdGuard

AdGuard Home shows client IPs by default. Getting hostnames requires reverse DNS (PTR records), which requires the DNS server to know which IP belongs to which hostname.

The key insight: EdgeOS's `use-dnsmasq enable` makes dnsmasq handle DHCP, which means it can serve PTR records from its lease table. But there's a catch — if you switched from ISC dhcpd to dnsmasq, existing leases are in ISC format. Devices need to renew their DHCP lease before dnsmasq registers them.

In AdGuard Home's DNS settings, I configured the private reverse DNS server to point at the router (10.150.10.1). I also added a conditional upstream so reverse lookups go to the right place:

```
[/10.150.in-addr.arpa/]10.150.10.1
```

After devices renewed their leases over 24 hours, the AdGuard dashboard started showing hostnames instead of IPs.

## Results

After one day of operation:

- 37,000+ DNS queries processed
- 10.6% blocked (mostly ad trackers, telemetry, and analytics)
- Top blocked domains: Netflix logs, Amazon telemetry, Roku analytics, Google ads
- All LAN clients showing hostnames on the dashboard
- Streaming devices reaching Jellyfin via Tailscale without running Tailscale themselves

## What I'd Do Differently

- **Disable systemd-resolved first** in the Ansible role, not as a manual step. I hit this twice (jellyfin01 and dns01).
- **Test PTR records early.** I spent too long debugging reverse DNS before realizing the DHCP engine matters.
- **Don't add random dnsmasq options without testing.** I accidentally added `no-resolv` to the router which nearly killed all DNS forwarding.
