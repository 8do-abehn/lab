# netprobe

Phase 2 of the network zones plan (#414, #640). Turns the zone reachability
matrix into a test that can be rerun after every firewall change.

- `files/expected.tsv`: the expected table, zone -> target:port -> allow/deny.
  It describes the rules as they are. A PR that changes a router rule changes
  the matching rows in the same PR.
- `files/netprobe.sh` (installed as `/usr/local/bin/netprobe`): runs every row
  from inside its zone, prints PASS/FAIL/SKIP and exits 1 on any FAIL.
- `files/netprobe-zones.sh` (`/usr/local/sbin/netprobe-zones`, run at boot by
  `netprobe-zones.service`): moves each zone's interface into a network
  namespace of the same name, with a static address, a default route through
  the zone's router address and its own resolver.

## Why namespaces

A check run from a namespace behaves like a client plugged into that zone: its
only route is the zone's gateway, so traffic to another VLAN crosses the
EdgeRouter firewall exactly as a phone or TV would. The LXC's management
interface keeps the only default route in the main namespace, so Ansible and
Tailscale work normally, and no probe can slip out through the wrong interface
or through a Tailscale route. Binding a source address instead would need
policy routing plus loose rp_filter to do the same thing.

## Run it

```
netprobe                 # every row
netprobe -z guests       # one zone
```

Rows for zones with no namespace are SKIPped, so planned zones (Work,
Untrusted, Kids) can have rows before they exist.

## Bootstrap (once, by hand)

1. Create a small Debian 13 LXC (`netprobe01`), management interface `net0`
   on VLAN 60 as usual, with `features: nesting=1`. Before going further,
   check that it can make namespaces: `ip netns add t && ip netns del t`.
2. Add one interface per zone, named after the zone, with no IP set in
   Proxmox (the role assigns it), for example
   `pct set <id> --net1 name=trusted,bridge=vmbr0,tag=10`.
   Only VLANs in `proxmox_bridge_vids` (currently `10 65 70`) reach a guest.
   IoT (20), Guests (25), Kids (30), Work (40) and Untrusted (666) need adding
   there first, which reloads vmbr0 on every node, and the switch ports to
   the nodes must carry them.
3. Register it on the tailnet like the other LXCs (Tailscale needs
   `/dev/net/tun` in the LXC config, see CLAUDE.md), and allow `tag:ci` to SSH
   to its tag.
4. Uncomment it in `inventory/homelab.yml` and set `netprobe_zones` in
   `inventory/group_vars/netprobe_hosts.yml` for the interfaces it has.
5. Deploy with `--tags netprobe`, then run `netprobe` on it.
