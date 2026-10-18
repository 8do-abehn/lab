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
| `network` | unifi | `https+insecure://127.0.0.1:8443` |
| `jellyfin` | jellyfin01 | Jellyfin, `127.0.0.1:8096` |
| `immich` | immich01 | Immich, `127.0.0.1:2283` |
| `dns` | dns01, dns02 | AdGuard UI, `127.0.0.1:3000` (adguard_home role) |
| `mem0` | mem01 | OpenMemory, `127.0.0.1:8090` (mem0 role) |

- **Tailnet devices** resolve these through MagicDNS as usual.
- **Default-LAN devices** (no Tailscale) get the router as their DNS server
  from DHCP, not AdGuard, and the router forwards to public resolvers that
  cannot answer for the tailnet zone. Two settings on the router, both set by
  hand (the router is not managed by Ansible):
  - DNS: forward only the tailnet zone to AdGuard on dns01 and dns02,
    `set service dns forwarding options server=/<tailnet>/<dns01 IP>` (and
    the same for dns02). AdGuard forwards it on to `100.100.100.100`
    (`adguard_home_conditional_forwards` in `group_vars/dns_servers.yml`), so
    LAN devices get the same 100.x answer as tailnet devices.
  - Routing: `set protocols static route 100.64.0.0/10 next-hop <dns01 IP>`.
    Without it the router sends 100.x traffic out the WAN. dns01 is the
    subnet router and masquerades it into the tailnet. One next-hop only:
    EdgeOS does not notice a dead static next-hop, so a second one would
    black-hole half the connections whenever either host is down.

  The certificate is valid either way. Check from a LAN device with
  `traceroute <a 100.x service address>`: the hop after the router must be
  dns01.
- AdGuard's rewrites take precedence over the forward, so host names such as
  `jellyfin01.<tailnet>` still resolve to the LAN IP.

## One-time setup before the first deploy

A Tailscale Service has to exist in the admin console before a host
advertises it, and each host's advertisement has to be approved.

1. Admin console, Services: define every name in the table above that is
   missing, each with endpoint `tcp:443`. Check the list, not this README:
   on 2026-10-10 `immich` turned out never to have been defined, although
   immich01 had been advertising it for weeks.
2. Approve the hosts when they advertise, or add auto-approval to the policy
   file so rebuilds need no clicks:

   ```jsonc
   "autoApprovers": {
     "services": {
       "svc:home":     ["tag:mem0"],
       "svc:chat":     ["tag:mem0"],
       "svc:mem0":     ["tag:mem0"],
       "svc:proxmox":  ["tag:proxmox"],
       "svc:network":  ["tag:unifi"],
       "svc:dns":      ["tag:dns"],
       "svc:immich":   ["tag:immich"],
       "svc:jellyfin": ["tag:media"],
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

### A service shows "0 hosts" or "Not advertising the service"

- **0 hosts, though the host serves it:** the host advertised before the
  service was defined, and the control plane dropped that advertisement. The
  host will not send it again on its own. Restart the unit on the host
  (`systemctl restart tailscale-serve-<name>`), then approve it.
- **Resolves, but HTTPS times out:** the host is waiting for approval.
- **Not advertising the service:** check `tailscale debug prefs | jq
  .AdvertiseServices` on the host. dns01 had its serve config but an empty
  list (#614). Re-running the serve command restores it.
- **A service name equal to a machine name never works.** MagicDNS answers
  `<name>.<tailnet>` with the machine's address. That is why the UniFi UI is
  `svc:network`, not `svc:unifi` (the machine is `unifi`).

## Changing the dashboard

Everything on the page is in `defaults/main.yml`, written in Homepage's own
format: `homepage_services`, `homepage_bookmarks`, `homepage_widgets` and
`homepage_settings`. Homepage reloads its config files on change, so a
config-only deploy needs no restart.

To add a service, publish it as a Tailscale Service on the host that runs it
(`tailscale_serve_services` in its host or group vars), define it in the admin
console, and add a tile here with `href: https://<name>.{{ tailnet_domain }}`.

## Weather

The Weather section has three tiles, and none of its sources needs an API key:

| Tile | Source | Fetched by |
|------|--------|------------|
| Arthur | [Wisconet](https://wisconet.wisc.edu/data/api) station `homepage_wisconet_station`, 5-minute readings | mem01 timer |
| Forecast | NWS alerts for the point, then the gridpoint forecast as a table of `homepage_forecast_days` days | your browser |
| Radar | NWS radar loop GIF for `homepage_radar_site`, scaled by an inline page | your browser |

The header also shows Open-Meteo's current conditions for the same
coordinates, fetched by the Homepage container.

**Arthur.** Wisconet's `latest_measures` is a list of about 150 readings,
which `customapi` could only read by position. For each entry in
`homepage_weather_fetches`, a `weather-fetch-<name>.timer` on mem01 runs
`files/weather-fetch.sh`, which reshapes the source into
`/opt/homepage/weather/<name>.json`. A busybox `httpd` container in the same
compose project serves those files to Homepage at
`http://weather:8080/<name>.json`, with no port published on the host.

- A row showing `null`: Wisconet renamed or dropped that field. List the
  current names with `jq 'keys' /opt/homepage/weather/wisconet.json`.
- "Updated" stuck in the past: the fetch is failing and the last good file is
  still being served. Check `systemctl status weather-fetch-wisconet.service`.

**Forecast and Radar** are small HTML pages inlined into `iframe` tiles as
`data:` URLs, so the browser does the fetching. Homepage list rows hold one
value each, which rules out a table there. The Forecast page is
`templates/forecast-table.html.j2`: it groups NWS's 12-hour periods by date
into day, sky, high, low and rain chance. NWS allows requests from any origin.

- The Forecast tile also shows active NWS alerts for the point
  (`homepage_nws_alerts_url`) above the table, colored by severity, one row
  per event type, at most 2 plus "+N more". Each links to the NWS point page
  with the full text. With none, the bottom line says "No active alerts".
- "Forecast unavailable" or "Alerts unavailable": NWS answered with an error,
  or the browser could not reach it. The tile retries every 5 minutes and on
  page reload.
- A fetch job dropped from `homepage_weather_fetches` goes into
  `homepage_weather_fetches_removed`, so the role removes its units from mem01.

## Status dots

`siteMonitor` checks run from the Homepage container, not the browser. mem01
runs with `--accept-dns=false`, so the container uses AdGuard
(`homepage_dns`) to resolve tailnet names.
