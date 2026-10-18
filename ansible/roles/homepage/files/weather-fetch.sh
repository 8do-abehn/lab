#!/usr/bin/env bash
# Managed by Ansible (roles/homepage)
#
# Fetches one weather source and reshapes it into JSON the Homepage customapi
# widget can read directly (#651). Two shapes it cannot handle as-is:
#   wisconet: latest_measures is a list of ~150 readings, readable only by
#             position, where a field Wisconet adds or drops would shift every
#             row onto the wrong number without any error. Rewritten as one
#             object keyed by standard_name; a missing field shows as null.
#   forecast: a Homepage list row holds one field, so the NWS period's
#             temperature and sky are joined into one string per row.
#
# Usage: weather-fetch <wisconet|forecast> <source URL> <output file>
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
  forecast)
    # The last row says when NWS issued the forecast, since a dynamic list has
    # no separate "Updated" row. strflocaltime uses the host's time zone.
    # $p is a jq variable, so single quotes are intended.
    # shellcheck disable=SC2016
    filter='
      (.properties.periods // error("unexpected forecast response")) as $p
      | ($p[:6] | map({name, summary: "\(.shortForecast) \(.temperature)°\(.temperatureUnit)"}))
      + [{name: "Issued", summary: (.properties.updateTime | sub("\\+00:00$"; "Z") | fromdate | strflocaltime("%a %-I:%M %p"))}]'
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

# NWS rejects requests without a User-Agent and asks for a contact in it;
# Wisconet does not mind one. The unit sets WEATHER_FETCH_UA.
curl -fsS --max-time 30 -A "${WEATHER_FETCH_UA:?set WEATHER_FETCH_UA}" "$url" | jq -e "$filter" > "$tmp"

chmod 0644 "$tmp"
mv -f "$tmp" "$out"
