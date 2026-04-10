---
name: strategic-compact
description: "Suggest manual /compact at logical workflow boundaries instead of relying on arbitrary auto-compaction. Use when the session approaches context limits, after completing a major milestone, when switching between unrelated tasks, or when responses become less coherent due to context pressure. Pairs with the suggest-compact.sh hook for automated threshold detection."
---

# Strategic Compact

Suggest manual `/compact` at logical workflow boundaries to preserve important context through task phases, rather than relying on auto-compaction that triggers at arbitrary points mid-task.

## Workflow

### Step 1: Assess Compaction Need

Check these indicators:

| Indicator | Action |
|-----------|--------|
| 50+ tool calls in session (hook fires) | Evaluate current phase before compacting |
| Transitioning from research → implementation | Compact — research context is bulky, plan is the distilled output |
| Just finished debugging a complex issue | Compact — debug traces pollute context for next task |
| Mid-implementation with active changes | Do NOT compact — losing file paths, variable names, and partial state is costly |
| Switching to an unrelated task | Compact — clear stale context before new focus |

### Step 2: Apply the Decision Guide

| Phase Transition | Compact? | Reason |
|-----------------|----------|--------|
| Research → Planning | Yes | Research context is bulky; plan is the distilled output |
| Planning → Implementation | Yes | Plan is in TodoWrite or a file; free up context for code |
| Implementation → Testing | Maybe | Keep if tests reference recent code; compact if switching focus |
| Debugging → Next feature | Yes | Debug traces pollute context for unrelated work |
| Mid-implementation | No | Losing variable names, file paths, and partial state is costly |
| After a failed approach | Yes | Clear the dead-end reasoning before trying a new approach |

### Step 3: Preserve Before Compacting

Before running `/compact`, save critical context:
1. Write important findings to files or `~/.claude/memory/`
2. Ensure the TodoWrite task list reflects current state
3. Commit any in-progress work to git
4. Add a summary message: `/compact Focus on implementing auth middleware next`

### What Survives Compaction

| Persists | Lost |
|----------|------|
| CLAUDE.md instructions | Intermediate reasoning and analysis |
| TodoWrite task list | File contents previously read |
| Memory files (`~/.claude/memory/`) | Multi-step conversation context |
| Git state (commits, branches) | Tool call history and counts |
| Files on disk | Nuanced user preferences stated verbally |

## Hook Setup

The `suggest-compact.sh` script (bundled with this skill) tracks tool calls and suggests compaction at configurable thresholds. Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "~/.claude/skills/strategic-compact/suggest-compact.sh" }]
      }
    ]
  }
}
```

Configure via environment variable: `COMPACT_THRESHOLD` (default: 50 tool calls before first suggestion, then every 25 calls after).

## Context Optimization Tips

- **Keep CLAUDE.md lean** — it loads into every conversation
- **Watch for duplicate rules** — same content in `~/.claude/rules/` and project `.claude/rules/`
- **Each loaded skill adds 1-5K tokens** — disable unused skills to free context
- **Large tool results (file reads, searches) accumulate fast** — compact after exploration-heavy phases
