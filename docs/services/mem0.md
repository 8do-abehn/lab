# OpenMemory (mem0)

AI memory stack: OpenMemory MCP server, Ollama for embeddings/LLM, and Open WebUI.

## Where It Runs

| Property | Value |
|----------|-------|
| Host | mem01 |
| LXC ID | 3003 |
| Proxmox Node | pve02 |
| Tailscale Service | `svc:mem0` |
| Disk | 52GB (expanded from 32GB for model storage) |

IPs and Tailscale addresses are in the [inventory](../../ansible/inventory/).

## Services

| Service | Container | Port | Purpose |
|---------|-----------|------|---------|
| Ollama | mem0-ollama | 11434 | LLM inference, embedding models |
| OpenMemory | mem0-openmemory | 8090 | MCP server (AI memory, SQLite-backed) |
| Open WebUI | mem0-openwebui | 3000 | Web interface for testing |

Tailscale Service routes HTTPS (443) to OpenMemory on port 8090.

## How to Connect

**Claude Desktop:** Uses `supergateway` bridge (not `mcp-remote`, which drops write tools).

**Claude Code:** Connects via Docker MCP Toolkit gateway automatically.

## Ollama Models

| Model | Size | Purpose |
|-------|------|---------|
| bge-m3 | 6GB | Embedding model for vector storage |
| qwen3:8b | 8B params | Chat/LLM |

## MCP Tools

6 tools available: `openmemory_query`, `openmemory_list`, `openmemory_get`, `openmemory_store`, `openmemory_reinforce`, `openmemory_delete`.

## Ansible

- **Role:** [`mem0`](../../ansible/roles/mem0/)
- **Group vars:** [`mem0_servers.yml`](../../ansible/inventory/group_vars/mem0_servers.yml)
- **Inventory group:** `mem0_servers`

## Known Issues

| Issue | Description |
|-------|-------------|
| [#329](https://github.com/8do-abehn/lab/issues/329) | No restic backup configured yet |
| [#336](https://github.com/8do-abehn/lab/issues/336) | Ollama and Open WebUI not exposed as Tailscale Services |
| [#313](https://github.com/8do-abehn/lab/issues/313) | MagicDNS leaks into LXC resolv.conf on reboot |
| [#307](https://github.com/8do-abehn/lab/issues/307) | GPU spike: test Ollama on RX 570 |
