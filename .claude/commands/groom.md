---
description: Groom the GitHub backlog (oldest first), propose changes, apply after approval
argument-hint: "[optional: label or theme to focus on, e.g. group:backup]"
allowed-tools: Bash(gh issue list:*), Bash(gh issue view:*), Bash(gh label list:*), Bash(gh pr list:*), Bash(git log:*), Read, Grep, Glob
---

# Backlog grooming

Focus: $ARGUMENTS (if empty, groom the whole open backlog)

You are grooming the issues in this repo. Grooming is triage, not implementation:
do not write code, open branches, or touch hosts.

## 1. Gather (read-only)

- `gh issue list --state open --limit 300 --json number,title,labels,createdAt,updatedAt,body`
- `gh pr list --state all --limit 50` so you can spot issues already fixed by a merged PR
- `git log --oneline -100` for the same reason
- Read the relevant code or inventory when an issue's status is unclear. Verify, don't guess.

## 2. Sweep oldest first

For every issue, decide one of:

| Action | When |
|---|---|
| **close** | done (cite the PR/commit), obsolete, superseded, or too vague to act on. Old vague issues cost more to groom than to re-file. |
| **merge** | duplicate of another issue (theme overlap: backup, CI, Tailscale are repeat offenders). Say which one survives. |
| **rewrite** | real but vague: propose a clear title plus a body with Context, Acceptance criteria, Verification steps. |
| **relabel** | labels missing or wrong. |
| **keep** | fine as is. |

## 3. Labels

- Exactly one priority: `priority:critical|high|medium|low` (definitions in CLAUDE.md).
  Legacy `P0-P3`, `critical`, `important`, `nice-to-have` labels: propose replacing with the `priority:` equivalent.
- **Cap `priority:high` at 5.** If more qualify, rank them and demote the rest. If everything is high, nothing is.
- One `group:*` label where one fits.
- Readiness, exactly one of:
  - `agent:ready`: clear acceptance criteria AND doable entirely as a repo change verified by
    `ansible-lint`, `--check --diff`, `hugo`, or tests. No secrets, no vault edits, no hardware,
    no deploy needed to know it is correct.
  - `needs:human`: needs physical access, BIOS/firmware, UPS, vault secrets, a purchase,
    a decision only the user can make, or a live change on a host.
  - neither: still needs refinement; say what question blocks it.

## 4. Report, then STOP for approval

Print a table: `# | title | action | priority | group | readiness | reason`, grouped by action,
then a short list of the top 5 `agent:ready` issues in suggested work order.

Do not change anything on GitHub yet. Wait for the user to approve (they may approve
all, some, or edit the plan).

## 5. Apply (only after approval)

- Use `gh issue edit` / `gh issue close --comment "<reason>"` / `gh issue comment`.
- Every close and merge gets a one-line comment saying why (and which PR or issue).
- If more than 5 closes were approved, apply them and then list the closed numbers so
  they are easy to reopen.
- Rewrites: keep the original text at the bottom under "Original description".
- No names, emails, public IPs, or tailnet domains in anything you write to GitHub.
- No em-dashes in issue text.
