# Ansible: Fix ansible-lint violations

**Labels:** `technical-debt`, `ansible`, `enhancement`

## Summary
We're currently skipping several ansible-lint rules to get CI/CD working. These should be fixed to improve code quality and maintainability.

## Current Skip List

```yaml
skip_list:
  - fqcn[action-core]  # ~116 violations - Use FQCN for modules
  - yaml[truthy]  # ~32 violations - Use true/false instead of yes/no
  - var-naming[no-role-prefix]  # ~26 violations - Add role prefix to variables
  - risky-file-permissions  # ~8 violations - Set explicit file modes
  - risky-shell-pipe  # ~8 violations - Add pipefail to shell pipes
  - no-changed-when  # ~11 violations - Mark command idempotency
  - command-instead-of-module  # 1 violation - Use proper module
```

## Tasks

### Phase 1: Quick Wins (Low Risk)
- [ ] Fix `yaml[truthy]` - Convert yes/no to true/false (~32 files)
- [ ] Fix `risky-file-permissions` - Add explicit mode to file ops (~8 tasks)
- [ ] Fix `no-changed-when` - Add changed_when to read-only commands (~11 tasks)

### Phase 2: Moderate Changes
- [ ] Fix `fqcn[action-core]` - Use fully qualified module names (~116 violations)
  - Can use automated tools: `ansible-lint --write`
- [ ] Fix `risky-shell-pipe` - Add pipefail to pipes (~8 tasks)

### Phase 3: Breaking Changes (Requires Testing)
- [ ] Fix `var-naming[no-role-prefix]` - Rename role variables (~26 variables)
  - Affects: `roles/nut/`, `roles/tailscale/`
  - Must update: defaults, tasks, handlers, group_vars, host_vars
  - **High risk** - test thoroughly

### Phase 4: Optional
- [ ] Fix `command-instead-of-module` - Improve GPG key handling (1 task)

## Priority
**Medium** - Not blocking, but should be addressed to maintain code quality standards.

## Notes
- Can be done incrementally (one phase at a time)
- Archive directory already excluded - ignore those files
- Test each phase thoroughly before moving to next
- Consider using `ansible-lint --write` for automated fixes where safe
