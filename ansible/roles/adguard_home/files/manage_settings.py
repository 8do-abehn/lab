#!/usr/bin/env python3
"""
Reconcile AdGuard Home web/DNS bind settings with the desired state on stdin.

Stdin: JSON object {"http_address": str, "dns_bind_hosts": [str], "dns_port": int}.
Reads/writes /opt/AdGuardHome/AdGuardHome.yaml in place, replacing only the
keys it manages (agh_config.py, #605).
Prints "CHANGED" if the file was modified, "OK" otherwise.
Exit non-zero on error.
"""
import json
import sys
from pathlib import Path

import yaml

from agh_config import write_config

CONFIG_PATH = Path("/opt/AdGuardHome/AdGuardHome.yaml")


def main() -> int:
    desired = json.load(sys.stdin)

    text = CONFIG_PATH.read_text()
    cfg = yaml.safe_load(text)
    http = cfg.setdefault("http", {})
    dns = cfg.setdefault("dns", {})

    edits = []

    if http.get("address") != desired["http_address"]:
        http["address"] = desired["http_address"]
        edits.append((("http", "address"), desired["http_address"]))

    if dns.get("bind_hosts") != desired["dns_bind_hosts"]:
        dns["bind_hosts"] = desired["dns_bind_hosts"]
        edits.append((("dns", "bind_hosts"), desired["dns_bind_hosts"]))

    if dns.get("port") != desired["dns_port"]:
        dns["port"] = desired["dns_port"]
        edits.append((("dns", "port"), desired["dns_port"]))

    if not edits:
        print("OK")
        return 0

    write_config(CONFIG_PATH, text, edits, cfg)
    print("CHANGED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
