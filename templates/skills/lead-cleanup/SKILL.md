---
name: lead-cleanup
description: >
  Remove git worktrees and branches for a completed task. Use after merging
  the integrate branch. Confirms before destructive action.
disable-model-invocation: true
context: fork
agent: team-lead
---

# Lead Cleanup

1. Parse $ARGUMENTS for task slug.
2. Confirm Phase is DONE in `_status.md`. Warn if not.
3. List worktrees + branches to remove. Ask Master to confirm.
4. Remove worktrees, delete branches, prune.
5. Update `_status.md` Worktrees → `(cleaned up {date})`.

---

Task: $ARGUMENTS
