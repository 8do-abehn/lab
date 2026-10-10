#!/usr/bin/env bash
set -euo pipefail

# Log UPS telemetry to CSV during a deliberate battery discharge (#487).
#
# Run it on the host the UPS serial cable is attached to, inside tmux, so the
# log keeps going if the SSH session or the network drops mid-test.
#
# Read-only. It only ever calls `upsc`, never `upscmd`, `upsrw` or `upsmon`,
# so it cannot change anything on the UPS or start a shutdown.
#
# Usage: ups-discharge-log.sh [interval_seconds] [output.csv]
#
# Optional: KP115_HOST=<address> adds plug_w and plug_wh columns from a Kasa
# KP115 metering the dummy load, read through kp115-read.py next to this
# script. That replaces reading a meter by eye every few minutes, and puts the
# true output watts in the same row as the battery voltage.
#
# Stopping the test is a human restoring mains, and a person watching a
# scrolling log misses things, so it also flags the stop conditions loudly:
#   WARN      battery.voltage <= WARN_V (default 50.0)
#   STOP      battery.voltage <= STOP_V (default 49.0), the hard stop. 49 rather than
#             48 because nobody can reach the battery terminals to check the
#             register or a weak unit; see RUNTIME-TEST.md
#   COLLAPSE  voltage fell by >= COLLAPSE_STEP_V (default 1.0) in one sample,
#             once SETTLE_S (default 15) seconds on battery have passed. A pack
#             running down sags gradually; a step like this means a BMS tripped
#             or a connection opened. The settle window exists because the
#             transfer itself drops the string from float to loaded voltage in
#             one step, which is normal
#   NODATA    upsc failed or upsd reports stale data. If the UPS output just
#             died, this is what it looks like from here

UPS="${UPS:-myups@localhost}"
INTERVAL="${1:-2}"
OUT="${2:-/root/ups-discharge-$(date +%Y%m%d-%H%M%S).csv}"
WARN_V="${WARN_V:-50.0}"
STOP_V="${STOP_V:-49.0}"
COLLAPSE_STEP_V="${COLLAPSE_STEP_V:-1.0}"
SETTLE_S="${SETTLE_S:-15}"
KP115_HOST="${KP115_HOST:-}"
KP115_READER="${KP115_READER:-$(dirname "$0")/kp115-read.py}"

FIELDS=(ups.status battery.voltage battery.charge battery.runtime ups.load input.voltage output.voltage ups.temperature)

# Two runs interleaved in one file would make the discharge curve meaningless
if [ -e "$OUT" ]; then
	echo "refusing to overwrite existing $OUT" >&2
	exit 1
fi

# Float comparisons, since bash arithmetic is integer only
le() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a <= b) }'; }
dropped_by() { awk -v prev="$1" -v cur="$2" -v step="$3" 'BEGIN { exit !(prev - cur >= step) }'; }

# One upsc call per sample, so every column in a row comes from the same
# driver state rather than from eight polls a few milliseconds apart
field() { printf '%s\n' "$snapshot" | awk -F': ' -v k="$1" '$1 == k { print $2 }'; }

if [ -n "$KP115_HOST" ] && [ ! -r "$KP115_READER" ]; then
	echo "KP115_HOST is set but $KP115_READER is missing" >&2
	exit 1
fi

header="epoch,iso_time,elapsed_ob_s"
for f in "${FIELDS[@]}"; do header+=",$f"; done
echo "${header},plug_w,plug_wh,flag" > "$OUT"
echo "logging ${UPS} every ${INTERVAL}s to ${OUT} (WARN<=${WARN_V}V STOP<=${STOP_V}V)"

ob_since=""
prev_v=""

while true; do
	now=$(date +%s)
	iso=$(date --iso-8601=seconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')
	flag=""

	if snapshot=$(upsc "$UPS" 2>/dev/null); then
		values=()
		for f in "${FIELDS[@]}"; do values+=("$(field "$f")"); done
		status="${values[0]}"
		volts="${values[1]}"
	else
		snapshot=""
		values=()
		for _ in "${FIELDS[@]}"; do values+=(""); done
		status=""
		volts=""
		flag="NODATA"
	fi

	# Elapsed time is counted from the first sample showing OB and resets on
	# line power, matching how the shutdown watchdog counts
	if [[ " ${status} " == *" OB "* ]]; then
		[ -n "$ob_since" ] || ob_since=$now
		elapsed=$(( now - ob_since ))
	else
		[ -z "$status" ] || ob_since=""
		elapsed=""
	fi

	if [ -n "$volts" ]; then
		if [ -n "$prev_v" ] && [ "${elapsed:-0}" -ge "$SETTLE_S" ] && dropped_by "$prev_v" "$volts" "$COLLAPSE_STEP_V"; then
			flag="COLLAPSE"
		elif le "$volts" "$STOP_V"; then
			flag="STOP"
		elif le "$volts" "$WARN_V"; then
			flag="WARN"
		fi
		prev_v="$volts"
	fi

	# The reader prints "," on any failure, so a plug dropping off Wi-Fi costs
	# two empty cells, never the battery row
	plug=","
	if [ -n "$KP115_HOST" ]; then
		plug=$(python3 "$KP115_READER" "$KP115_HOST" 1.5)
	fi

	row="${now},${iso},${elapsed}"
	for v in "${values[@]}"; do row+=",${v}"; done
	echo "${row},${plug},${flag}" >> "$OUT"

	printf '%s  ob=%5ss  %-8s V=%-6s chg=%-5s load=%-5s rt=%-4s plugW=%-6s %s\n' \
		"$(date +%H:%M:%S)" "${elapsed:--}" "${status:-?}" "${volts:-?}" \
		"${values[2]:-?}" "${values[4]:-?}" "${values[3]:-?}" "${plug%%,*}" "$flag"

	case "$flag" in
		STOP | COLLAPSE | NODATA)
			printf '\a'
			echo "*** ${flag}: end the discharge now (see RUNTIME-TEST.md) ***"
			;;
	esac

	sleep "$INTERVAL"
done
