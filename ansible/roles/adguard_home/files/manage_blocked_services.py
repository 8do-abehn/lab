#!/usr/bin/env python3
"""
Reconcile AdGuard Home blocked-services list with the desired list passed via stdin.

Stdin: JSON list of service ID strings (e.g. ["youtube", "tiktok"]).
Reads/writes /opt/AdGuardHome/AdGuardHome.yaml in place.
Prints "CHANGED" if the file was modified, "OK" otherwise.
Exit non-zero on error.
"""
import json
import sys
from pathlib import Path

import yaml

CONFIG_PATH = Path("/opt/AdGuardHome/AdGuardHome.yaml")


def main() -> int:
    desired = sorted(set(json.load(sys.stdin)))

    cfg = yaml.safe_load(CONFIG_PATH.read_text())
    filtering = cfg.setdefault("filtering", {})
    blocked = filtering.setdefault("blocked_services", {})
    blocked.setdefault("schedule", {"time_zone": "Local"})
    current = sorted(set(blocked.get("ids") or []))

    if current == desired:
        print("OK")
        return 0

    blocked["ids"] = desired
    CONFIG_PATH.write_text(yaml.safe_dump(cfg, default_flow_style=False, sort_keys=False))
    print("CHANGED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
