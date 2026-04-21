---
title: "IP Registration Lessons: IPv6, TTL Auto-Renewal, and SSO That Wasn't Worth It"
date: 2026-04-20
draft: false
tags: ["cloudflare", "jellyfin", "media-server", "ipv6", "workers"]
description: "Follow-up to the Cloudflare IP registration system: handling IPv6 privacy extensions, auto-renewing TTLs from audit logs, and why SSO wasn't worth the complexity."
---

After deploying the self-service IP registration system for family Jellyfin access, three things came up within the first day of real-world testing.

## IPv6 Privacy Extensions Break Registration

The first family member to register got an IPv6 address. The Worker stored it with a `/128` (exact match), but when she visited `media.8devops.com`, her phone used a different IPv6 address. IPv6 privacy extensions rotate the interface identifier (the last 64 bits) on every connection to prevent tracking.

The fix: register the `/64` prefix instead of the full address. The first four groups of an IPv6 address identify the network, and all devices on the same home network share that prefix. The Worker now detects IPv6 and truncates to the network prefix:

```javascript
if (ip.includes(":")) {
  const prefix = ip.split(":").slice(0, 4).join(":") + "::/64";
  includeRules.push({ ip: { ip: prefix } });
} else {
  includeRules.push({ ip: { ip: ip + "/32" } });
}
```

This covers any device on the family member's home network, regardless of address rotation.

## Auto-Renewing TTLs from Audit Logs

The original design expired registered IPs after 45 days. A family member streaming every day would still have to re-register every 45 days. That's unnecessary friction.

The scheduled Worker (daily cron at 3am UTC) now queries Cloudflare Access audit logs for the Jellyfin app, finds IPs that were active in the last 24 hours, and refreshes their KV TTL. Active users never expire. Inactive IPs still drop off after 45 days of no activity.

Key details:
- Audit logs are filtered by `app_uid` to only count Jellyfin activity, not visits to the registration page
- KV writes are minimal (1 per active IP per day, well under the 1,000/day free tier limit)
- Failed API responses are logged to Worker logs for debugging
- If the audit log API isn't available on the free tier, the function logs and exits gracefully without affecting existing registrations

## SSO: Not Worth It

I evaluated Cloudflare Access OIDC with the Jellyfin SSO plugin to eliminate the Jellyfin login after OTP authentication. The idea was single sign-on: authenticate once through Cloudflare, automatically logged into Jellyfin.

After thinking through the access paths, SSO only benefits one scenario: browser access through Cloudflare (my work laptop). Family members on Rokus use IP bypass and log into Jellyfin with saved credentials on the device. Personal devices use Tailscale and also have saved Jellyfin credentials.

SSO would save one click on a saved password, in exchange for maintaining a community Jellyfin plugin that could break on updates. Not worth the complexity. Closed the issue.

## Current Access Flow

The system now handles all access scenarios:

- **Browser from managed device:** OTP at Cloudflare, then Jellyfin login (saved password)
- **Family Roku/Apple TV:** Register IP once every 45 days (auto-renewed if active), then Jellyfin login (saved on device)
- **Personal devices:** Tailscale direct, Jellyfin login
- **No open firewall ports, no VPN installs, no port forwarding**

Everything runs on Cloudflare's free tier and is managed through two Ansible roles.
