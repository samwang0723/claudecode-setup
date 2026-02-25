# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shell-based installer that configures Claude Code with a Master Engineering workflow: skills, agents, git worktree isolation, and stateful task tracking. All configuration targets `~/.claude/`. Uses AWS Bedrock for model access.

## Repository Structure

- `install.sh` — Main installer. Prompts for AWS SSO profile, creates agents (`~/.claude/agents/*.md`), skills (`~/.claude/skills/*/SKILL.md`), `settings.json` (backs up to `.bak` then overwrites), and appends to global `CLAUDE.md`.
- `statusline.sh` — Claude Code status line hook. Reads JSON from stdin (model, cost, context usage, duration), outputs a formatted terminal line with color-coded context bar (green <70%, yellow 70-89%, red 90%+).
- `README.md` — User-facing docs with architecture diagram, skill reference, and pipeline overview.

## Running

```bash
chmod +x install.sh && ./install.sh
```

No build system, no tests, no dependencies beyond `jq` (auto-installed by the script) and the Claude Code CLI.

## Key Design Decisions

- **Heredoc-based file generation**: All agents and skills are generated via `cat > file << 'EOF'` heredocs inside `install.sh`. Editing agent/skill content means editing the corresponding heredoc block in `install.sh`, not separate files.
- **Backup then overwrite for settings.json**: Existing `settings.json` is backed up to `settings.json.bak` before overwriting.
- **Append-only for CLAUDE.md**: Appended (not replaced) using `$MARKER` grep guards (`## Architecture: Skills + Agents` and `## Agent Teams (Experimental)`). Existing file is backed up to `CLAUDE.md.bak` before appending. Two separate marker checks for skills+agents vs agent teams sections.
- **Task state in `.claude/tasks/`**: All task tracking (`_status.md`, role reports) goes under `.claude/tasks/{slug}/` in the target project.
- **YAML frontmatter in skills**: Most pipeline skills use `context: fork` + `agent: team-lead` to run in isolated subagent context. Exception: `/team-start` executes directly in main session (no fork) to ensure proper tmux pane creation via `TeamCreate` tool.
- **`$ARGUMENTS` placeholder**: Skills reference `$ARGUMENTS` for runtime argument injection by Claude Code.

## What the Installer Creates

| Target                        | Count  | Purpose                                                                                                                                                             |
| ----------------------------- | ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `~/.claude/agents/*.md`       | 7      | team-lead, architect, dev, qa, security-reviewer, pm, explorer                                                                                                      |
| `~/.claude/skills/*/SKILL.md` | 12     | 9 pipeline (lead-start, lead-summary, lead-cleanup, review-pr, arch-review, investigate, strategy, scope, quick-scan) + 3 team (team-start, team-status, team-stop) |
| `~/.claude/settings.json`     | 1      | AWS Bedrock config, permissions, model (claude-opus-4-6), enabled plugins                                                                                           |
| `~/.claude/statusline.sh`     | 1      | Status line display hook                                                                                                                                            |
| `~/.claude/CLAUDE.md`         | append | Skills+Agents architecture section + Agent Teams section                                                                                                            |

## settings.json Structure

The generated `settings.json` includes:

- `env` — AWS region (ap-southeast-1), profile, Bedrock flag, model IDs for Opus/Sonnet/Haiku
- `model` — `claude-opus-4-6[1m]`
- `permissions` — allow/deny lists for tools and bash commands
- `statusLine` — points to `~/.claude/statusline.sh`
- `enabledPlugins` — default set of Claude Code plugins

## Shell Conventions

- `set -euo pipefail` — strict mode throughout
- Color constants (`BLUE`, `GREEN`, etc.) with `NC` reset
- Logging helpers: `log()`, `warn()`, `err()`, `info()` with status icons
- `statusline.sh` expects piped JSON input via `jq`

## Editing Content

To modify agent or skill definitions:

1. Find the corresponding heredoc block in `install.sh` (search for `cat >"$AGENTS_DIR/` or `cat >"$SKILLS_DIR/`)
2. Edit the content between `<< 'EOF'` (or `<< 'AGENT_EOF'` / `<< 'SKILL_EOF'`) and the closing delimiter
3. Re-run `./install.sh` to regenerate files
