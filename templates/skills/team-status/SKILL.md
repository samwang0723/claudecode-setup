---
name: team-status
description: >
  Check progress of an active agent team. Shows member status, completed tasks,
  pending work, and any messages. Use when asked "team status", "how's the team",
  "check team progress", "team update".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Team Status — Monitor Agent Team Progress

## Syntax
```
/team-status [team-name]
```

## Steps

### 1. Find Teams
- If team-name provided: check `.claude/tasks/{team-name}/_status.md`
- If not provided: scan all `.claude/tasks/*/` for teams with Phase BUILD

### 2. Check Task State
1. Read `_status.md` for phase, status, member count.
2. Load `TaskList` tool (via ToolSearch) to get team task states.
3. Load `TaskGet` tool for detailed task info.

### 3. Check Worktrees
```bash
# List active worktrees for the team
git worktree list | grep {slug}
```
- Check if worktrees exist and have recent commits
- Report last commit date/message per worktree

### 4. Check Member Reports
- Look for `dev-{N}.md` files in `.claude/tasks/{slug}/`
- If present → member has reported completion
- If absent → member still working or hasn't started

### 5. Report Format
```
## Team: {slug}
Phase: BUILD | Members: {N}
Created: {date} | Updated: {date}

| Member | Area | Status | Last Activity |
|--------|------|--------|---------------|
| dev-1  | auth | Done ✅ | dev-1.md written |
| dev-2  | api  | Working 🔄 | 3 commits |
| dev-3  | ui   | Pending ⏳ | no activity |

## Completed Tasks
- [x] dev-1: Authentication module

## Pending Tasks
- [ ] dev-2: API endpoints
- [ ] dev-3: UI components

## Messages (recent)
- dev-1 → team-lead: "Auth module complete, tests passing"

## Recommendations
- dev-2 appears stalled — consider checking in
- dev-3 hasn't started — verify worktree setup
```

---

Team: $ARGUMENTS
