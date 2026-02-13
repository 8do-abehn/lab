# Netdata Fleet Health Check in CI/CD

**Date:** 2026-02-12

## Summary

Added a post-deploy health check step to the `ansible-deploy.yml` GitHub Actions workflow. After running Netdata or site-wide playbooks, the workflow now queries the Netdata Cloud API to verify all nodes are reachable.

## Problem

The deploy workflow relied solely on Ansible's exit code to determine success. A playbook could complete without errors but leave a node in a degraded state — the agent might not start, or a config issue could make it unreachable from Netdata Cloud. There was no post-deploy verification.

## Solution

Added a new step between the playbook run and vault cleanup that:

1. Queries the Netdata Cloud API (`/api/v2/spaces/{space}/rooms/{room}/nodes`) for all nodes in the "All nodes" room
2. Prints a summary table of node names and states
3. Fails the workflow if any node is not in `reachable` state

The step only runs for `netdata_install.yml` and `site.yml` playbooks — skipped for unrelated runs like `verify_nut.yml`.

## Implementation Details

- Uses `NETDATA_API_TOKEN` stored as a GitHub Actions secret
- Space ID: `fdc5c86c-40e1-4c04-ba72-2c270dbcc2f2`
- Room: "All nodes" (`b9b8607a-73ca-4de7-b5ae-86c3c74766be`)
- Uses `jq` to parse the API response and `grep` to detect unreachable nodes
- Outputs GitHub Actions error annotations (`::error::`) for visibility in the Actions UI

## Issues Hit Along the Way

### pibackup unreachable from CI

First deploy failed because `pibackup` had a hardcoded LAN IP (`10.150.10.140`) in the Ansible inventory. The CI runner connects via Tailscale and can't reach LAN addresses. All other hosts resolved by Tailscale DNS hostname — pibackup was the only one with `ansible_host` set. Fix: removed the `ansible_host` entry so it resolves via Tailscale like everything else.

### Netdata Cloud API response format

The health check initially assumed the API returned `{"nodes": [...]}` but it actually returns a top-level array. The jq expression `.nodes[]` failed with `Cannot index array with string "nodes"`. Fix: changed to `.[]` after confirming the format with debug output.

### API response structure (for reference)

- Endpoint: `GET /api/v2/spaces/{space}/rooms/{room}/nodes`
- Response: top-level JSON array
- Each element has `name` (string) and `state` (string, e.g. `"reachable"`)
- Currently returns 11 nodes across proxmox hosts, jellyfin, docker, and pi-burg

## Required Setup

- Generate a new Netdata Cloud API token (previous one was revoked)
- Add it as `NETDATA_API_TOKEN` in the repo's GitHub Actions secrets

## Files Changed

- `.github/workflows/ansible-deploy.yml` — added "Netdata fleet health check" step
- `ansible/inventory/homelab.yml` — removed hardcoded LAN IP from pibackup
