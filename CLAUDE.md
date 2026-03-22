# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shell-based installer that configures Claude Code with a Master Engineering workflow: skills, agents, git worktree isolation, and stateful task tracking. All configuration targets `~/.claude/`.

## Repository Structure

- `install.sh` — Main installer (~900 lines). Copies templates, merges settings (with jq), and handles backup/revert. Supports `--revert`, `--dry-run`, and `--yes` flags.
- `templates/` — 1:1 mirror of `~/.claude/` structure. Edit these directly, then re-run `./install.sh` to copy.
  - `templates/agents/*.md` — 8 agent definitions
  - `templates/skills/*/` — 25 skill directories (entire directories copied, not just SKILL.md)
  - `templates/powerline.json` — claude-powerline status line config
  - `templates/rules/*/` — 5 rule directories (kit, common, golang, python, typescript), auto-discovered and copied
  - `templates/sample-claude.md` — Reference template for `~/.claude/CLAUDE.md` (not auto-installed)
- `statusline.sh` — Legacy status line hook (replaced by `claude-powerline` in v6).
- `README.md` — User-facing docs with architecture diagram, skill reference, and pipeline overview.

## Running

```bash
chmod +x install.sh && ./install.sh     # install/update
./install.sh --revert                    # one-click uninstall
./install.sh --dry-run                   # preview changes without modifying files
./install.sh --yes                       # auto-approve prompts
```

No build system, no tests, no dependencies beyond `jq` (auto-installed by the script), `@owloops/claude-powerline` (auto-installed), RTK (auto-installed), and the Claude Code CLI.

## Navigating install.sh

The installer is organized into numbered sections delimited by comment bars (`# ---...---`):

| Section | What it does |
|---------|--------------|
| Top (after helpers) | `SCRIPT_DIR`, `TEMPLATES_DIR`, `manifest()`, `install_template()`, `revert_kit()`, flag parsing |
| 0. Pre-flight | Checks for `claude` CLI, `jq`, `claude-powerline`, and `templates/` directory |
| 1. Directories + manifest init | Creates `agents/`, rule dirs, `skills/*/`; initializes manifest |
| 2. settings.json | jq deep-merge with existing (kit defaults as base, user values win); statusLine force-override; backup to `.kit-backup/` |
| 2b. powerline.json | Copies claude-powerline config with backup of existing |
| 3. Rules | Auto-discovers all `templates/rules/*/` directories and copies entire directories |
| 4. Agents | Copies 8 agent `.md` files from `templates/agents/` |
| 5. Skills | Copies 25 entire skill directories from `templates/skills/` |
| 6. Cleanup | Warns about deprecated `~/.claude/commands/` |
| 7. RTK | Installs RTK (Rust Token Killer) token-optimized CLI proxy; runs `rtk init -g` |
| 8. Agent Browser | Optional: installs agent-browser for browser automation |
| 9. Visual Explainer | Optional: installs visual-explainer plugin for diagrams and slides |
| 10. Summary | Final output with revert instructions |

## Key Design Decisions

- **Template-based file generation**: `templates/` mirrors the `~/.claude/` directory structure 1:1. The installer copies each file via `install_template <relative-path>` (e.g. `install_template "agents/dev.md"` → `~/.claude/agents/dev.md`). No name mapping or path translation. Only `settings.json` (which requires jq merge) uses inline shell logic.
- **jq deep-merge for settings.json**: Existing `settings.json` is backed up to `.kit-backup/`, then merged with kit defaults using a recursive `deep_merge` jq function. User values win for scalars/objects; arrays (permissions) are unioned and deduplicated.
- **Rules auto-discovery**: The installer auto-discovers all subdirectories in `templates/rules/` (kit, common, golang, python, typescript) and copies entire directories to `~/.claude/rules/`. Claude Code auto-loads all files in `rules/*/`. The installer never appends to `~/.claude/CLAUDE.md` — it only strips legacy markers if found from previous installs.
- **statusLine force-override**: After jq deep-merge, `statusLine` is force-overridden from kit defaults to ensure it always updates on reinstall (user values don't win for this key).
- **Backup manifest**: `~/.claude/.kit-manifest` tracks all created/modified files. `~/.claude/.kit-backup/` stores pre-install copies. `./install.sh --revert` reads the manifest to delete kit files and restore backups.
- **YAML frontmatter in skills**: Most pipeline skills use `context: fork` + `agent: team-lead` to run in isolated subagent context. Exception: `/team-start` executes directly in main session (no fork) to ensure proper tmux pane creation via `TeamCreate` tool.
- **`$ARGUMENTS` placeholder**: Skills reference `$ARGUMENTS` for runtime argument injection by Claude Code.
- **Task state in `.claude/tasks/`**: All task tracking (`_status.md`, role reports) goes under `.claude/tasks/{slug}/` in the target project.

## What the Installer Creates

| Target | Count | Purpose |
|--------|-------|---------|
| `~/.claude/agents/*.md` | 8 | team-lead, architect, dev, code-reviewer, qa, security-reviewer, pm, explorer |
| `~/.claude/agents/memory/` | dir | Agent learning logs — persistent diary of lessons learned per agent |
| `~/.claude/skills/*/` | 25 | 9 pipeline + 3 team + 6 document/utility + 4 effective-* + 3 other skills |
| `~/.claude/rules/*/` | 5 dirs | kit, common, golang, python, typescript (auto-loaded by Claude Code rules) |
| `~/.claude/settings.json` | merge | Permissions, model, env vars, plugins (merged with existing) |
| `~/.claude/powerline.json` | 1 | claude-powerline status line config |
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
- Status line uses `claude-powerline` with config at `~/.claude/powerline.json`

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

To modify kit rules content: edit files in `templates/rules/*/` (e.g., `templates/rules/kit/CLAUDE-kit.md`, `templates/rules/common/*.md`).
