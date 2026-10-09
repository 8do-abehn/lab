#!/usr/bin/env python3
"""Decide the CI result from ansible-playbook's exit code and PLAY RECAP (#599).

A host that is genuinely offline (pi-burg is a Pi on Wi-Fi at another house) used to fail
every unrelated PR. This passes the job ONLY when the sole problem is an unreachable host
listed as optional; it is still reported, as a warning annotation and in the job summary.

Fails the job when any of these hold:
  - any host has failed > 0 (a real task failure)
  - any host NOT in the optional list is unreachable
  - there is no PLAY RECAP at all (vault, syntax or inventory error)
  - ansible-playbook exited with anything other than 0 or 4 (4 = unreachable hosts only)

Usage: recap_gate.py --rc N --optional "host1 host2" LOGFILE
"""
import argparse
import os
import re
import sys

RECAP_LINE = re.compile(
    r"(?P<host>\S+)\s+:\s+ok=\d+\s+changed=\d+\s+unreachable=(?P<unreach>\d+)\s+failed=(?P<failed>\d+)"
)


def parse_recap(text):
    """Return {host: (unreachable, failed)} from the LAST PLAY RECAP block, or None."""
    idx = text.rfind("PLAY RECAP")
    if idx < 0:
        return None
    hosts = {}
    for line in text[idx:].splitlines()[1:]:
        m = RECAP_LINE.search(line)
        if m:
            hosts[m["host"]] = (int(m["unreach"]), int(m["failed"]))
        elif hosts and line.strip() and not re.search(r"\d{4}-\d\d-\d\dT[\d:.]+Z\s*$", line):
            break  # first non-recap line after the block ends it
    return hosts


def decide(rc, recap, optional):
    """Return (exit_code, errors, warnings)."""
    errors, warnings = [], []
    if rc == 0:
        return 0, errors, warnings
    if recap is None:
        return 1, [f"ansible-playbook exited {rc} with no PLAY RECAP (vault, syntax or inventory error)"], warnings
    for host, (unreach, failed) in sorted(recap.items()):
        if failed:
            errors.append(f"{host}: {failed} failed task(s)")
        if unreach:
            if host in optional:
                warnings.append(f"{host}: unreachable (optional host; not failing the run)")
            else:
                errors.append(f"{host}: unreachable")
    if rc not in (2, 4):
        errors.append(f"ansible-playbook exited {rc}, which is not a task or unreachable failure")
    if not errors and not warnings:
        errors.append(f"ansible-playbook exited {rc} but the recap shows no failed or unreachable host")
    return (1 if errors else 0), errors, warnings


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rc", type=int, required=True)
    ap.add_argument("--optional", default="")
    ap.add_argument("log")
    a = ap.parse_args()
    optional = set(a.optional.split())
    with open(a.log, errors="replace") as f:
        recap = parse_recap(f.read())
    code, errors, warnings = decide(a.rc, recap, optional)
    for w in warnings:
        print(f"::warning title=Optional host unreachable::{w}")
    for e in errors:
        print(f"::error title=Ansible check failed::{e}")
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as s:
            s.write("### Ansible check result\n\n")
            s.write(f"ansible-playbook exit code: `{a.rc}` → job **{'failed' if code else 'passed'}**\n\n")
            for e in errors:
                s.write(f"- ❌ {e}\n")
            for w in warnings:
                s.write(f"- ⚠️ {w}\n")
    return code


if __name__ == "__main__":
    sys.exit(main())
