#!/usr/bin/env python3
"""
Reconcile AdGuard Home blocked-services list with the desired list passed via stdin.

Stdin: JSON list of service ID strings (e.g. ["youtube", "tiktok"]).
Reads/writes /opt/AdGuardHome/AdGuardHome.yaml in place, replacing only the
keys it manages (agh_config.py, #605).
Prints "CHANGED" if the file was modified, "OK" otherwise.
Exit non-zero on error.
"""
import copy
import json
import sys
from pathlib import Path

import yaml

from agh_config import write_config

CONFIG_PATH = Path("/opt/AdGuardHome/AdGuardHome.yaml")


def main() -> int:
    desired = sorted(set(json.load(sys.stdin)))

    text = CONFIG_PATH.read_text()
    cfg = yaml.safe_load(text)
    filtering = cfg.setdefault("filtering", {})
    had_block = "blocked_services" in filtering
    blocked = filtering.setdefault("blocked_services", {})
    had_schedule = "schedule" in blocked
    blocked.setdefault("schedule", {"time_zone": "Local"})
    current = sorted(set(blocked.get("ids") or []))

    if current == desired:
        print("OK")
        return 0

    blocked["ids"] = desired
    if had_block:
        edits = [(("filtering", "blocked_services", "ids"), desired)]
        if not had_schedule:
            edits.append((("filtering", "blocked_services", "schedule"), blocked["schedule"]))
    else:
        # No block yet: write it whole, schedule default included.
        edits = [(("filtering", "blocked_services"), copy.deepcopy(blocked))]
    write_config(CONFIG_PATH, text, edits, cfg)
    print("CHANGED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
