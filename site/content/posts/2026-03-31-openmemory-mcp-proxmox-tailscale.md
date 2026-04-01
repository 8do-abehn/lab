---
title: "Self-Hosting OpenMemory MCP on Proxmox with Tailscale"
date: 2026-03-31
draft: true
tags: ["homelab", "proxmox", "docker", "ai", "mcp", "tailscale", "ollama"]
description: "Deploying a self-hosted OpenMemory MCP server on a Proxmox LXC with Ollama and Tailscale, plus fixing Claude Desktop's broken write tools with supergateway."
---

## The Goal

I wanted a persistent AI memory layer — something that stores context across conversations and tools, accessible from Claude Desktop, Claude Code, and eventually other MCP clients. The official mem0 platform exists, but I wanted to self-host it on my Proxmox cluster for control and privacy.

## The Stack

The deployment runs on **mem01** (LXC 3003, pve02) with three Docker containers:

- **Ollama** — LLM inference for embeddings (bge-m3) and chat (qwen3:8b)
- **OpenMemory** — the MCP server itself, using SQLite for vectors and metadata
- **Open WebUI** — optional web interface for testing

I started with `mem0-mcp-selfhosted` (Neo4j + Qdrant + Python SDK) but it crashed repeatedly and had a painful dependency chain. OpenMemory — SQLite for everything, Node.js SDK — just worked.

The whole thing is an Ansible role. Docker Compose template, Tailscale Service registration, Ollama model pulls — all automated:

```yaml
# ansible/roles/mem0/defaults/main.yml
mem0_compose_dir: /opt/mem0
mem0_ollama_port: 11434
mem0_openmemory_port: 8090
mem0_openwebui_port: 3000
mem0_ollama_models:
  - bge-m3
  - qwen3:8b
```

## Disk Sizing

The 32GB root disk filled up fast — Ollama models (6GB for bge-m3 + qwen3:8b), Docker images (20GB for three services), and build cache. Hit 100% and got a critical Netdata alert at 4am. Live-resized to 52GB without downtime:

```bash
# On the Proxmox host
pct resize 3003 rootfs +20G
# That's it — resize2fs runs automatically for LXCs
```

Lesson: size LXC disks for Ollama at 40GB+ minimum. Models and images add up fast.

## Connecting Claude Desktop: mcp-remote vs supergateway

This was the sneakiest issue. OpenMemory exposes 6 MCP tools (query, list, get, store, reinforce, delete), but Claude Desktop only loaded the read tools. The write tools appeared in the deferred tool catalog but wouldn't load into active sessions.

The server wasn't filtering anything — confirmed by hitting the MCP endpoint directly:

```bash
curl -s -X POST http://localhost:8090/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq '.result.tools[].name'
# Returns all 6 tools
```

The problem was **`mcp-remote`** — the npm package that bridges remote MCP servers to Claude Desktop's stdio transport. It doesn't handle Streamable HTTP transport correctly and silently drops write tools from the tool list.

The fix: **`supergateway`** — a different bridge that properly handles Streamable HTTP:

```json
{
  "mcpServers": {
    "openmemory": {
      "command": "npx",
      "args": [
        "-y",
        "supergateway",
        "--streamableHttp",
        "http://<tailscale-ip>:8090/mcp"
      ]
    }
  }
}
```

All 6 tools loaded immediately after the switch. If you're self-hosting any MCP server that uses Streamable HTTP transport, skip `mcp-remote` and go straight to `supergateway`.

## Claude Code vs Claude Desktop

The two clients connect to OpenMemory differently:

| Client | Transport | Config |
|--------|-----------|--------|
| Claude Code | Docker MCP Toolkit gateway | Automatic via `docker mcp gateway run` |
| Claude Desktop | supergateway → Streamable HTTP | `claude_desktop_config.json` |

Claude Code gets its MCP tools through the Docker MCP Toolkit, which handles the transport natively. Claude Desktop needs the supergateway bridge because it only speaks stdio to MCP servers.

## Migrating Memories

The original OpenMemory ran on Docker Desktop on my Mac. Once mem01 was stable, I needed to move the data over. The SQLite database had been partially copied during initial setup (4 of 7 memories came across with matching IDs), but two were missing — GPU consolidation plans and cluster hardware notes.

I listed both instances side by side, identified the gaps, and stored the missing memories via the MCP `openmemory_store` tool from Claude Code. No file copying needed — just read from the old instance, write to the new one.

To verify persistence, I stopped and started the OpenMemory container on mem01. All memories survived. The Mac instance can be shut down now — mem01 is the source of truth.

## Tailscale Service

OpenMemory is registered as a Tailscale Service (`svc:mem0`):

```bash
tailscale serve --service=svc:mem0 --bg --https=443 127.0.0.1:8090
```

The idea is a stable DNS name (`mem0.<tailnet>.ts.net`) decoupled from the LXC hostname — if I move it to a different node or add replicas, clients don't need to change config. In practice, the service registration is still pending — the host isn't showing in the Tailscale admin panel despite `tailscale serve` running on mem01. The ACL may need an explicit service-proxy grant. For now, MCP clients connect directly via the Tailscale IP.

## Current State

- **mem01**: LXC 3003 on pve02, 52GB disk, 16GB RAM
- **Containers**: All healthy, low resource usage (~700MB total memory)
- **Models**: bge-m3 (embeddings), qwen3:8b (chat)
- **MCP**: Full read/write access from both Claude Code and Claude Desktop
- **Tailscale Service**: Registered but pending admin approval — using direct IP for now
- **Backup**: Manual snapshot taken, automated restic to pi-burg is next priority

## Lessons Learned

1. **Start with SQLite** — Qdrant + Neo4j is overkill for a single-user memory server
2. **`mcp-remote` drops write tools** — use `supergateway` for Streamable HTTP MCP servers connecting to Claude Desktop
3. **Size LXC disks for Ollama** — models + images need 40GB+ minimum, and `pct resize` works live with no reboot
