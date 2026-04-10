---
name: learn
description: "Extract reusable patterns from the current session and save them as skill files. Use when the user says 'learn from this', 'extract patterns', 'save this as a skill', 'what did we learn', or after solving a non-trivial debugging or integration problem worth capturing for future sessions."
---

# Extract Reusable Patterns

Analyze the current session and extract patterns worth saving as reusable skill files in `~/.claude/skills/learned/`.

## Workflow

### Step 1: Identify Extractable Patterns

Review the session for these pattern categories:

1. **Error Resolution** — Non-obvious root causes and their fixes (e.g., "Jest mock hoisting causes undefined when imported after mock setup — move `jest.mock()` above imports")
2. **Debugging Techniques** — Tool combinations or diagnostic sequences that worked (e.g., "Use `git bisect` + `vitest --reporter=verbose` to isolate flaky test to specific commit")
3. **Workarounds** — Library quirks, API limitations, version-specific fixes (e.g., "Next.js 14 `useSearchParams` requires `Suspense` boundary or build fails silently")
4. **Project Conventions** — Codebase patterns, architecture decisions, integration approaches discovered during the session

### Step 2: Evaluate Reusability

Skip patterns that are:
- Trivial fixes (typos, simple syntax errors)
- One-time issues (specific API outages, transient failures)
- Already documented in project README or CLAUDE.md

Keep patterns that:
- Would save 5+ minutes if encountered again
- Apply across multiple projects or contexts
- Involve non-obvious behavior or undocumented quirks

### Step 3: Draft the Skill File

Create `~/.claude/skills/learned/[pattern-name].md` using this structure:

```markdown
# [Descriptive Pattern Name]

**Extracted:** [Date]
**Context:** [Brief description of when this applies]

## Problem
[What problem this solves — be specific about symptoms]

## Solution
[The pattern/technique/workaround — include concrete steps]

## Example
[Code example if applicable]

## When to Use
[Trigger conditions — what should activate this skill]
```

### Step 4: Confirm and Save

1. Present the drafted skill to the user with a summary of what was captured
2. Ask for confirmation before writing the file
3. Save to `~/.claude/skills/learned/` on approval

## Guidelines

- One pattern per skill file — keep each focused and self-contained
- Use kebab-case for filenames (e.g., `jest-mock-hoisting-fix.md`)
- Include concrete examples with real code when possible
- Write trigger conditions that help future sessions auto-activate the pattern
