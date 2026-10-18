#!/usr/bin/env bash
# netprobe-zones: give every zone its own network namespace (#640).
#
# The LXC gets one extra interface per VLAN, named after the zone. This moves
# each one into a namespace of the same name with a static address, a default
# route through that zone's router address and its own resolv.conf. The LXC's
# management interface keeps the only default route in the main namespace, so
# Ansible and Tailscale are unaffected, and probe traffic cannot leak out of
# the wrong interface or through Tailscale's routes.
#
# Safe to rerun: the address and route are replaced, not appended.
set -euo pipefail

conf=${1:-/etc/netprobe/zones.conf}
missing=0

if [[ ! -r $conf ]]; then
    echo "netprobe-zones: cannot read $conf" >&2
    exit 2
fi

namespace_exists() {
    ip netns list | awk '{print $1}' | grep -qx -- "$1"
}

while read -r zone addr gw dns _; do
    [[ -z ${zone:-} || $zone == \#* ]] && continue

    namespace_exists "$zone" || ip netns add "$zone"

    # Still in the main namespace on first boot, and again after the LXC
    # restarts (namespaces do not survive a restart).
    if ip link show dev "$zone" >/dev/null 2>&1; then
        ip link set dev "$zone" netns "$zone"
    fi

    if ! ip -n "$zone" link show dev "$zone" >/dev/null 2>&1; then
        echo "netprobe-zones: no interface named $zone; add it to the LXC (see the role README)" >&2
        missing=1
        continue
    fi

    ip -n "$zone" link set dev lo up
    ip -n "$zone" link set dev "$zone" up
    ip -n "$zone" addr flush dev "$zone"
    ip -n "$zone" addr add "$addr" dev "$zone"
    ip -n "$zone" route replace default via "$gw" dev "$zone"

    # ip netns exec bind-mounts this over /etc/resolv.conf inside the zone.
    mkdir -p "/etc/netns/$zone"
    printf 'nameserver %s\n' "$dns" >"/etc/netns/$zone/resolv.conf"

    echo "netprobe-zones: $zone up as $addr via $gw"
done <"$conf"

exit "$missing"
