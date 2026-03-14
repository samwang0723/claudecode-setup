---
name: quick-scan
description: >
  Fast codebase health check. Structure, stack, dependencies, test status.
  Use when asked to "scan", "health check", "quick look".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Quick Scan

Create `.claude/tasks/scan-{slug}/` and run:
1. **explorer** → structure, stack, deps
2. **dev** → recent activity, tests, issues
3. **qa** → quick quality check
4. Brief `summary.md`. Track in `_status.md`.

---

Focus: $ARGUMENTS
