# AdGuard Home

DNS server with ad blocking, plus Tailscale subnet router for LAN-to-Tailscale bridging.

## Where It Runs

| Property | Value |
|----------|-------|
| Host | dns01 |
| LXC ID | 3002 |
| Proxmox Node | pve01 |
| IP | 10.150.60.11 |
| Tailscale Service | `svc:dns` |
| Address | `dns.taile975f.ts.net` |
| Web UI | `http://10.150.60.11:3000` |

## How to Connect

DNS queries go to `10.150.60.11:53`. EdgeRouter DHCP hands this out as primary DNS to all LAN clients.

Web UI at `http://10.150.60.11:3000` (no auth currently — see #289).

## What It Does

1. **DNS server** — Ad blocking, upstream to Cloudflare/Google DoH, conditional forwarding for `*.taile975f.ts.net` to Tailscale (`100.100.100.100`)
2. **Subnet router** — Advertises all 4 LAN subnets to Tailscale:
   - `10.150.10.0/24` (legacy cluster)
   - `10.150.60.0/24` (new cluster management)
   - `10.150.65.0/24` (Ceph storage)
   - `10.150.70.0/24` (guest/services)
3. **LAN-to-Tailscale bridge** — Lets non-Tailscale devices (Rokus, TVs) reach Tailscale Services via DNS rewrites

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
