---
name: team-stop
description: >
  Clean up an agent team. Removes team resources, optionally cleans worktrees
  and branches. Use after team work is complete and merged.
  Use when told to "stop team", "cleanup team", "disband team".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Team Stop — Clean Up Agent Team

## Syntax
```
/team-stop <team-name>
```

## Steps

### 1. Verify Completion
1. Read `.claude/tasks/{slug}/_status.md`.
2. Check phase — warn if not DONE or COMPLETED.
3. Check all `dev-{N}.md` reports exist.
4. List any incomplete tasks.

### 2. Confirm with Master
Present what will be cleaned up:
```
## Team Cleanup: {slug}

Resources to remove:
- Team config: ~/.claude/teams/{slug}/
- Worktrees: .worktrees/{slug}/dev-{1..N}/
- Branches: {slug}/dev-{1..N}

Resources to KEEP:
- Task docs: .claude/tasks/{slug}/*.md
- Integrate branch: {slug}/integrate (if exists)

Proceed? (awaiting confirmation)
```

### 3. Clean Up (after Master confirms)
1. Load `TeamDelete` tool (via ToolSearch) → delete team config.
2. **Kill all idle agent tmux panes but leave the main session intact.**
   List tmux panes, identify agent/teammate panes, and kill them individually:
   ```bash
   # Kill agent panes (NOT the main session pane)
   tmux list-panes -a -F '#{pane_id} #{pane_title}' | grep -i 'teammate\|agent\|dev-' | awk '{print $1}' | xargs -I{} tmux kill-pane -t {}
   ```
3. **Check for uncommitted changes** in each worktree before removal:
   ```bash
   cd .worktrees/{slug}/dev-{N} && git status --porcelain
   ```
   If any worktree has uncommitted changes, warn Master and list the affected files.
   Do NOT proceed with removal until Master confirms it is safe to discard or commits are made.
4. Remove worktrees:
   ```bash
   git worktree remove .worktrees/{slug}/dev-{N} --force
   ```
5. Delete dev branches:
   ```bash
   git branch -D {slug}/dev-{N}
   ```
6. Remove empty worktree directories.
7. Update `_status.md`:
   - Worktrees → `(cleaned up {date})`
   - Add note: "Team disbanded. Task docs preserved."

### 4. Report
```
## Team Cleaned Up: {slug}
- Removed: {N} worktrees, {N} branches, team config
- Preserved: .claude/tasks/{slug}/ (all reports)
- Integrate branch: {kept/removed} based on merge status
```

**NEVER auto-clean without Master confirmation.**

---

Team: $ARGUMENTS
