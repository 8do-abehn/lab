# homepage

[Homepage](https://gethomepage.dev) as the lab's service dashboard, at
`https://home.<tailnet>`. It runs in Docker on mem01 (`dashboard_servers`),
bound to loopback, and is published as the Tailscale Service `svc:home`.

## How names work, on the tailnet and on the default LAN

There is no separate reverse proxy. `tailscale serve` is the proxy: each
service is a Tailscale Service (`svc:<name>`) that terminates TLS with a
certificate Tailscale issues for `<name>.<tailnet>` and forwards to the app
on loopback. The units come from `tailscale_serve_services` (roles/tailscale).

| Name | Served by | Upstream |
|------|-----------|----------|
| `home` | mem01 | Homepage, `127.0.0.1:3010` |
| `chat` | mem01 | Open WebUI, `127.0.0.1:3000` |
| `proxmox` | pve01, pve02, pve03 | `https+insecure://127.0.0.1:8006` |
| `unifi` | unifi | `https+insecure://127.0.0.1:8443` |
| `jellyfin` | jellyfin01 | already existed |
| `immich` | immich01 | already existed |
| `dns` | dns01, dns02 | already existed (adguard_home role) |
| `mem0` | mem01 | already existed (mem0 role) |

- **Tailnet devices** resolve these through MagicDNS as usual.
- **Default-LAN devices** (no Tailscale) get AdGuard from DHCP. AdGuard
  forwards the tailnet zone to `100.100.100.100`
  (`adguard_home_conditional_forwards` in `group_vars/dns_servers.yml`), so
  they get the same 100.x answer. The router's `100.64.0.0/10` static route
  sends that traffic to dns01, which forwards and masquerades it into the
  tailnet. The certificate is valid either way.
- AdGuard's rewrites take precedence over the forward, so host names such as
  `jellyfin01.<tailnet>` still resolve to the LAN IP.

## One-time setup before the first deploy

A Tailscale Service has to exist in the admin console before a host can serve
it, and a host's advertisement has to be approved.

1. Admin console, Services: define `home`, `chat`, `proxmox` and `unifi`,
   each with endpoint `tcp:443`.
2. Approve the hosts when they advertise, or add auto-approval to the policy
   file so rebuilds need no clicks:

   ```jsonc
   "autoApprovers": {
     "services": {
       "svc:home":    ["tag:mem0"],
       "svc:chat":    ["tag:mem0"],
       "svc:proxmox": ["tag:proxmox"],
       "svc:unifi":   ["tag:unifi"],
     },
   },
   ```

3. Access: the current policy grants `*` to `*`, which covers services. If
   that is ever narrowed, grant `tag:dns` (the subnet router the LAN comes
   through) and your users access to these `svc:` names.

Then deploy from `main`:

```bash
ansible-playbook -i inventory/homelab.yml site.yml --limit 'proxmox:unifi_servers:mem0_servers:dns_servers'
```

If a service is not defined yet, its `tailscale-serve-<name>` unit can fail,
and the play fails on that host. Define it, then re-run.

## Changing the dashboard

Everything on the page is in `defaults/main.yml`, written in Homepage's own
format: `homepage_services`, `homepage_bookmarks`, `homepage_widgets` and
`homepage_settings`. Homepage reloads its config files on change, so a
config-only deploy needs no restart.

To add a service, publish it as a Tailscale Service on the host that runs it
(`tailscale_serve_services` in its host or group vars), define it in the admin
console, and add a tile here with `href: https://<name>.{{ tailnet_domain }}`.

## Status dots

`siteMonitor` checks run from the Homepage container, not the browser. mem01
runs with `--accept-dns=false`, so the container uses AdGuard
(`homepage_dns`) to resolve tailnet names.
