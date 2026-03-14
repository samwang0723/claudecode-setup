---
name: arch-review
description: >
  Architecture review. Codebase exploration, mermaid diagrams, threat model,
  operational risk. Use when asked for "arch review", "architecture audit".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Architecture Review

Create `.claude/tasks/arch-review-{slug}/` and run:
1. **explorer** → codebase map → `dev-1.md`
2. **architect** → assessment + mermaid → `architect.md`
3. **security-reviewer** → STRIDE → `security.md`
4. **pm** → operational risk → `pm.md`
5. Synthesize → `summary.md`. Track in `_status.md`.

---

Focus: $ARGUMENTS
