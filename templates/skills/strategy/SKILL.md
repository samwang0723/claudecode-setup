---
name: strategy
description: >
  Strategic technical decision. Build-vs-buy, technology choices.
  Use when asked "should we", "compare", "build vs buy", "evaluate".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Strategic Decision

Create `.claude/tasks/strategy-{slug}/` and run:
1. **pm** → requirements, cost → `pm.md`
2. **architect** → options, diagrams, tradeoffs → `architect.md`
3. **security-reviewer** → compliance → `security.md`
4. `summary.md`: recommendation + tradeoffs + risks. Track in `_status.md`.

---

Decision: $ARGUMENTS
