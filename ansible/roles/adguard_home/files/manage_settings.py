#!/usr/bin/env python3
"""
Reconcile AdGuard Home web/DNS bind settings with the desired state on stdin.

Stdin: JSON object {"http_address": str, "dns_bind_hosts": [str], "dns_port": int}.
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

    cfg = yaml.safe_load(CONFIG_PATH.read_text())
    http = cfg.setdefault("http", {})
    dns = cfg.setdefault("dns", {})

    changed = False

    if http.get("address") != desired["http_address"]:
        http["address"] = desired["http_address"]
        changed = True

    if dns.get("bind_hosts") != desired["dns_bind_hosts"]:
        dns["bind_hosts"] = desired["dns_bind_hosts"]
        changed = True

    if dns.get("port") != desired["dns_port"]:
        dns["port"] = desired["dns_port"]
        changed = True

    if not changed:
        print("OK")
        return 0

    CONFIG_PATH.write_text(yaml.safe_dump(cfg, default_flow_style=False, sort_keys=False))
    print("CHANGED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
