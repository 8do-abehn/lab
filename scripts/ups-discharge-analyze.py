#!/usr/bin/env python3
"""Turn a ups-discharge-log.sh CSV into proposed NUT thresholds (#487).

Stdlib only, so it runs on the Mac or on pve01 as is.

Usage:
  ups-discharge-analyze.py run.csv --test-watts 700 [--worst-load-pct 48]

--test-watts is the AC meter reading on the dummy load during the discharge.
Everything else derives from the log. The method is explained in
ansible/roles/nut/RUNTIME-TEST.md, "Turning the log into thresholds"; the
numbers printed here are a proposal for a human to check, not a decision.
"""

import argparse
import csv
import math
import sys

UPS_WATTS = 1600  # SU2200 rating plate
UPS_VA = 2200
# Lowest battery.charge ever read on mains (#536). A charge threshold must sit
# well below it or LB can assert on line power again.
LOWEST_ON_MAINS_CHARGE = 84


def num(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def load_ob_run(path):
    """Return the longest contiguous run of on-battery rows."""
    runs, current = [], []
    with open(path, newline="") as fh:
        for row in csv.DictReader(fh):
            row["epoch"] = int(row["epoch"])
            if row["elapsed_ob_s"] != "" or (current and row["flag"] == "NODATA"):
                current.append(row)
            elif current:
                runs.append(current)
                current = []
    if current:
        runs.append(current)
    if not runs:
        sys.exit("no on-battery samples in the log")
    return max(runs, key=len)


def find_end(run, stop_v):
    """First sample where the test should have ended, and why."""
    for i, row in enumerate(run):
        # A lone stale poll that on-battery samples follow is a driver hiccup,
        # not the UPS output dying, so only a trailing NODATA ends the run
        if row["flag"] == "NODATA" and any(r["elapsed_ob_s"] for r in run[i + 1:]):
            continue
        if row["flag"] in ("COLLAPSE", "NODATA"):
            return row, row["flag"]
        v = num(row["battery.voltage"])
        if v is not None and v <= stop_v:
            return row, f"battery.voltage <= {stop_v}"
    return run[-1], "mains restored before the hard stop"


def sample_at(run, epoch):
    return min(run, key=lambda r: abs(r["epoch"] - epoch))


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("csv")
    p.add_argument("--test-watts", type=float, required=True, help="AC meter watts on the dummy load")
    p.add_argument("--worst-watts", type=float, help="worst realistic cluster load in watts")
    p.add_argument("--worst-load-pct", type=float, help="or: worst realistic ups.load, converted via the measured basis")
    p.add_argument("--stop-v", type=float, default=48.0)
    p.add_argument("--shutdown-budget", type=int, default=180, help="seconds from FSD to UPS output off, with margin")
    p.add_argument("--derate", type=float, default=0.8, help="capacity kept for ageing, temperature, one-sample error")
    p.add_argument("--delay-cap", type=int, default=300, help="policy ceiling on ups_onbatt_shutdown_delay")
    args = p.parse_args()

    run = load_ob_run(args.csv)
    t0 = run[0]["epoch"]
    end, reason = find_end(run, args.stop_v)
    t_meas = end["epoch"] - t0
    if t_meas <= 0:
        sys.exit("on-battery run is too short to analyse")
    run = [r for r in run if r["epoch"] <= end["epoch"]]

    loads = [num(r["ups.load"]) for r in run if num(r["ups.load"])]
    mean_load = sum(loads) / len(loads)
    implied = args.test_watts / (mean_load / 100)
    basis = "watts (of 1600 W)" if abs(implied - UPS_WATTS) < abs(implied - UPS_VA) else "VA (of 2200 VA)"
    rating = UPS_WATTS if basis.startswith("watts") else UPS_VA

    volts = sorted({num(r["battery.voltage"]) for r in run if num(r["battery.voltage"]) is not None})
    steps = [round(b - a, 3) for a, b in zip(volts, volts[1:]) if b - a > 0]
    v_step = min(steps) if steps else None

    if args.worst_watts:
        p_worst = args.worst_watts
    elif args.worst_load_pct:
        # The dummy load is resistive (PF 1), so W == VA there and the implied
        # rating converts a percentage reading straight into watts
        p_worst = args.worst_load_pct / 100 * rating
    else:
        p_worst = args.test_watts

    print(f"On battery: {t_meas}s ({t_meas / 60:.1f} min), ended by: {reason}")
    print(f"Mean ups.load {mean_load:.1f}% at {args.test_watts:.0f} W -> implied rating {implied:.0f}, ups.load is a % of {basis}")
    print(f"Approx energy delivered: {args.test_watts * t_meas / 3600:.0f} Wh AC (pack rated ~920 Wh DC)")
    print(f"battery.voltage resolution: smallest step {v_step} V across {len(volts)} distinct values")
    print()
    print(" min    V      charge  load   runtime  status")
    for minute in range(0, t_meas // 60 + 1, 5):
        r = sample_at(run, t0 + minute * 60)
        print(f"{minute:4d}  {r['battery.voltage']:>6}  {r['battery.charge']:>6}  {r['ups.load']:>5}  {r['battery.runtime']:>7}  {r['ups.status']}")
    print()

    lb = next((r for r in run if " LB " in f" {r['ups.status']} "), None)
    if lb:
        left = end["epoch"] - lb["epoch"]
        print(f"NUT LB (charge < battery.charge.low) first set at {lb['epoch'] - t0}s, {left}s before the end at this load")
    else:
        print("NUT LB never set during the run: the current charge threshold gave NO warning")

    t_worst = t_meas * args.test_watts / p_worst
    t_usable = args.derate * t_worst
    budget = args.shutdown_budget
    # Two back-to-back outages must both fit, because the timer assumes a full
    # pack and the charger refills slowly
    delay_max = int(t_usable / 2 - budget)
    delay = max(60, min(delay_max, args.delay_cap) // 60 * 60)
    print()
    print(f"Worst-case load {p_worst:.0f} W -> runtime {t_worst / 60:.1f} min, usable after x{args.derate} derate {t_usable / 60:.1f} min")
    print(f"ups_onbatt_shutdown_delay ceiling = usable/2 - {budget}s budget = {delay_max}s")
    if delay_max < 60:
        print("  !! ceiling is below 60s: the pack cannot cover the shutdown budget twice. Keep 60 and raise this in #487")
    else:
        print(f"  proposed ups_onbatt_shutdown_delay: {delay}  (capped at {args.delay_cap}s by policy)")

    # Energy the cluster needs to still be in the pack when LB fires: two full
    # shutdown budgets at worst-case load, re-expressed as time at test load
    reserve_test = 2 * budget * p_worst / args.test_watts / args.derate
    at = sample_at(run, end["epoch"] - reserve_test)
    charge = num(at["battery.charge"])
    print()
    print(f"Reserve point: {reserve_test:.0f}s before the end at test load -> charge {at['battery.charge']}, voltage {at['battery.voltage']}")
    ceiling = LOWEST_ON_MAINS_CHARGE - 10
    if charge is None:
        print("  no charge reading there, cannot propose ups_charge_low")
    elif charge > ceiling:
        print(f"  charge is still above {ceiling} there, so it does not track the pack usefully: keep ups_charge_low at 50")
        print(f"  and consider a voltage condition in ups_is_critical() at >= {at['battery.voltage']} V (only while OB)")
    else:
        proposed = max(math.ceil(charge), 50)
        print(f"  proposed ups_charge_low: {proposed}  (integer, never below the current 50, never above {ceiling})")


if __name__ == "__main__":
    main()
