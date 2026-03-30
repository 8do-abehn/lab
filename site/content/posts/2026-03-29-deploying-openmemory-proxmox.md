---
title: "Deploying OpenMemory on Proxmox for Persistent AI Context"
date: 2026-03-29
draft: true
tags: ["ai", "homelab", "proxmox", "docker", "mcp", "tailscale"]
description: "How I deployed OpenMemory on a Proxmox LXC for persistent AI memory across Claude Code and Claude Desktop sessions, and everything that went wrong along the way."
---

## The Problem

I use Claude Code and Claude Desktop daily. Each session starts fresh — no memory of past conversations unless I manually maintain markdown files. I wanted semantic search over my accumulated context: "what do I know about VLAN 70?" should return relevant memories even if the word "VLAN" isn't in every note.

## What I Tried (and What Failed)

### Attempt 1: mem0-mcp-selfhosted

The plan was a full stack on a Proxmox LXC: Qdrant (vector DB), Ollama (embeddings), Neo4j (graph), and `elvismdev/mem0-mcp-selfhosted` as the MCP server that ties them together.

**Podman failed first.** Rootless Podman in an unprivileged LXC can't create UDP sockets for DNS resolution during image pulls. Switching to Docker fixed container networking but introduced AppArmor problems — Docker builds fail inside LXCs even with `lxc.apparmor.profile: unconfined`. I ended up cross-compiling the mem0-mcp image on my Mac (ARM) for AMD64 using a multi-stage Docker build, then `scp`ing the tarball to the server.

**Then the MCP server crashed.** The SSE transport in the MCP Python SDK has known bugs ([#883](https://github.com/modelcontextprotocol/python-sdk/issues/883), [#737](https://github.com/modelcontextprotocol/python-sdk/issues/737)) that cause ASGI crashes when clients reconnect. Switching to `streamable-http` transport avoided the SSE bugs but the server still froze under idle connections.

### Attempt 2: OpenMemory (Already Running)

While debugging mem0-mcp-selfhosted, I checked what the `openmemory` entry in my Claude Desktop config was actually doing. Turns out OpenMemory was already running on my Mac via Docker Desktop — with 7 memories stored from a session back in February. It had been working the whole time.

OpenMemory is simpler than the mem0 stack:
- **SQLite** for both metadata and vectors (no Qdrant, no Neo4j)
- **Ollama** for embeddings
- Built-in temporal fact store (subject/predicate/object triples with timestamps)
- Memory sectors (episodic, semantic, procedural, emotional, reflective)
- Salience scoring with decay

## What Actually Got Deployed

**LXC 3003 (`mem01`)** on pve02, VLAN 70 (services), Docker with `nesting=1`:

| Container | Purpose | Port |
|-----------|---------|------|
| Ollama | bge-m3 embeddings + qwen3:8b chat | 11434 |
| OpenMemory | MCP memory server (SQLite backend) | 8090 |
| Open WebUI | Chat interface for Ollama | 3000 |

Three containers instead of the original six. No Qdrant, no Neo4j, no mem0-mcp-selfhosted. OpenMemory's SQLite backend handles vectors and metadata in a single 4MB file.

## LXC Gotchas

Every one of these bit me during the deploy:

- **MagicDNS leaks into LXC resolv.conf** on every reboot, even with `pct set --nameserver` and `tailscale set --accept-dns=false`. Current workaround is a systemd oneshot service that rewrites `/etc/resolv.conf` on boot.
- **`/dev/net/tun` missing** — Tailscale needs it. Add `lxc.cgroup2.devices.allow: c 10:200 rwm` and `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file` to the container config.
- **AppArmor blocks Docker** — even with `lxc.apparmor.profile: unconfined`, Docker builds fail. Remove AppArmor entirely: `apt purge apparmor`.
- **`NEO4J_AUTH=neo4j/password`** uses `/` as separator — if your vault-generated password contains `/`, Neo4j rejects it silently and restart-loops. Use `openssl rand -hex 16`.
- **`python:3.12-slim` lacks `git`** — if pip needs to install from a git URL, you need the full `python:3.12` image or install git explicitly.
- **Cross-compiling psycopg2 on ARM Mac for AMD64** — use a multi-stage build with full `python:3.12` (not slim) as the builder stage.

## Ansible Role

The role follows the same pattern as `adguard_home`: install tasks, configure tasks (template the compose file), service tasks (start stack, pull models, verify health, register Tailscale service).

Key decisions:
- **`no_log: true`** on template tasks that could render vault secrets
- **`check_mode: false`** on all command/uri tasks that verify live service state
- **`pull_policy: never`** on the OpenMemory container (pre-built image, not from a registry)
- **`--ignore-pull-failures`** on `docker compose pull` so local images don't block remote pulls

## MCP Integration

Claude Code connects via HTTP transport:
```
claude mcp add --scope user --transport http mem0 "http://<tailscale-ip>:8090/mcp"
```

Claude Desktop uses `npx mcp-remote` to bridge:
```json
{
  "mem0": {
    "command": "npx",
    "args": ["mcp-remote", "http://<tailscale-ip>:8090/mcp", "--allow-http"]
  }
}
```

The `--allow-http` flag is needed because we're using Tailscale IP directly (HTTP over WireGuard). A Tailscale Service would give us HTTPS with a proper cert, but the service registration ACL needs investigation.

## What's Next

- **Tailscale Service** — expose as `https://mem0.taile975f.ts.net` instead of raw IP
- **Migrate flat-file memories** — import `~/.claude/projects/.../memory/` into OpenMemory
- **Backups** — SQLite file is easy to back up, just need to schedule it
- **GPU spike** — test Ollama on the RX 570s (Polaris/GCN 4, ROCm dropped support, community fork exists)

## Lessons Learned

1. **Check what's already running.** OpenMemory was deployed and working for weeks before I tried to build something new.
2. **Podman doesn't work in unprivileged LXCs** for container networking. Docker does.
3. **The MCP ecosystem is young.** Community MCP servers crash under real-world reconnection patterns. Official/established tools are more reliable.
4. **Start simple.** SQLite beats Qdrant + Neo4j for a single-user memory store. Add complexity when you need it.
5. **Cross-platform Docker builds from ARM Macs** need multi-stage builds with full base images for C extension compilation.
