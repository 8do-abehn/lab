---
description: Hand one or more agent:ready issues to backlog-worker subagents (one worktree and PR each)
argument-hint: "<issue numbers, e.g. 512 530> | next [count]"
---

# Work issues

Arguments: $ARGUMENTS

1. Resolve the issue list:
   - Numbers given: use them.
   - `next [count]` (default 1): `gh issue list --state open --label agent:ready --json number,title,labels`
     and pick by priority (critical, high, medium, low), oldest first within a priority.
     Skip anything already labeled `in progress` or with an open PR referencing it.
2. Confirm every issue has `agent:ready`. Drop any that don't and say why.
3. Check for overlap: if two issues touch the same role or file, run them one after another, not in parallel.
4. Launch one `backlog-worker` subagent per issue (parallel when independent, max 3 at once),
   each with the prompt: "Work issue #<N>."
5. When they finish, print a summary table: issue, PR URL, CI status, deploy command, manual steps.
   Do not merge or deploy anything.
