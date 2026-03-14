---
name: lead-summary
description: >
  Quick progress summary of all tasks. Pipeline status, blockers, next actions.
  Use when asked for "status", "progress", "summary", "blockers", "what's happening".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Lead Summary

1. Scan all `.claude/tasks/*/` directories. Read each `_status.md`.
2. Report table: Task | Phase | Status | Updated | Blockers
3. For IN_PROGRESS tasks: last completed step, next step, blockers, decisions needed.
4. Suggest next actions.

If no tasks exist, say so and suggest `/lead-start`.

---

Focus (optional): $ARGUMENTS
