#!/usr/bin/env python3
"""Reconcile AdGuard Home users from JSON on stdin.

Stdin: JSON list of {"name": str, "password": str} objects (plaintext passwords).
Reads/writes /opt/AdGuardHome/AdGuardHome.yaml in place.
Prints "CHANGED" if the file was modified, "OK" otherwise.
Exit non-zero on error.
"""
import json
import sys
from pathlib import Path

import bcrypt
import yaml

CONFIG_PATH = Path("/opt/AdGuardHome/AdGuardHome.yaml")


def main() -> int:
    target = json.load(sys.stdin)

    cfg = yaml.safe_load(CONFIG_PATH.read_text())
    current = {u["name"]: u for u in (cfg.get("users") or [])}
    changed = False

    for user in target:
        name = user["name"]
        password = user["password"].encode()
        existing = current.get(name)
        if existing:
            stored = existing["password"].encode()
            if not bcrypt.checkpw(password, stored):
                new_hash = bcrypt.hashpw(password, bcrypt.gensalt(rounds=10)).decode()
                for u in cfg["users"]:
                    if u["name"] == name:
                        u["password"] = new_hash
                changed = True
        else:
            new_hash = bcrypt.hashpw(password, bcrypt.gensalt(rounds=10)).decode()
            if not cfg.get("users"):
                cfg["users"] = []
            cfg["users"].append({"name": name, "password": new_hash})
            changed = True

    target_names = {u["name"] for u in target}
    if cfg.get("users"):
        pruned = [u for u in cfg["users"] if u["name"] in target_names]
        if len(pruned) != len(cfg["users"]):
            cfg["users"] = pruned
            changed = True

    if changed:
        CONFIG_PATH.write_text(yaml.safe_dump(cfg, default_flow_style=False, sort_keys=False))
        print("CHANGED")
    else:
        print("OK")

    return 0


if __name__ == "__main__":
    sys.exit(main())
