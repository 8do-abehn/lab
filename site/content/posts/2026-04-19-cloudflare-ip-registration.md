---
title: "Self-Service IP Registration for Family Jellyfin Access"
date: 2026-04-19
draft: false
tags: ["cloudflare", "workers", "jellyfin", "media-server", "security", "ansible"]
description: "A Cloudflare Worker that lets family members register their home IP for Jellyfin access from devices that can't handle browser-based auth flows."
---

After setting up Cloudflare Tunnel with Zero Trust Access for Jellyfin, I hit a new problem: family members with Rokus and Apple TVs outside my network couldn't get through the email OTP gate. Streaming device apps can't render a Cloudflare login page or enter an OTP code.

## The Problem

Cloudflare Access works great for browsers. But Jellyfin client apps on Rokus, Apple TVs, and phones make direct API calls. They need to reach Jellyfin without a browser-based auth step in the middle.

I didn't want to remove the Access gate entirely. The solution: let family members register their home IP address through a simple web flow on their phone, then allow that IP through to Jellyfin without OTP.

## Architecture

```
1. Family member visits register.8devops.com on phone
   -> Cloudflare Access (email OTP, family emails only)
   -> Cloudflare Worker captures their public IP
   -> Worker updates "Family IPs" Access policy via API
   -> Worker stores IP in KV with 7-day TTL

2. Family Roku hits media.8devops.com
   -> Cloudflare Access checks "Family IPs" policy
   -> IP matches, request passes through without OTP
   -> Cloudflare Tunnel -> Jellyfin
```

Two key pieces: a Cloudflare Worker for the registration page, and Workers KV for tracking IP expiry.

## Why Workers KV

Cloudflare's Access policy IP entries don't have TTL or expiry. Registered IPs would linger forever without cleanup. Workers KV solves this with native `expirationTtl` support. The Worker stores each registration in KV with a 7-day TTL. A scheduled Worker (cron trigger) runs daily, reads the surviving KV entries, and rebuilds the Access policy's IP list. Expired entries auto-delete from KV, and the next reconciliation removes them from the policy.

## The Registration Page

The Worker serves a simple page showing the visitor's current IP and registration status. After authenticating through Cloudflare Access (email OTP), they click one button to register. The page confirms the registration and links to Jellyfin.

On re-registration (IP changed), the Worker replaces the old entry and resets the TTL. One IP per email, no list bloat.

## Access Policy Structure

The Jellyfin Access app ends up with two policies:

1. **Allow by email** (precedence 1) - personal email, full OTP access from any IP
2. **Family IPs** (precedence 2) - registered IPs, no OTP required

Policy 1 is for browser access from anywhere. Policy 2 is for streaming devices at registered locations. Both require a Jellyfin account to actually use the service.

## Automating with Ansible

The entire setup is a separate Ansible role (`cloudflare_ip_registration`) that runs after the tunnel role:

1. Creates a KV namespace for IP tracking
2. Creates the "Family IPs" Access policy on the Jellyfin app (seeded with a placeholder)
3. Deploys the Worker with KV bindings and API secrets
4. Creates DNS and routing for `register.8devops.com`
5. Creates an Access application on the registration page (family emails only)

The Worker secrets (API token, account ID, app ID, policy ID) are set via the Cloudflare secrets API and stored encrypted. They never appear in Worker code or logs.

## Security Considerations

**What's solid:**
- Registration page is behind its own Access gate (email OTP)
- Only family emails can register IPs
- IPs expire after 7 days, auto-cleaned by scheduled Worker
- Jellyfin's own auth is still required after IP bypass
- Worker secrets are encrypted in Cloudflare, API token in Ansible vault
- No open firewall ports (still using Cloudflare Tunnel)

**Trade-offs:**
- Anyone on the same public IP as a family member gets past the Access gate (shared apartment WiFi, coffee shop). They still need a Jellyfin login.
- 7-day window means a family member's old IP lingers briefly after it changes. The scheduled cleanup handles this.
- The Worker has a Cloudflare API token that can modify Access policies. Scoped to minimum permissions, stored as a Worker secret.

## Cost

Everything runs on Cloudflare's free tier:
- Workers: 100k requests/day
- Workers KV: 100k reads/day, 1k writes/day
- Access: 50 users
- Tunnel: free

A handful of family members registering IPs weekly won't come close to any limit.

## Result

Family members visit `register.8devops.com` on their phone, tap one button, and their Roku can stream from Jellyfin for the next 7 days. No VPN, no port forwarding, no client installs. The entire stack is codified in two Ansible roles and costs nothing to run.
