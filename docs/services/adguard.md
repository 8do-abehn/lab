# AdGuard Home

DNS server with ad blocking, plus Tailscale subnet router for LAN-to-Tailscale bridging.

## Where It Runs

| Property | Value |
|----------|-------|
| Host | dns01 |
| LXC ID | 3002 |
| Proxmox Node | pve01 |
| Tailscale Service | `svc:dns` |
| DNS Port | 53 |
| Web UI Port | 3000 |

IPs and Tailscale addresses are in the [inventory](../../ansible/inventory/).

## How to Connect

DNS queries go to dns01 on port 53. EdgeRouter DHCP hands it out as primary DNS to all LAN clients.

Web UI on port 3000 (no auth currently — see #289).

## What It Does

1. **DNS server** — Ad blocking, upstream to Cloudflare/Google DoH, conditional forwarding for Tailscale domains
2. **Subnet router** — Advertises all 4 LAN subnets to Tailscale (legacy, management, Ceph storage, guest/services)
3. **LAN-to-Tailscale bridge** — Lets non-Tailscale devices (Rokus, TVs) reach Tailscale Services via DNS rewrites

## Memory sizing

**These containers need 1024 MB, not 512 MB.** Both were raised on 2026-09-19 after
Netdata reported `30min_ram_swapped_out` on each, with ~220 MB sitting in swap.

The non-obvious part is that AdGuard Home is not the problem. Measured on dns01:

| Process | RSS |
|---------|-----|
| netdata + go.d.plugin | ~114 MB |
| AdGuardHome | ~47 MB |
| tailscaled | ~40 MB |

The monitoring agent uses more than twice what the service it monitors uses. 512 MB was
adequate before Netdata was added and stopped being adequate afterwards, which is easy to
miss because nothing about AdGuard changed.

Netdata's footprint scales with how much it has to watch: ~106 MB on immich01, ~290 MB on
the Minecraft hosts. Irrelevant at 32 GB, decisive at 512 MB. Check any container under
1 GB before adding it to the Netdata play in `site.yml`.

**This is not codified.** LXC memory lives in Proxmox config, not this repo, so a rebuilt
container comes back at whatever the create command specified. Set it with
`pct set <vmid> -memory 1024` (applies live, no restart).

## Ansible

- **Role:** [`adguard_home`](../../ansible/roles/adguard_home/)
- **Group vars:** [`dns_servers.yml`](../../ansible/inventory/group_vars/dns_servers.yml)
- **Inventory group:** `dns_servers`

## Known Issues

| Issue | Description |
|-------|-------------|
| [#289](https://github.com/8do-abehn/lab/issues/289) | No admin password on web UI — open to LAN |
| [#287](https://github.com/8do-abehn/lab/issues/287) | Post-deploy setup incomplete (Tailscale Service approval pending) |
| [#313](https://github.com/8do-abehn/lab/issues/313) | MagicDNS leaks into LXC resolv.conf on reboot |
