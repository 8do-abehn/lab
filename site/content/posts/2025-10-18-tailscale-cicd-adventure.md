---
title: "Building a CI/CD Pipeline Over Tailscale VPN"
date: 2025-10-18
draft: false
tags: ["ansible", "tailscale", "ci-cd", "github-actions", "proxmox"]
description: "How I got GitHub Actions to test Ansible playbooks against real homelab infrastructure over Tailscale, complete with tag-based ACLs and OAuth authentication."
---

One of those satisfying days where a pile of "almost working" became a fully operational CI/CD pipeline. The goal: get GitHub Actions runners to test Ansible playbooks against real infrastructure over Tailscale VPN.

## The Problem

I had Ansible playbooks managing Proxmox hosts, but no automated testing. Every change was a manual `ansible-playbook --check` from my laptop. I wanted PRs to automatically lint and dry-run against the real cluster before merge.

The catch: the infrastructure lives on a private network behind Tailscale. GitHub Actions runners need a way in.

## The Journey

### Act 1: The Hostname Switcheroo

The CI workflow was timing out trying to SSH to hosts. The inventory used local IPs like `10.150.10.44` that GitHub Actions runners couldn't reach, even with Tailscale connected.

**The fix:** Strip out all the `ansible_host` IP entries and let Tailscale MagicDNS handle resolution. Clean and simple — just `pve004` instead of `pve004 ansible_host=10.150.10.44`.

### Act 2: The SSH Key Verification Wall

"Host key verification failed" on every host. Ephemeral GitHub runners don't have any SSH host keys in their `known_hosts` file.

**The fix:** `ANSIBLE_HOST_KEY_CHECKING: 'False'` in the workflow environment. Safe for ephemeral CI runners that get destroyed after every run.

### Act 3: The ACL Permission Maze

Then came the error: `tailnet policy does not permit you to SSH to this node`.

This kicked off a game of "ACL Whack-a-Mole":

1. **First attempt:** Use `autogroup:member` in dst — *NOPE* — "invalid dst autogroup:member"
2. **Second attempt:** Use `*` for all hosts — *NOPE* — "invalid dst *"
3. **The catch-22:** Hosts needed tags to be accessible, but I needed SSH access to apply the tags

**The breakthrough:** Update the ACL to allow admin access to all member devices temporarily, apply the tags via Ansible, then tighten the ACL back down.

### Act 4: The Tag Application Drama

With SSH access restored, the Ansible playbook applied tags to all hosts. But then:

```
ERROR: object of type 'HostVarsVars' has no attribute 'ansible_host'
```

The NUT role was still looking for `ansible_host` that I'd removed. It was trying to auto-detect the UPS server's IP address.

**The fix:** Updated the NUT client role to use the inventory hostname directly instead of `hostvars[item].ansible_host`.

### Act 5: The Tailscale Tag Tango

One more hurdle. Running `tailscale up --advertise-tags=tag:proxmox` failed with:

```
Error: changing settings via 'tailscale up' requires mentioning all
non-default flags.
```

Since SSH was already enabled on the hosts (a non-default setting), I needed to include `--ssh` along with `--advertise-tags` when updating configuration.

**The fix:** Updated the Ansible tasks to always include `--ssh` when running `tailscale up` with tags:
```yaml
command: >
  tailscale up
  {% if tailscale_tags is defined %}--advertise-tags={{ tailscale_tags }}{% endif %}
  {% if tailscale_enable_ssh | default(true) %}--ssh{% endif %}
```

### Act 6: Green Across the Board

With everything aligned, the CI workflow ran:
- **Ansible Lint**: passed (40 seconds)
- **Test Against Infrastructure**: passed (2m 37s)

Total runtime: 3 minutes 36 seconds.

The GitHub Actions runner successfully connected to Tailscale using OAuth, SSH'd into 11 infrastructure hosts, ran `ansible-playbook --check --diff`, and reported zero errors.

## The Final Setup

### Tailscale ACL Configuration

Tag-based access control keeps CI runners scoped to infrastructure only:

```json
"tagOwners": {
    "tag:ci": ["autogroup:admin"],
    "tag:proxmox": ["autogroup:admin"],
    "tag:k3s": ["autogroup:admin"]
},

"ssh": [
    {
        "action": "accept",
        "src":    ["autogroup:admin"],
        "dst":    ["tag:proxmox", "tag:k3s"],
        "users":  ["root", "autogroup:nonroot"]
    },
    {
        "action": "accept",
        "src":    ["tag:ci"],
        "dst":    ["tag:proxmox", "tag:k3s"],
        "users":  ["root", "autogroup:nonroot"]
    }
]
```

CI runners can only SSH to tagged infrastructure — not personal devices.

### GitHub Actions OAuth

Used Tailscale OAuth instead of auth keys:
- Automatic token rotation
- Ephemeral nodes with auto-cleanup
- No long-lived credentials in GitHub Secrets
- Scoped access with tags

## Lessons Learned

1. **Tailscale SSH ACLs are strict** — no wildcards in dst, specific tag rules only
2. **Tags are applied via `tailscale up --advertise-tags`**, not `tailscale set`
3. **When updating settings with `tailscale up`, include ALL non-default flags** — the `--ssh` requirement is easy to miss
4. **Ephemeral CI runners need different security posture** — host key checking off is fine when the runner is destroyed after every job
5. **MagicDNS just works** — no need for `ansible_host` entries when using Tailscale hostnames

## What Got Shipped

Every PR now gets automatically validated against the real infrastructure before merge. The pipeline has multiple layers:

1. **Tailscale VPN** — network access
2. **ACL tags** — scoped permissions
3. **SSH keys** — authentication
4. **Ansible check mode** — dry-run validation

No more "works on my machine." It either works on the actual Proxmox cluster or the PR stays red.
