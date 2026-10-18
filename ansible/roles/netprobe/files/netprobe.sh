#!/usr/bin/env bash
# netprobe: test the zone reachability table (#640).
#
# Each zone is a network namespace set up by netprobe-zones, holding that
# zone's VLAN interface, address, default route and resolver. Running a check
# inside the namespace makes it behave like a client plugged into that zone,
# so it crosses the EdgeRouter firewall the same way a real device would, and
# never takes the LXC's own management interface or Tailscale routes.
#
# Prints PASS/FAIL/SKIP per row. Exit codes: 0 all rows match, 1 at least one
# FAIL, 2 bad usage or a malformed table.
set -euo pipefail

table=/etc/netprobe/expected.tsv
zones_conf=/etc/netprobe/zones.conf
only_zone=""
default_dns_name=example.com

usage() {
    cat <<EOF
Usage: netprobe [-t table] [-c zones.conf] [-z zone]

  -t  expected reachability table (default $table)
  -c  zone definitions from netprobe-zones (default $zones_conf)
  -z  only test rows for this zone
EOF
}

while getopts ":t:c:z:h" opt; do
    case "$opt" in
        t) table=$OPTARG ;;
        c) zones_conf=$OPTARG ;;
        z) only_zone=$OPTARG ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

if [[ $EUID -ne 0 ]]; then
    echo "netprobe: must run as root (ip netns exec needs it)" >&2
    exit 2
fi

for f in "$table" "$zones_conf"; do
    if [[ ! -r $f ]]; then
        echo "netprobe: cannot read $f" >&2
        exit 2
    fi
done

# Gateways, so a row can say "gateway" instead of hardcoding each zone's
# router address. Zones whose subnet is not decided yet still get rows.
declare -A gateway=()
while read -r zone _addr gw _dns; do
    [[ -z ${zone:-} || $zone == \#* ]] && continue
    gateway[$zone]=$gw
done <"$zones_conf"

# Namespaces that exist right now. A zone without one is SKIPped rather than
# failed, so rows for zones that are planned but not built yet can live in the
# table ahead of time.
declare -A have_ns=()
while read -r ns _; do
    [[ -n ${ns:-} ]] && have_ns[$ns]=1
done < <(ip netns list)

pass=0 fail=0 skip=0 lineno=0

while IFS= read -r line || [[ -n $line ]]; do
    lineno=$((lineno + 1))

    # Anything after # is a note, printed with the result.
    fields=${line%%#*}
    note=""
    [[ $line == *#* ]] && note=${line#*#}
    note=${note#"${note%%[![:space:]]*}"}

    read -r zone target port check expect name _extra <<<"$fields" || true
    [[ -z ${zone:-} ]] && continue

    if [[ -z ${expect:-} ]]; then
        echo "netprobe: $table:$lineno: need at least 5 columns: zone target port check expect" >&2
        exit 2
    fi
    if [[ ! $port =~ ^[0-9]+$ ]]; then
        echo "netprobe: $table:$lineno: port '$port' is not a number" >&2
        exit 2
    fi
    if [[ $expect != allow && $expect != deny ]]; then
        echo "netprobe: $table:$lineno: expect must be allow or deny, not '$expect'" >&2
        exit 2
    fi
    if [[ $check != tcp && $check != dns ]]; then
        echo "netprobe: $table:$lineno: check must be tcp or dns, not '$check'" >&2
        exit 2
    fi

    [[ -n $only_zone && $zone != "$only_zone" ]] && continue

    label="$zone -> $target:$port/$check"
    [[ $check == dns ]] && label="$label ${name:-$default_dns_name}"

    if [[ -z ${have_ns[$zone]:-} ]]; then
        printf 'SKIP  %-50s no namespace for zone %s\n' "$label" "$zone"
        skip=$((skip + 1))
        continue
    fi

    if [[ $target == gateway ]]; then
        if [[ -z ${gateway[$zone]:-} ]]; then
            echo "netprobe: $table:$lineno: zone '$zone' has no gateway in $zones_conf" >&2
            exit 2
        fi
        target=${gateway[$zone]}
        label="$zone -> $target:$port/$check"
        [[ $check == dns ]] && label="$label ${name:-$default_dns_name}"
    fi

    # Any reply counts as reachable: a REFUSED DNS answer still proves the
    # firewall let the packet through. A REJECT or a timeout counts as deny.
    if [[ $check == tcp ]]; then
        if ip netns exec "$zone" nc -z -w2 "$target" "$port" >/dev/null 2>&1; then
            got=allow
        else
            got=deny
        fi
    else
        if ip netns exec "$zone" dig +time=2 +tries=1 -p "$port" "@$target" "${name:-$default_dns_name}" >/dev/null 2>&1; then
            got=allow
        else
            got=deny
        fi
    fi

    if [[ $got == "$expect" ]]; then
        result=PASS
        pass=$((pass + 1))
    else
        result=FAIL
        fail=$((fail + 1))
    fi
    printf '%s  %-50s expect %-5s got %-5s %s\n' "$result" "$label" "$expect" "$got" "${note:+# $note}"
done <"$table"

echo "netprobe: $pass passed, $fail failed, $skip skipped"
[[ $fail -eq 0 ]]
