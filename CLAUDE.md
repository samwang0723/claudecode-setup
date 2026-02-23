# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shell-based installer that configures Claude Code with an SVP Engineering workflow: skills, agents, git worktree isolation, and stateful task tracking. All configuration targets `~/.claude/`.

## Repository Structure

- `install.sh` — Main installer. Creates agents (`~/.claude/agents/*.md`), skills (`~/.claude/skills/*/SKILL.md`), `settings.json` (backs up existing to `.bak` then overwrites), and appends to global `CLAUDE.md`. Appends skills section only if marker absent.
- `statusline.sh` — Claude Code status line hook. Reads JSON from stdin (model, cost, context usage, duration), outputs a formatted terminal line with color-coded context bar.
- `README.md` — User-facing docs with architecture diagram, skill reference, and pipeline overview.

## Running

```bash
chmod +x install.sh && ./install.sh
```

No build system, no tests, no dependencies beyond `jq` (auto-installed by the script) and the Claude Code CLI.

## Key Design Decisions

- **Heredoc-based file generation**: All agents and skills are generated via `cat > file << 'EOF'` heredocs inside `install.sh`. Editing agent/skill content means editing the corresponding heredoc block in `install.sh`, not separate files.
- **Backup then overwrite for settings.json**: Existing `settings.json` is backed up to `settings.json.bak` before overwriting with the latest config.
- **Append-only for CLAUDE.md**: Appended (not replaced) using a `$MARKER` grep guard (`## Architecture: Skills + Agents`). Existing file is backed up to `CLAUDE.md.bak` before appending.
- **Task state in `.claude/tasks/`**: All task tracking (`_status.md`, role reports) goes under `.claude/tasks/{slug}/` in the target project, keeping the project root clean.
- **YAML frontmatter in skills**: Each `SKILL.md` uses `context: fork` + `agent: team-lead` to run in isolated subagent context.
- **`$ARGUMENTS` placeholder**: Skills reference `$ARGUMENTS` for runtime argument injection by Claude Code.

## What the Installer Creates

| Target | Count | Purpose |
|--------|-------|---------|
| `~/.claude/agents/*.md` | 7 | team-lead, architect, dev, qa, security-reviewer, pm, explorer |
| `~/.claude/skills/*/SKILL.md` | 9 | lead-start, lead-summary, lead-cleanup, review-pr, arch-review, investigate, strategy, scope, quick-scan |
| `~/.claude/settings.json` | 1 | Permissions, model (opus), env vars, agent teams flag |
| `~/.claude/CLAUDE.md` | append | Skills+Agents architecture section |

## Shell Conventions

- `set -euo pipefail` — strict mode throughout
- Color constants (`BLUE`, `GREEN`, etc.) with `NC` reset
- Logging helpers: `log()`, `warn()`, `err()`, `info()` with status icons
- `statusline.sh` expects piped JSON input via `jq` — context percentage drives bar color (green < 70%, yellow 70-89%, red 90%+)
