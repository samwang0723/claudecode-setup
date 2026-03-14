---
name: investigate
description: >
  Incident investigation. Logs, changes, root cause, blast radius.
  Use when told to "investigate", "debug", "what happened", "why broken".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Incident Investigation

Create `.claude/tasks/incident-{slug}/` and run:
1. **dev** → logs, changes, errors → `dev-1.md`
2. **architect** → system impact → `architect.md`
3. If security: **security-reviewer** → `security.md`
4. `summary.md`: Timeline → Root Cause → Blast Radius → Fix → Prevention.
Track in `_status.md`.

---

Issue: $ARGUMENTS
