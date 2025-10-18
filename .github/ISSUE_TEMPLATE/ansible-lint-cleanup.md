---
name: Ansible Lint Cleanup
about: Track ansible-lint rule violations that need to be fixed
title: 'ansible: fix ansible-lint violations'
labels: technical-debt, ansible
assignees: ''
---

## Summary
We're currently skipping several ansible-lint rules to get CI/CD working. These should be fixed in a future PR to improve code quality and maintainability.

## Rules Currently Skipped

### 1. `fqcn[action-core]` - Use Fully Qualified Collection Names
**Impact:** ~116 violations
**Fix:** Convert all module calls to use FQCN format

**Example:**
```yaml
# Current
- name: Install package
  apt:
    name: vim

# Should be
- name: Install package
  ansible.builtin.apt:
    name: vim
```

**Files affected:** All roles and playbooks

---

### 2. `yaml[truthy]` - Use proper boolean values
**Impact:** ~32 violations
**Fix:** Convert `yes/no` to `true/false`

**Example:**
```yaml
# Current
become: yes
state: present

# Should be
become: true
state: present
```

**Files affected:** All playbooks and task files

---

### 3. `var-naming[no-role-prefix]` - Variables should use role prefix
**Impact:** ~26 violations
**Fix:** Rename variables in roles to include role prefix

**Example:**
```yaml
# Current (in nut role)
ups_name: myups
ups_port: /dev/ttyS0

# Should be
nut_ups_name: myups
nut_ups_port: /dev/ttyS0
```

**Files affected:**
- `roles/nut/defaults/main.yml`
- `roles/nut/tasks/*.yml`
- `roles/tailscale/tasks/*.yml`

**Note:** This will require updating all references in templates, tasks, and group_vars

---

### 4. `risky-file-permissions` - Set explicit file permissions
**Impact:** ~8 violations
**Fix:** Add explicit `mode` parameter to file operations

**Example:**
```yaml
# Current
- name: Create config file
  copy:
    dest: /etc/config.conf
    content: "..."

# Should be
- name: Create config file
  copy:
    dest: /etc/config.conf
    content: "..."
    mode: '0644'
```

**Files affected:**
- `roles/nut/tasks/*.yml`
- `roles/proxmox/tasks/*.yml`

---

### 5. `risky-shell-pipe` - Add pipefail to shell pipes
**Impact:** ~8 violations
**Fix:** Set `pipefail` option when using pipes in shell commands

**Example:**
```yaml
# Current
shell: tailscale status --json | jq -r '.Self.DNSName'

# Should be
shell: |
  set -o pipefail
  tailscale status --json | jq -r '.Self.DNSName'
args:
  executable: /bin/bash
```

**Files affected:** Tailscale and NUT verification tasks

---

### 6. `no-changed-when` - Mark command idempotency
**Impact:** ~11 violations
**Fix:** Add `changed_when` to command/shell tasks

**Example:**
```yaml
# Current
- name: Check status
  command: upsc myups

# Should be
- name: Check status
  command: upsc myups
  changed_when: false
```

**Files affected:** Commands that are read-only checks

---

### 7. `command-instead-of-module` - Use proper module
**Impact:** 1 violation
**Fix:** Consider alternatives to curl for GPG key download

**File:** `roles/tailscale/tasks/install.yml`

**Current approach works but might be improved with `get_url` + `command` for dearmoring**

---

## Acceptance Criteria

- [ ] All ansible-lint rules pass without skip_list
- [ ] Playbooks still work correctly after changes
- [ ] Variables renamed with role prefix (update all references)
- [ ] CI passes with stricter linting

## Notes

- This can be done incrementally (one rule type at a time)
- Test thoroughly - variable renames will touch many files
- Consider doing FQCN conversion with automated tools
- Archive directory is already excluded - no need to fix those files
