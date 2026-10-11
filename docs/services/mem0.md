# OpenMemory (mem0)

AI memory stack: OpenMemory MCP server, Ollama, and Open WebUI. OpenMemory is the
shared memory for MCP clients (Claude Code, Claude Desktop).

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

**Claude Code:** User-scope MCP server `mem0` over streamable HTTP.

## Embeddings (#625)

OpenMemory runs `OM_TIER=deep`: every memory is embedded with `bge-m3:567m` at
1024 dimensions, on the GPU Ollama on ollama01 (`svc:ollama`, ~0.12 s per
embedding; the mem01 CPU takes ~4 s). Until 2026-10-11 it ran `hybrid`, which
only ever used hash-based synthetic vectors, so recall matched words, not meaning.

- **The model and dimension are a pair.** Vectors do not record which model made
  them, and OpenMemory truncates or zero-pads to `OM_VEC_DIM`. Changing either is
  a migration: export the memories, wipe them, add them back.
- **The fallback to synthetic cannot be disabled.** If `svc:ollama` is down, new
  memories silently get hash vectors. `openmemory-fallback-check` (hourly cron)
  logs that to the journal and notifies through `/etc/apprise.yml` once mem01 has
  one (#329). Memories added during an outage need re-embedding.
- Regeneration only re-embeds a memory when a query hits it, so it does not
  repair memories that stopped matching.

## Backups (#329)

Nightly restic to pi-burg, same shared repo as the other clients:

- **00:05** `mem0-db-snapshot` (cron, mem0 role) copies the three live SQLite
  databases (OpenMemory, Open WebUI, Open WebUI's Chroma index) with SQLite's
  online backup API into `/var/backups/mem0-db`, checks each with
  `integrity_check`, and writes them as single files. The live files are WAL-mode
  and not safe to copy directly. A failure is logged and sent through Apprise.
- **00:15** restic backs up `/var/backups/mem0-db`, Open WebUI's `uploads` and
  `vector_db` (minus the live `chroma.sqlite3`), and `/opt/mem0`.
- Not backed up: Ollama models and Open WebUI's `cache/`, which are
  re-downloadable.

Restore OpenMemory: stop the stack, restore `openmemory.sqlite` from a snapshot
into the `mem0_openmemory_data` volume (remove any `-wal`/`-shm` next to it),
and start the stack.

## Ollama Models

| Where | Model | Purpose |
|-------|-------|---------|
| ollama01 (GPU) | bge-m3:567m | OpenMemory embeddings (pinned) |
| ollama01 (GPU) | qwen3:8b, llama3.1:8b | Chat in Open WebUI |
| mem01 (CPU) | bge-m3 | Not used by OpenMemory any more; still pulled by the role |

## MCP Tools

6 tools available: `openmemory_query`, `openmemory_list`, `openmemory_get`, `openmemory_store`, `openmemory_reinforce`, `openmemory_delete`.

## Ansible

- **Role:** [`mem0`](../../ansible/roles/mem0/)
- **Group vars:** [`mem0_servers.yml`](../../ansible/inventory/group_vars/mem0_servers.yml)
- **Inventory group:** `mem0_servers`

## Known Issues

| Issue | Description |
|-------|-------------|
| [#336](https://github.com/8do-abehn/lab/issues/336) | Ollama and Open WebUI not exposed as Tailscale Services |
| [#313](https://github.com/8do-abehn/lab/issues/313) | MagicDNS leaks into LXC resolv.conf on reboot |
| [#307](https://github.com/8do-abehn/lab/issues/307) | GPU spike: test Ollama on RX 570 |
