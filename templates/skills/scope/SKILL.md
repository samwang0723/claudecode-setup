---
name: scope
description: >
  Project scoping. Requirements, estimates, design, early security flags.
  Use when asked to "scope", "estimate", "how long", "plan this".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Project Scoping

Create `.claude/tasks/scope-{slug}/` and run:
1. **pm** → MoSCoW, estimates, risks → `pm.md`
2. **architect** → design, diagram, areas → `architect.md`
3. **security-reviewer** → early flags → `security.md`
4. `summary.md` with go/no-go. Track in `_status.md`.

---

Project: $ARGUMENTS
