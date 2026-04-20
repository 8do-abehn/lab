---
title: "Exposing Jellyfin Through Cloudflare Tunnel with Zero Trust Access"
date: 2026-04-18
draft: false
tags: ["cloudflare", "jellyfin", "media-server", "security", "ansible"]
description: "Securely exposing a self-hosted Jellyfin server at media.8devops.com using Cloudflare Tunnel and Zero Trust email OTP, fully automated with Ansible."
---

I needed to access my Jellyfin media server from a managed work laptop where I can't install Tailscale or any VPN client. Cloudflare Tunnel solved this: outbound-only connection from the LXC, no open firewall ports, and a Zero Trust email OTP gate before anyone can reach Jellyfin.

## The Problem

My Jellyfin instance runs in an LXC container on Proxmox. It's accessible over Tailscale from my personal devices, but some environments have endpoint protection that blocks VPN installs. I needed a way to access my media library over plain HTTPS without installing anything on the client.

## Why Cloudflare Tunnel

A few options I considered:

- **Port forwarding** - Opens a hole in the firewall. No thanks.
- **Reverse proxy on a VPS** - Works, but adds a server to maintain and pay for.
- **Cloudflare Tunnel** - Outbound-only connection, free tier, built-in auth. The tunnel connector (cloudflared) runs on the Jellyfin host and dials out to Cloudflare's edge. No inbound ports needed.

## Architecture

```
Browser
  -> Cloudflare Edge (TLS termination)
  -> Zero Trust Access (email OTP check)
  -> Cloudflare Tunnel
  -> cloudflared on jellyfin01
  -> http://localhost:8096 (Jellyfin)
```

The tunnel is outbound-only from the LXC. Cloudflare terminates TLS at the edge, authenticates via email OTP, then forwards through the tunnel to Jellyfin's local port.

## Automating with Ansible

I built an Ansible role that handles everything via the Cloudflare API:

1. Installs cloudflared from the official apt repo
2. Creates the tunnel via API (or skips if it exists)
3. Configures ingress rules (hostname to local service mapping)
4. Creates the DNS CNAME record pointing to the tunnel
5. Fetches the tunnel token and installs cloudflared as a systemd service
6. Creates a Zero Trust Access application with an email allow policy

The role is fully idempotent. Re-runs produce zero changes. All mutating API calls are guarded with `not ansible_check_mode` so CI dry runs don't create real Cloudflare resources.

### Inventory

```yaml
cloudflare_tunnel:
  hosts:
    jellyfin01:
```

### Host Variables

```yaml
cloudflare_tunnel_name: jellyfin
cloudflare_tunnel_hostname: media.8devops.com
cloudflare_tunnel_service: "http://localhost:8096"
cloudflare_access_emails:
  - "{{ vault_cloudflare_access_email }}"
```

### API Token Permissions

The role needs a Cloudflare API token with:

- Account: Cloudflare Tunnel: Edit
- Account: Access: Apps and Policies: Edit
- Account: Access: Organizations, Identity Providers, and Groups: Read
- Zone: DNS: Edit (scoped to the domain)

### Running It

```bash
ansible-playbook site.yml --limit jellyfin01 --ask-vault-pass
```

One command, and Jellyfin is accessible at `media.8devops.com` behind email OTP.

## Zero Trust Access

Cloudflare Access sits in front of the tunnel. Anyone hitting `media.8devops.com` sees a Cloudflare login page instead of Jellyfin. Only allowed email addresses can request an OTP. After entering the code, there's a 24-hour session before re-authentication.

This means two layers of auth: Cloudflare Access (email OTP) and Jellyfin's own user login. Even if someone bypasses Cloudflare, they still need a Jellyfin account.

## Security Considerations

**What's solid:**
- No open ports on the firewall
- Outbound-only tunnel connection
- Email OTP is phishing-resistant compared to passwords
- Kill the tunnel and access disappears instantly
- Jellyfin's own auth is a second layer

**Trade-offs:**
- Cloudflare terminates TLS, so they can see the traffic between their edge and the tunnel. Acceptable for a media server, wouldn't do this for sensitive data.
- The free tier supports 50 users, which is plenty for personal use.
- 24-hour session duration means a stolen browser session has a window. Fine for media streaming.

## Gotcha: Zero Trust Onboarding

The Cloudflare Access API returns 403 until you complete the Zero Trust onboarding in the dashboard (picking a team name). This is a one-time step that's easy to miss if you're automating from the start. Complete the onboarding wizard at `one.dash.cloudflare.com` before running the Ansible role.

## Result

`media.8devops.com` serves Jellyfin through Cloudflare's edge network, gated by email OTP. The entire setup is codified in Ansible, idempotent, and CI-safe. I can stream music from my work laptop without installing anything, and the traffic looks like normal HTTPS to any network inspection.
