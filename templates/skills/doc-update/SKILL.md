---
name: doc-update
description: >
  Review and update project documentation (README.md, CLAUDE.md, docs/) to reflect
  the current codebase. Use when the user asks to "update docs", "sync documentation",
  "refresh README", "update CLAUDE.md", or after significant code changes that may
  have made documentation stale. Also trigger when the user mentions "docs are outdated"
  or "documentation drift".
---

# Doc Update

Review and update project documentation to match the current state of the codebase.

## When to Use

- After adding/removing features, skills, agents, or configuration
- After refactoring that changes file structure, APIs, or workflows
- When the user suspects docs have drifted from reality
- Before releases to ensure documentation accuracy

## Process

### 1. Analyze the Codebase

Understand the current state before touching any docs:

- Read the project structure (files, directories, key modules)
- Check `git log --oneline -20` for recent changes that may not be reflected in docs
- Identify the tech stack, entry points, and key configuration files
- Note any new files, removed files, or renamed paths since docs were last updated

### 2. Audit Existing Documentation

For each documentation file, check for:

- **Accuracy**: Do file paths, command examples, and descriptions match reality?
- **Completeness**: Are new features, files, or workflows documented?
- **Staleness**: Are removed features still referenced? Are counts/numbers correct?
- **Consistency**: Do different docs agree with each other (e.g., skill count in README vs CLAUDE.md)?

#### Files to Review

| File | What to Check |
|------|---------------|
| `README.md` | Project overview, install instructions, feature lists, architecture diagrams, examples |
| `CLAUDE.md` | Repository structure, navigation guide, design decisions, file counts, conventions |
| `docs/**/*.md` | Any documentation files in the docs directory |

### 3. Report Findings

Before making changes, present a summary of what's stale or missing:

```
Documentation Audit:
- README.md: 3 issues (outdated skill count, missing new feature, stale file path)
- CLAUDE.md: 2 issues (wrong line count, missing section for new module)
- docs/api.md: up to date
```

### 4. Apply Updates

After the user confirms (or if invoked with `--yes`), update each file:

- Fix inaccurate paths, counts, and descriptions
- Add documentation for new features/files
- Remove references to deleted features/files
- Update architecture diagrams if structure changed
- Keep the existing writing style and formatting conventions of each file
- Do not rewrite sections that are still accurate — only change what needs changing

### 5. Verify Consistency

After updates, cross-check that all docs agree:

- Feature lists match across README.md and CLAUDE.md
- File counts and paths are consistent
- Command examples still work
- Links between docs are valid

## Guidelines

- Preserve the original author's voice and formatting style
- Don't add documentation for things that aren't there — only document what exists
- When in doubt about intent, ask rather than guess
- Keep diffs minimal — change only what's stale, not what's stylistically different
- If a `docs/` directory doesn't exist, skip that part — don't create one
- Numbers and counts should be derived from the actual codebase, not hardcoded

## Arguments

Focus area or scope: $ARGUMENTS

If no arguments provided, audit all documentation files found in the project root and `docs/` directory.
