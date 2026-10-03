#!/usr/bin/env python3
"""Print one power reading from a Kasa KP115 energy-monitoring plug as CSV.

Output: power_w,total_wh   (empty fields on any failure, never a traceback)

Stdlib only, so ups-discharge-log.sh can use it on a Proxmox host without
installing python-kasa there. It speaks the plug's legacy local protocol on
TCP 9999 and sends exactly one read-only query, emeter.get_realtime, so it
cannot switch the plug off or change any setting.

Usage: kp115-read.py <host> [timeout_seconds]
"""

import json
import socket
import struct
import sys

QUERY = {"emeter": {"get_realtime": {}}}


# The legacy Kasa protocol XORs each byte with the previous ciphertext byte,
# starting from 171, behind a 4-byte big-endian length prefix
def encrypt(text):
    key, out = 171, bytearray()
    for b in text.encode():
        key ^= b
        out.append(key)
    return struct.pack(">I", len(out)) + bytes(out)


def decrypt(data):
    key, out = 171, bytearray()
    for b in data:
        out.append(key ^ b)
        key = b
    return out.decode()


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("short read")
        buf += chunk
    return buf


def read(host, timeout):
    with socket.create_connection((host, 9999), timeout=timeout) as sock:
        sock.sendall(encrypt(json.dumps(QUERY)))
        (length,) = struct.unpack(">I", recv_exact(sock, 4))
        reply = json.loads(decrypt(recv_exact(sock, length)))
    rt = reply["emeter"]["get_realtime"]
    # Hardware v1 KP115 reports milli-units; older firmware uses plain units
    power = rt["power_mw"] / 1000 if "power_mw" in rt else rt["power"]
    total = rt["total_wh"] if "total_wh" in rt else rt["total"] * 1000
    return power, total


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    timeout = float(sys.argv[2]) if len(sys.argv) > 2 else 2.0
    try:
        power, total = read(sys.argv[1], timeout)
        print(f"{power:.1f},{total:.0f}")
    except Exception:
        # The logger treats empty fields as "no reading" and keeps going
        print(",")


if __name__ == "__main__":
    main()
