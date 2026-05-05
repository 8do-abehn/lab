#!/usr/bin/env python3
"""
Reconcile AdGuard Home DNS rewrites with the desired list passed via stdin.

Stdin: JSON list of {"domain": str, "answer": str} objects (the desired state).
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
    desired = json.load(sys.stdin)
    desired_normalized = sorted(
        [{"domain": r["domain"], "answer": r["answer"], "enabled": True} for r in desired],
        key=lambda r: (r["domain"], r["answer"]),
    )

    cfg = yaml.safe_load(CONFIG_PATH.read_text())
    filtering = cfg.setdefault("filtering", {})
    current = filtering.get("rewrites") or []
    current_normalized = sorted(
        [
            {"domain": r["domain"], "answer": r["answer"], "enabled": r.get("enabled", True)}
            for r in current
        ],
        key=lambda r: (r["domain"], r["answer"]),
    )

    if current_normalized == desired_normalized:
        print("OK")
        return 0

    filtering["rewrites"] = desired_normalized
    CONFIG_PATH.write_text(yaml.safe_dump(cfg, default_flow_style=False, sort_keys=False))
    print("CHANGED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
