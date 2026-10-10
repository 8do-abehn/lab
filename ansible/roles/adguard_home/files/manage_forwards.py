#!/usr/bin/env python3
"""
Reconcile AdGuard Home conditional forwards with the desired list on stdin.

Stdin: JSON list of {"domain": str, "upstream": str} objects.
Each becomes a "[/domain/]upstream" entry in dns.upstream_dns. Only entries
for exactly one listed domain are owned here: any other "[/domain/]..." line
for that same domain is replaced, and everything else in upstream_dns (the
general upstreams, forwards added through the UI) is left alone.
Reads/writes /opt/AdGuardHome/AdGuardHome.yaml in place.
Prints "CHANGED" if the file was modified, "OK" otherwise.
Exit non-zero on error.
"""
import json
import sys
from pathlib import Path

import yaml

from agh_config import write_config

CONFIG_PATH = Path("/opt/AdGuardHome/AdGuardHome.yaml")


def forward_domains(line: str) -> list[str] | None:
    """Return the domains of a "[/a/b/]upstream" line, or None for a plain upstream."""
    if not line.startswith("[/") or "/]" not in line:
        return None
    return [d for d in line[2 : line.index("/]")].split("/") if d]


def main() -> int:
    desired = json.load(sys.stdin)
    owned = {f["domain"] for f in desired}
    wanted = [f"[/{f['domain']}/]{f['upstream']}" for f in desired]

    text = CONFIG_PATH.read_text()
    cfg = yaml.safe_load(text)
    dns = cfg.setdefault("dns", {})
    current = dns.get("upstream_dns") or []

    kept = [
        line
        for line in current
        if not (
            (domains := forward_domains(line)) is not None
            and len(domains) == 1
            and domains[0] in owned
        )
    ]
    updated = kept + wanted

    if updated == current:
        print("OK")
        return 0

    dns["upstream_dns"] = updated
    write_config(CONFIG_PATH, text, [(("dns", "upstream_dns"), updated)], cfg)
    print("CHANGED")
    return 0


if __name__ == "__main__":
    sys.exit(main())
