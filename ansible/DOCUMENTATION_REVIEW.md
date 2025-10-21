# Ansible Documentation Review

**Date:** October 21, 2025
**Reviewer:** Claude Code

## Summary

Overall, the Ansible documentation is **well-structured and accurate**. Found a few minor discrepancies and opportunities for improvement.

---

## Files Reviewed

1. `ansible/README.md` - Main Ansible documentation ✅
2. `ansible/inventory/README.md` - Inventory documentation ✅
3. `ansible/roles/nut/UPS-SHUTDOWN.md` - NUT configuration docs ✅

---

## Findings & Recommendations

### ✅ What's Correct

1. **Structure diagram** - Accurate representation of directory layout
2. **Vault management** - Commands are correct
3. **Running playbooks** - All examples work correctly
4. **Inventory groups** - Correctly documented
5. **UPS shutdown documentation** - Technically accurate and detailed
6. **Role descriptions** - Proxmox, Tailscale, NUT roles accurately described

### ⚠️ Issues Found

#### 1. Missing Documentation for netdata Role

**Issue:** The main README lists 3 roles (proxmox, tailscale, nut), but there's actually a 4th role: `netdata`

**Current State:**
- Role exists: `ansible/roles/netdata/`
- Playbook exists: `ansible/netdata_install.yml`
- **Not documented** in main README

**Recommendation:** Add netdata to the Roles section

```markdown
### netdata
Netdata monitoring setup including:
- Installation and configuration
- Claiming to Netdata Cloud
- Integration with vault for claim tokens
```

#### 2. k3s_cluster Workers Count Outdated

**Issue:** Inventory README says "k3s-worker-01 through k3s-worker-03" but inventory now has **6 workers** (01-06)

**Current Reality:**
```yaml
k3s_workers:
  hosts:
    k3s-worker-01:
    k3s-worker-02:
    k3s-worker-03:
    k3s-worker-04:  # Added recently
    k3s-worker-05:  # Added recently
    k3s-worker-06:  # Added recently
```

**Recommendation:** Update to "k3s-worker-01 through k3s-worker-06"

#### 3. Missing Playbooks in Documentation

**Issue:** Main README doesn't mention all playbooks

**Documented:**
- ✅ `site.yml`
- ✅ `verify_nut.yml`

**Not Documented:**
- ❌ `k3s_setup_tools.yml` - Installs vim/git on k3s nodes
- ❌ `netdata_install.yml` - Installs Netdata on all hosts

**Recommendation:** Add "Other Playbooks" section

#### 4. Inventory README: Missing ansible_host Details

**Issue:** The inventory README doesn't mention that some hosts have explicit `ansible_host` settings

**Current Reality:**
- Most hosts use DNS/hostname
- k3s-worker-04/05/06 have explicit IPs set
- This detail is not explained

**Recommendation:** Add note about when/why `ansible_host` is used

---

## Recommended Updates

### Update 1: ansible/README.md - Add netdata Role

**Location:** After line 98 (after nut role description)

```markdown
### netdata
Netdata monitoring setup including:
- Installation and configuration
- Claiming to Netdata Cloud with vault-stored tokens
- Monitoring for both Proxmox and k3s infrastructure

**Note:** Run via `netdata_install.yml` playbook, not included in `site.yml`
```

### Update 2: ansible/README.md - Add Other Playbooks Section

**Location:** After line 77 (after verify_nut.yml example)

```markdown
### Install Netdata monitoring
```bash
ansible-playbook -i inventory/homelab.yml --ask-vault-pass netdata_install.yml
```
Installs Netdata monitoring on all hosts (Proxmox + k3s).

### Install basic tools on k3s cluster
```bash
ansible-playbook -i inventory/homelab.yml k3s_setup_tools.yml
```
Installs vim and git on k3s nodes (no vault required).
```

### Update 3: ansible/inventory/README.md - Update Worker Count

**Location:** Line 52

**Change from:**
```markdown
- **k3s_workers:** `k3s-worker-01` through `k3s-worker-03` - Worker nodes
```

**Change to:**
```markdown
- **k3s_workers:** `k3s-worker-01` through `k3s-worker-06` - Worker nodes
```

### Update 4: ansible/inventory/README.md - Add ansible_host Note

**Location:** After line 61 (after host_vars section)

```markdown
## Ansible Connection Details

Most hosts are accessed by hostname via Tailscale DNS. Some hosts have explicit `ansible_host` settings:

- **k3s-worker-04/05/06:** Use direct IP addresses (10.150.10.169-171)
  - These were added before Tailscale DNS was fully configured
  - Can be simplified once hostnames resolve properly

To override connection details for any host, add to the inventory:
```yaml
hostname:
  ansible_host: 10.x.x.x
  ansible_user: ubuntu
  ansible_port: 22
```
```

### Update 5: ansible/README.md - Update Inventory Groups

**Location:** Line 100-104

**Current:**
```markdown
## Inventory Groups

- `nut_server`: Host with UPS directly connected (pve004)
- `nut_netclients`: Hosts that monitor UPS over network
- `proxmox`: Parent group containing all Proxmox hosts
```

**Add:**
```markdown
## Inventory Groups

### Proxmox Groups
- `nut_server`: Host with UPS directly connected (pve004)
- `nut_netclients`: Hosts that monitor UPS over network (pve001-003, pve005-007)
- `proxmox`: Parent group containing all Proxmox hosts

### k3s Groups
- `k3s_master`: Control plane node (k3s-master-01)
- `k3s_workers`: Worker nodes (k3s-worker-01 through k3s-worker-06)
- `k3s_cluster`: Parent group containing all k3s nodes
```

---

## Additional Recommendations

### 1. Add Quick Reference Section

Create a cheat sheet at the top of README.md:

```markdown
## Quick Reference

```bash
# Apply all configuration to homelab
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml

# Dry-run with preview
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --check --diff

# Run on single host
ansible-playbook -i inventory/homelab.yml --ask-vault-pass site.yml --limit pve001

# Install Netdata monitoring
ansible-playbook -i inventory/homelab.yml --ask-vault-pass netdata_install.yml

# Verify NUT UPS setup
ansible-playbook -i inventory/homelab.yml verify_nut.yml

# Install tools on k3s cluster
ansible-playbook -i inventory/homelab.yml k3s_setup_tools.yml
```
```

### 2. Create Role-Specific READMEs

Consider adding README.md files in each role directory:

- `ansible/roles/proxmox/README.md`
- `ansible/roles/tailscale/README.md`
- `ansible/roles/netdata/README.md`

The `nut` role already has excellent documentation with `UPS-SHUTDOWN.md`.

### 3. Document Recent Changes

Add a "Recent Changes" or "Migration Notes" section:

```markdown
## Recent Changes

- **Oct 2025:** Inventory restructured from single `inventory.ini` to `inventory/homelab.yml`
- **Oct 2025:** Added 3 new k3s workers (04, 05, 06) - cluster now has 7 nodes
- **Oct 2025:** Fixed Tailscale role to support both Debian and Ubuntu hosts
- **Oct 2025:** Added netdata monitoring role
```

### 4. Add Troubleshooting Section

```markdown
## Troubleshooting

### "No package matching 'tailscale' is available"
- **Cause:** OS detection issue in Tailscale role
- **Fix:** Already resolved in latest version (auto-detects Ubuntu vs Debian)

### "Vault password incorrect"
- **Cause:** Wrong vault password
- **Fix:** Ensure you're using the correct vault password from secure storage

### "SSH connection failed"
- **Cause:** Host not accessible
- **Check:**
  - Host is powered on
  - Tailscale is running on both ends
  - SSH keys are properly configured

### "Ansible host key checking failed"
- **Temporary fix:** `export ANSIBLE_HOST_KEY_CHECKING=False`
- **Proper fix:** Add host keys to known_hosts
```

---

## Priority Fixes

### High Priority
1. ✅ Add netdata role documentation
2. ✅ Update k3s worker count (01-06, not 01-03)
3. ✅ Document all playbooks

### Medium Priority
4. ✅ Add ansible_host explanation
5. ✅ Add Quick Reference section
6. ⚠️ Consider role-specific READMEs

### Low Priority
7. ⚠️ Add Recent Changes section
8. ⚠️ Add Troubleshooting section

---

## Conclusion

The documentation is **accurate and well-maintained**. The issues found are minor and primarily relate to:

1. Missing documentation for the `netdata` role
2. Outdated worker count (easy fix)
3. Missing some playbook examples

**Recommendation:** Apply the suggested updates to keep documentation in sync with current state.

**Overall Grade:** B+ (would be A with the suggested updates)
