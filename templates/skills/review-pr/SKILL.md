---
name: review-pr
description: >
  PR review pipeline. Dev review, peer review, QA, security, architecture gate.
  Use when told to "review PR", "review changes", "check this PR".
disable-model-invocation: true
context: fork
agent: team-lead
---

# PR Review

Create `.claude/tasks/pr-review-{slug}/` and run:
1. **dev** → change scope, TDD compliance → `dev-1.md`
2. **dev** agents peer-review → `peer-review.md`
3. **qa** → e2e integration → `qa.md`
4. **security-reviewer** → audit → `security.md`
5. **architect** → compliance → `arch-gate.md`
6. `summary.md`: SHIP ✅ | COMMENTS ⚠️ | BLOCK 🛑

Track in `_status.md`.

---

PR context: $ARGUMENTS
