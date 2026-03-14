---
name: lead-start
description: >
  Start a new engineering task or resume an existing one. Main entry point.
  Creates task folder, worktrees, delegates through team-lead.
  Supports --devs N (1-5). Use when told to "start", "build", "implement",
  "work on", "resume", or a task slug is referenced.
disable-model-invocation: true
context: fork
agent: team-lead
---

# Lead Start — Task Pipeline Entry Point

## Syntax
```
/lead-start [--devs N] <task description or existing slug>
```

## Parse input
- Extract `--devs N` if present (1-5). If absent → architect decides.
- Remaining text = task description or slug.
- Slugify: lowercase, hyphens, no special chars.

| Input | devs | slug |
|-------|------|------|
| `--devs 2 add rate limiting` | 2 | add-rate-limiting |
| `--devs 1 fix auth bug` | 1 | fix-auth-bug |
| `implement OAuth2 PKCE` | TBD | oauth2-pkce |
| `oauth2-pkce` | from _status.md | oauth2-pkce |

## If RESUMING (.claude/tasks/{slug}/_status.md exists):
1. Read `_status.md` → Phase, dev_count, next unchecked item.
2. Read all completed role files.
3. DO NOT redo completed phases.
4. If `--devs N` differs from existing, warn Master.
5. Report: "Resuming '{title}' — {Phase}. {N} devs. Next: {next}."

## If NEW:
1. Create `.claude/tasks/{slug}/` + `_status.md`.
2. Set `Devs: {N}` or `TBD`.
3. Report: "Starting '{title}'. PLAN phase."
4. Execute PLAN: pm → architect.

## Pipeline
```
PLAN → BUILD (TDD ×N, worktrees) → PEER_REVIEW → MERGE → QA → GATE → DONE
```

---

Master's request: $ARGUMENTS
