# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shell-based installer that configures Claude Code with a Master Engineering workflow: skills, agents, git worktree isolation, and stateful task tracking. All configuration targets `~/.claude/`.

## Repository Structure

- `install.sh` — Main installer (~750 lines). Copies templates, merges settings (with jq), and handles backup/revert. Supports `--revert` for one-click uninstall.
- `templates/` — 1:1 mirror of `~/.claude/` structure. Edit these directly, then re-run `./install.sh` to copy.
  - `templates/agents/*.md` — 7 agent definitions
  - `templates/skills/*/SKILL.md` — 12 skill definitions (matches Claude Code's `skills/<name>/SKILL.md` layout)
  - `templates/rules/kit/CLAUDE-kit.md` — Kit documentation (auto-loaded by Claude Code rules)
  - `templates/sample-claude.md` — Reference template for `~/.claude/CLAUDE.md` (not auto-installed)
- `statusline.sh` — Claude Code status line hook. Reads JSON from stdin via `jq`, outputs a formatted terminal line with color-coded context bar (green <70%, yellow 70-89%, red 90%+).
- `remove-md-hook.sh` — Utility to remove the everything-claude-code plugin's PreToolUse hook that blocks Write operations on `.md`/`.txt` files.
- `README.md` — User-facing docs with architecture diagram, skill reference, and pipeline overview.

## Running

```bash
chmod +x install.sh && ./install.sh     # install/update
./install.sh --revert                    # one-click uninstall
```

No build system, no tests, no dependencies beyond `jq` (auto-installed by the script) and the Claude Code CLI.

## Navigating install.sh

The installer is organized into numbered sections delimited by comment bars (`# ---...---`):

| Section | What it does |
|---------|--------------|
| Top (after helpers) | `SCRIPT_DIR`, `TEMPLATES_DIR`, `manifest()`, `install_template()`, `revert_kit()`, flag parsing |
| 0. Pre-flight | Checks for `claude` CLI, `jq`, and `templates/` directory |
| 1. Directories + manifest init | Creates `agents/`, `rules/kit/`, `skills/*/`; initializes manifest |
| 2. settings.json | jq deep-merge with existing (kit defaults as base, user values win); backup to `.kit-backup/` |
| 2b. statusline.sh | Copies with backup of existing |
| 3. Kit rules | Copies `templates/rules/CLAUDE-kit.md`; strips legacy CLAUDE.md markers if present |
| 4. Agents | Copies 7 agent `.md` files from `templates/agents/` |
| 5. Skills | Copies 12 skill `.md` files from `templates/skills/` |
| 6. Cleanup | Warns about deprecated `~/.claude/commands/` |
| 7. claude-squad | Optional installation prompt |
| 8. Summary | Final output with revert instructions |

## Key Design Decisions

- **Template-based file generation**: `templates/` mirrors the `~/.claude/` directory structure 1:1. The installer copies each file via `install_template <relative-path>` (e.g. `install_template "agents/dev.md"` → `~/.claude/agents/dev.md`). No name mapping or path translation. Only `settings.json` (which requires jq merge) uses inline shell logic.
- **jq deep-merge for settings.json**: Existing `settings.json` is backed up to `.kit-backup/`, then merged with kit defaults using a recursive `deep_merge` jq function. User values win for scalars/objects; arrays (permissions) are unioned and deduplicated.
- **Kit rules in `~/.claude/rules/kit/`**: Kit content (skills, agents, teams documentation) is written to `~/.claude/rules/kit/CLAUDE-kit.md` which Claude Code auto-loads via the rules system. The installer never appends to `~/.claude/CLAUDE.md` — it only strips legacy markers if found from previous installs.
- **Backup manifest**: `~/.claude/.kit-manifest` tracks all created/modified files. `~/.claude/.kit-backup/` stores pre-install copies. `./install.sh --revert` reads the manifest to delete kit files and restore backups.
- **YAML frontmatter in skills**: Most pipeline skills use `context: fork` + `agent: team-lead` to run in isolated subagent context. Exception: `/team-start` executes directly in main session (no fork) to ensure proper tmux pane creation via `TeamCreate` tool.
- **`$ARGUMENTS` placeholder**: Skills reference `$ARGUMENTS` for runtime argument injection by Claude Code.
- **Task state in `.claude/tasks/`**: All task tracking (`_status.md`, role reports) goes under `.claude/tasks/{slug}/` in the target project.

## What the Installer Creates

| Target | Count | Purpose |
|--------|-------|---------|
| `~/.claude/agents/*.md` | 7 | team-lead, architect, dev, qa, security-reviewer, pm, explorer |
| `~/.claude/skills/*/SKILL.md` | 12 | 9 pipeline + 3 team skills |
| `~/.claude/rules/kit/CLAUDE-kit.md` | 1 | Kit documentation (auto-loaded by Claude Code rules) |
| `~/.claude/settings.json` | merge | Permissions, model, env vars, plugins (merged with existing) |
| `~/.claude/statusline.sh` | 1 | Status line display hook |
| `~/.claude/.kit-manifest` | 1 | Tracks all created/modified files for revert |
| `~/.claude/.kit-backup/` | dir | Pre-install backups of modified files |

## settings.json Merge Strategy

| Field type | Strategy |
|-----------|----------|
| Scalars (`model`, `cleanupPeriodDays`) | Kit provides defaults; user value wins if present |
| Objects (`env`, `enabledPlugins`, `hooks`) | Deep merge; user values win per key |
| Arrays (`permissions.allow`, `permissions.deny`) | Union + deduplicate |

## Shell Conventions

- `set -euo pipefail` — strict mode throughout
- Color constants (`BLUE`, `GREEN`, etc.) with `NC` reset
- Logging helpers: `log()`, `warn()`, `err()`, `info()` with status icons
- `manifest()` helper appends entries to `.kit-manifest`
- `statusline.sh` expects piped JSON input with fields: `model`, `cost`, `context_window`, `workspace`

## Editing Content

To modify agent or skill definitions:

1. Edit the file in `templates/` (same path as `~/.claude/`)
2. Re-run `./install.sh` to copy updated files

To sync from your live `~/.claude/` back to the repo (paths are identical):
```bash
cp ~/.claude/agents/team-lead.md templates/agents/team-lead.md
cp ~/.claude/skills/lead-start/SKILL.md templates/skills/lead-start/SKILL.md
```

To modify kit defaults for settings.json: edit the `KIT_DEFAULTS` variable in section 2 of `install.sh`.

To modify kit rules content: edit `templates/rules/CLAUDE-kit.md`.
