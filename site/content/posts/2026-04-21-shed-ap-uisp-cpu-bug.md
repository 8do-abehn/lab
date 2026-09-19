---
title: "Why My Shed Lost WiFi: A UISP Agent Eating 100% CPU on a NanoStation"
date: 2026-04-21
draft: false
tags: ["ubiquiti", "networking", "troubleshooting", "airmax", "homelab"]
description: "A flaky shed access point turned out to be a wireless bridge with its CPU pegged at 100% by a UISP agent retrying connections to a cloud controller that didn't exist."
---

My shed AP had been intermittently dropping off the Unifi controller for weeks. It surfaced during a controller migration when push notifications started firing: "device disconnected for 21 minutes, reconnected." The other AP and switches were fine. Just the shed.

## The Setup

The shed is about 0.1 miles from the house. A pair of NanoStation Loco M2 devices form a point-to-point wireless bridge between the two buildings. A UAP-AC-Lite hangs off the shed-side bridge to provide WiFi coverage out there.

```
[House] --ethernet-- [Loco M2 AP] ~~wireless~~ [Loco M2 Station] --ethernet-- [AC-Lite]
         .13                                          .14                       .137
```

The bridges run airOS (not Unifi), so they have their own management UIs separate from the Unifi controller.

## Finding the Bridges

First challenge: I didn't know the bridge IPs. They're not managed by the Unifi controller and weren't documented anywhere. A quick scan of the subnet found them at `.13` and `.14`, each running airOS v6.3.11.

## The Smoking Gun

The house-side bridge looked fine at 6% CPU. The shed-side bridge was at **100% CPU**. After a reboot, it came right back up to 100%. Not stale state. Something was actively consuming all resources.

The logs told the story:

```
udapi-bridge[873]: unms: connecting to 13.249.141.93:443
udapi-bridge[873]: connection error (redacted.uisp.com:443): Timed out waiting SSL
udapi-bridge[873]: unms: connecting to 13.249.141.75:443
udapi-bridge[873]: connection error (redacted.uisp.com:443): Timed out waiting SSL
```

The UISP/UNMS agent was trying to connect to `redacted.uisp.com` every 20 seconds, timing out on SSL each time, and immediately retrying. On a device with the processing power of a calculator, that tight retry loop consumed everything.

Both bridges showed "UNMS: Enabled but unreachable" on their status pages. The cloud controller it was trying to reach either never existed or had been decommissioned long ago.

## The Fix

On each bridge: Services tab, disable UISP/UNMS, save. The shed-side CPU dropped from 100% to 3% immediately. The AC-Lite reconnected to the Unifi controller within minutes.

## What I Learned

**The bridge link was never the problem.** Signal strength was -29 dBm (excellent at 0.1 miles), CCQ was 97-99%, and the wireless link was negotiating 300/300 Mbps. The investigation plan assumed antenna drift or firmware issues, but the actual cause was a management agent running amok.

**Check the logs before assuming hardware.** The status page showed 100% CPU, and the logs showed exactly what was eating it. Could have saved time by going straight to the logs instead of trying reboots first.

**Disable cloud agents you're not using.** UISP/UNMS was enabled on both bridges but pointed at a nonexistent cloud controller. The house-side bridge was handling it at 6% CPU (maybe fewer retries or faster timeouts), but the shed-side was drowning. If you're not using a cloud management feature, turn it off.

**Document your bridge IPs.** These devices sat on the network for 200+ days without anyone knowing their IPs or checking on them. They're now documented and the UISP agent is disabled on both.
