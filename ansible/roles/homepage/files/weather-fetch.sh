#!/usr/bin/env bash
# Managed by Ansible (roles/homepage)
#
# Fetches one weather source and reshapes it into JSON the Homepage customapi
# widget can read directly (#651):
#   wisconet: latest_measures is a list of ~150 readings, readable only by
#             position, where a field Wisconet adds or drops would shift every
#             row onto the wrong number without any error. Rewritten as one
#             object keyed by standard_name; a missing field shows as null.
#
# Usage: weather-fetch wisconet <source URL> <output file>
set -euo pipefail

kind="$1"
url="$2"
out="$3"

case "$kind" in
  wisconet)
    # collection_time differs per field (daily totals are stamped with the
    # end of their day), so "Updated" uses the 5-minute air temperature's.
    filter='
      if type == "array" and length > 0 then
        (map({key: .standard_name, value: .value}) | from_entries)
        + {collection_time: (map(select(.standard_name == "5min_air_temp_f_avg"))[0].collection_time)}
      else
        error("unexpected latest_measures response")
      end'
    ;;
  *)
    echo "unknown kind: $kind" >&2
    exit 2
    ;;
esac

# Written next to the target and renamed over it, so the web server never
# serves a half-written file. On any failure the previous file stays in place.
tmp="$(mktemp "${out}.XXXXXX")"
trap 'rm -f "$tmp"' EXIT

# A User-Agent with a contact, as public APIs ask. The unit sets it.
curl -fsS --max-time 30 -A "${WEATHER_FETCH_UA:?set WEATHER_FETCH_UA}" "$url" | jq -e "$filter" > "$tmp"

chmod 0644 "$tmp"
mv -f "$tmp" "$out"
