---
title: "The Great Tailscale CI/CD Adventure"
date: 2025-10-18
draft: false
tags: ["proxmox", "ansible", "tailscale", "ci-cd"]
summary: "Getting GitHub Actions to test Ansible playbooks against real infrastructure over Tailscale VPN. A journey through ACL whack-a-mole, SSH key verification, and tag-based access control."
---

## Mission: Get GitHub Actions CI/CD Working with Tailscale

Today was one of those satisfying days where I turned a pile of "almost working" into a fully operational CI/CD pipeline. The goal? Get GitHub Actions runners to test my Ansible playbooks against real infrastructure over Tailscale VPN.

## The Journey

### Act 1: The Hostname Switcheroo

I started where I left off - the CI workflow was timing out trying to SSH to hosts. The problem? My inventory used local IPs like `10.x.x.x` that GitHub Actions runners couldn't reach, even with Tailscale connected.

**The fix:** Strip out all the `ansible_host=10.x.x.x` entries and let Tailscale MagicDNS do its thing. Clean and simple - just `proxmox-node` instead of `proxmox-node ansible_host=10.x.x.x`.

One commit, one push, feeling good...

### Act 2: The SSH Key Verification Wall

*WHAM!* "Host key verification failed" on every single host. Of course! Ephemeral GitHub runners don't have any SSH host keys in their `known_hosts` file. I remembered running into this before - "there was a command I had to run to accept SSH keys?"

**The fix:** `ANSIBLE_HOST_KEY_CHECKING: 'False'` in the workflow environment. Safe for ephemeral CI runners that get destroyed after every run. Added it to both workflows. Another commit, another push...

### Act 3: The ACL Permission Maze

Then came the fun part. The error message: `tailnet policy does not permit you to SSH to this node`.

This kicked off a wonderful game of "ACL Whack-a-Mole":

1. **First attempt:** Use `autogroup:member` in dst - *NOPE* - "invalid dst autogroup:member"
2. **Second attempt:** Use `*` for all hosts - *NOPE* - "invalid dst *"
3. **The catch-22:** Hosts needed tags to be accessible, but I needed SSH access to apply the tags!

**The breakthrough:** I could have bypassed Tailscale SSH temporarily with `ANSIBLE_SSH_ARGS="-o ProxyCommand=none"` to apply the tags, but I just updated the ACL to allow admin access to all member devices first. Sometimes the direct approach works.

### Act 4: The Tag Application Drama

With SSH access restored, I ran the Ansible playbook to apply tags. Success! All hosts got their tags... but then:

```
ERROR: object of type 'HostVarsVars' has no attribute 'ansible_host'
```

The NUT role was still looking for `ansible_host` that I'd removed! It was trying to auto-detect the UPS server's IP address.

**The fix:** Updated the NUT client role to use the inventory hostname directly instead of `hostvars[item].ansible_host`. Changed the fallback to use the Tailscale hostname. Committed, pushed...

Then I ran it again and got the same error. What?!

**The plot twist:** I hadn't pulled the latest changes. Classic. A quick `git pull` and I was back in business.

### Act 5: The Tailscale Tag Tango

One more hurdle emerged when I tried to apply tags. Running `tailscale up --advertise-tags=tag:proxmox` failed with:

```
Error: changing settings via 'tailscale up' requires mentioning all
non-default flags.
```

**The issue:** Since SSH was already enabled on the hosts (a non-default setting), I needed to include `--ssh` along with `--advertise-tags` when updating configuration.

**The fix:** Updated the Ansible tasks to always include `--ssh` when running `tailscale up` with tags:
```yaml
command: >
  tailscale up
  {% if tailscale_tags is defined %}--advertise-tags={{ tailscale_tags }}{% endif %}
  {% if tailscale_enable_ssh | default(true) %}--ssh{% endif %}
```

### Act 6: Victory!

With everything aligned, the CI workflow ran:
- **Ansible Lint**: SUCCESS (40 seconds)
- **Test Against Infrastructure**: SUCCESS (2m 37s)

Total runtime: 3 minutes 36 seconds of pure green checkmarks.

The GitHub Actions runner successfully:
1. Connected to Tailscale using OAuth
2. SSH'd into 11 infrastructure hosts (7 Proxmox + 4 K3s)
3. Ran `ansible-playbook --check --diff`
4. Reported zero errors

## The Bonus Round

While basking in the glow of success, I started thinking about optimizing CI performance.

**Created Issue #21:** Custom Docker image for faster workflows. Pre-bake Ansible, ansible-lint, jq, and other tools into a container image. Should save 30-60 seconds per run and ensure consistent tool versions.

Merged PR #19 via web UI, synced main, and I was done!

## What I Shipped

**Files Created/Modified:**
- `.github/workflows/ansible-ci.yml` - Auto CI on PRs
- `.github/workflows/ansible-deploy.yml` - Manual production deployment
- `ansible/inventory.ini` - Tailscale hostnames only
- `ansible/group_vars/proxmox.yml` - Added `tailscale_tags: "tag:proxmox"`
- `ansible/group_vars/k3s_cluster.yml` - Added `tailscale_tags: "tag:k3s"`
- `ansible/roles/tailscale/tasks/auth.yml` - Auto-apply tags with `--advertise-tags`
- `ansible/roles/nut/tasks/client.yml` - Use hostnames instead of IPs
- `ansible/.ansible-lint` - Skip rules (technical debt tracked in Issue #20)
- `.github/tailscale-acl.json` - Updated ACL template

**Issues Created:**
- #20: ansible-lint cleanup (technical debt)
- #21: Custom Docker image for CI (performance optimization)

## Lessons Learned

1. **Tailscale SSH ACLs are picky** - No wildcards in dst, specific rules only
2. **Tags are applied via `tailscale up --advertise-tags`**, not `tailscale set`
3. **When updating settings with `tailscale up`, you must mention ALL non-default flags** (that `--ssh` requirement bit me)
4. **Ephemeral CI runners need different security posture** - Host key checking off is fine
5. **Always `git pull` before running** - Classic mistake, timeless lesson
6. **MagicDNS just works** - No need for `ansible_host` entries when using Tailscale hostnames

## Technical Details

### Tailscale ACL Configuration

Final ACL setup with tag-based access control:

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
        "users":  ["root", "autogroup:nonroot"],
    },
    {
        "action": "accept",
        "src":    ["tag:ci"],
        "dst":    ["tag:proxmox", "tag:k3s"],
        "users":  ["root", "autogroup:nonroot"],
    },
    {
        "action": "check",
        "src":    ["autogroup:member"],
        "dst":    ["autogroup:self"],
        "users":  ["autogroup:nonroot", "root"],
    },
],
```

This ensures:
- Admins can SSH to all infrastructure
- CI runners can ONLY SSH to tagged infrastructure (not personal devices)
- Regular users can SSH to their own devices with browser check

### GitHub Actions OAuth Setup

I used Tailscale OAuth instead of auth keys for better security:
- Automatic token rotation
- Ephemeral nodes (auto-cleanup)
- No long-lived credentials in GitHub Secrets
- Scoped access with tags

## Final Thoughts

What started as "SSH connection timeouts" turned into a complete CI/CD pipeline with:
- Automatic linting and testing on every PR
- Secure infrastructure access via Tailscale OAuth
- Tag-based ACL restrictions (CI runners can only access infrastructure, not personal devices)
- Manual deployment workflow for production changes
- Full dry-run validation before any real changes

The infrastructure is now protected by multiple layers:
1. Tailscale VPN (network level)
2. ACL tags (access level)
3. SSH keys (authentication level)
4. Ansible check mode (validation level)

And the best part? Every PR now gets automatically validated against the real infrastructure before merge. No more "works on my machine" - it either works on the actual Proxmox cluster or the PR stays red.

**Status:** Production-ready CI/CD pipeline

**Next up:**
- Issue #20: Clean up ansible-lint technical debt
- Issue #21: Speed up CI with custom Docker image
- Maybe Terraform CI/CD workflows?
