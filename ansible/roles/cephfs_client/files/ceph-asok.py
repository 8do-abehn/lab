#!/usr/bin/env python3
"""Send one command to a Ceph admin socket and print the reply.

Managed by Ansible (roles/cephfs_client). See #579.

The media LXCs only carry ceph-fuse, not ceph-common, so there is no `ceph
daemon` CLI to talk to the client's admin socket. ceph-common is deliberately
not installed: its logrotate rule sends SIGHUP to ceph-fuse, which would muddy
#579, where a host-side SIGHUP is one of the open leads.

Extra arguments become command fields: key=value sends a string, key:=<json>
sends raw JSON. Some fields must be JSON: "config set" rejects a plain string
val with "invalid command json" and wants a list, e.g. to change a setting on
the running client without a remount:

  ceph-asok <socket> "config set" var=debug_client 'val:=["1/5"]'

Exits non-zero when the daemon answers with an error, so callers notice.

Usage: ceph-asok <socket path> "<command>" [key=value | key:=json ...]
"""
import json
import socket
import struct
import sys

TIMEOUT = 10


def recv_exact(sock, n):
    buf = b""
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            raise EOFError("admin socket closed after %d of %d bytes" % (len(buf), n))
        buf += chunk
    return buf


def main():
    if len(sys.argv) < 3 or not all("=" in a for a in sys.argv[3:]):
        sys.exit(__doc__.strip().splitlines()[-1])
    path, prefix = sys.argv[1], sys.argv[2]
    request = {"prefix": prefix, "format": "json-pretty"}
    for arg in sys.argv[3:]:
        key, value = arg.split("=", 1)
        if key.endswith(":"):
            request[key[:-1]] = json.loads(value)
        else:
            request[key] = value
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    # A wedged ceph-fuse may never answer. That is itself a finding, so fail
    # fast and let the caller record it rather than hang the watchdog.
    sock.settimeout(TIMEOUT)
    sock.connect(path)
    sock.sendall(json.dumps(request).encode() + b"\0")
    length = struct.unpack(">I", recv_exact(sock, 4))[0]
    reply = recv_exact(sock, length).decode(errors="replace")
    sys.stdout.write(reply + "\n")
    if reply.startswith("ERROR"):
        sys.exit(1)


if __name__ == "__main__":
    main()
