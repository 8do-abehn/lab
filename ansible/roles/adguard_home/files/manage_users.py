#!/usr/bin/env python3
"""Reconcile AdGuard Home users from JSON on stdin.

Stdin: JSON list of {"name": str, "password": str} objects (plaintext passwords).
Surgically replaces only the users: block in AdGuardHome.yaml using text
substitution so other YAML fields (e.g. duration strings) are never touched.
Prints "CHANGED" if the file was modified, "OK" otherwise.
Exit non-zero on error.
"""
import json
import re
import sys
from pathlib import Path

import bcrypt
import yaml

CONFIG_PATH = Path("/opt/AdGuardHome/AdGuardHome.yaml")

# Capture users: block up to the next top-level key (col-0, not '-' or whitespace).
# Using [^-\s] so list item lines ('- name:') and indented lines are included.
_USERS_RE = re.compile(r"^users:.*?(?=^[^-\s]|\Z)", re.MULTILINE | re.DOTALL)


def _parse_users(text: str) -> list[dict]:
    m = _USERS_RE.search(text)
    if not m:
        return []
    return yaml.safe_load(m.group(0)).get("users") or []


def _render_users_block(users: list[dict]) -> str:
    if not users:
        return "users: []\n"
    return "users:\n" + yaml.safe_dump(users, default_flow_style=False, sort_keys=False)


def main() -> int:
    target = json.load(sys.stdin)
    text = CONFIG_PATH.read_text()

    current = _parse_users(text)
    by_name = {u["name"]: u for u in current}
    updated = list(current)
    changed = False

    for user in target:
        name = user["name"]
        password = user["password"].encode()
        existing = by_name.get(name)
        if existing:
            if not bcrypt.checkpw(password, existing["password"].encode()):
                new_hash = bcrypt.hashpw(password, bcrypt.gensalt(rounds=10)).decode()
                for u in updated:
                    if u["name"] == name:
                        u["password"] = new_hash
                changed = True
        else:
            new_hash = bcrypt.hashpw(password, bcrypt.gensalt(rounds=10)).decode()
            updated.append({"name": name, "password": new_hash})
            changed = True

    target_names = {u["name"] for u in target}
    pruned = [u for u in updated if u["name"] in target_names]
    if len(pruned) != len(updated):
        updated = pruned
        changed = True

    if changed:
        new_block = _render_users_block(updated)
        CONFIG_PATH.write_text(_USERS_RE.sub(new_block, text))
        print("CHANGED")
    else:
        print("OK")

    return 0


if __name__ == "__main__":
    sys.exit(main())
