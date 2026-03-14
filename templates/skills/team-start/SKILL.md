---
name: team-start
description: >
  Spawn an agent team with multiple parallel Claude instances in tmux panes.
  Each teammate is a separate session with its own context window.
  Creates git worktrees and markdown state tracking alongside JSON tasks.
  Supports: --agents (comma-separated), --members N, --devs N.
  Use when told to "team up", "parallel team", "spawn a team", or "standby".
---

# Team Start — Spawn Agent Team with Worktrees + Markdown State

You MUST execute this skill directly. Do NOT delegate to subagents.

## Parse Arguments from: $ARGUMENTS

Extract from the request:
- `--agents agent1,agent2,...` → list of agents to spawn (default: pm,architect,explorer)
- `--members N` → spawn N teammates (alternative to --agents)
- `--devs N` → shorthand for spawning N dev agents
- Remaining text → task description or "standby"

Derive:
- `slug`: slugified task name (lowercase, hyphens, no special chars)
- `dev_count`: number of dev agents in the list

## EXECUTE IMMEDIATELY

### Step 1: Create Project-Repo Task State

**Before creating the team**, set up markdown state tracking in the project repo:

```bash
mkdir -p .claude/tasks/{slug}
```

Create `.claude/tasks/{slug}/_status.md`:
```markdown
# Task: {title}
Created: {date}
Updated: {date}
Phase: PLAN
Status: IN_PROGRESS
Mode: TEAM (Agent Teams)
Devs: {dev_count or TBD}
Base Commit: {git rev-parse HEAD}
Team: {team-name}

## Worktrees
(created at BUILD phase)

## Phase Checklist
- [ ] PLAN — requirements + design
- [ ] BUILD — dev-1 ({area})
... (one per dev)
- [ ] PEER_REVIEW (skip if Devs=1)
- [ ] MERGE — integrate branch
- [ ] QA — e2e testing
- [ ] GATE — security + architecture review
- [ ] REPORT — summary

## Blockers
(none)

## Team Members
| Name | Role | Worktree | Status |
|------|------|----------|--------|
(populated after spawn)
```

### Step 2: Create Git Worktrees for Dev Agents

For each dev agent (dev-1, dev-2, ...):

```bash
mkdir -p .worktrees/{slug}
git worktree add .worktrees/{slug}/dev-{N} -b {slug}/dev-{N}
```

Update `_status.md` Worktrees section with paths and branch names.

**Skip worktree creation if** the team is "standby" or has no dev agents.

### Step 3: Create Team (Agent Teams System)

Use ToolSearch to load TeamCreate:
```
ToolSearch query: "select:TeamCreate"
```

Call TeamCreate with:
- team_name: the slug derived from arguments

### Step 4: Spawn Teammates using Agent Tool

**CRITICAL**: Teammates are spawned using the **Agent tool**, NOT SendMessage.

For each agent in the list, call the Agent tool with these parameters:
- `team_name`: the team name from step 3
- `name`: a unique name for the teammate (e.g., "pm-1", "architect-1", "dev-1")
- `subagent_type`: the agent type (pm, architect, explorer, dev, qa, security-reviewer, or general-purpose)
- `prompt`: Role assignment with **markdown state instructions** (see below)

**IMPORTANT**: Do NOT specify the `model` parameter. Teammates inherit the parent's model automatically.

#### Prompt Template for ALL Teammates:

```
You are {role}-{N} on team '{team-name}'.

## Project State
- Task slug: {slug}
- Project repo: {cwd}
- Task docs: .claude/tasks/{slug}/
- Status file: .claude/tasks/{slug}/_status.md
{if dev: - Your worktree: .worktrees/{slug}/dev-{N}/}
{if dev: - Your branch: {slug}/dev-{N}}

## MANDATORY: Markdown State Tracking
You MUST maintain markdown documentation alongside any JSON task updates:

1. **Read `_status.md`** at the start of every task to understand current state.
2. **Write your role report** to `.claude/tasks/{slug}/{role}-{N}.md` when completing work.
3. **Update `_status.md`** Team Members table with your status when you start and finish.

### Role Report Format ({role}-{N}.md)
# {Role} Report: {role}-{N}
Task: {slug}
Date: {date}
Status: COMPLETED | IN_PROGRESS | BLOCKED

## Summary
[What you did, key decisions, outcomes]

## Files Modified
[List of files with brief description of changes]

## Key Findings / Concerns
[Anything the team-lead should know]

## Test Results (if applicable)
[Test output, coverage numbers]

## Your Specialization
{role-specific instructions}

{if dev:
## CRITICAL: Git Worktree
- ALL code changes → .worktrees/{slug}/dev-{N}/ ONLY
- Task docs ({role}-{N}.md) → main repo .claude/tasks/{slug}/
- Commit: cd .worktrees/{slug}/dev-{N} && git add -A && git commit -m "feat({area}): ..."
- NEVER modify main repo code.
- MANDATORY: TDD (RED → GREEN → REFACTOR)
}

Status: STANDBY — awaiting task assignment.
Acknowledge your role and wait for instructions.
```

### Step 5: Update _status.md with Team Members

After all teammates are spawned, update the Team Members table in `_status.md`:
```markdown
## Team Members
| Name | Role | Worktree | Status |
|------|------|----------|--------|
| pm-1 | pm | n/a | Spawned |
| architect-1 | architect | n/a | Spawned |
| dev-1 | dev | .worktrees/{slug}/dev-1/ | Spawned |
| dev-2 | dev | .worktrees/{slug}/dev-2/ | Spawned |
```

### Step 6: Report Success

```
## Team Created: {team-name}
Task: .claude/tasks/{slug}/_status.md

| Teammate | Name | Role | Worktree | Status |
|----------|------|------|----------|--------|
| 1 | pm-1 | pm | — | Spawned |
| 2 | architect-1 | architect | — | Spawned |
| 3 | dev-1 | dev | .worktrees/{slug}/dev-1/ | Spawned |

**State tracking**:
- JSON tasks: ~/.claude/tasks/{team-name}/ (Agent Teams built-in)
- Markdown state: .claude/tasks/{slug}/ (project repo — persistent memory)
- Worktrees: .worktrees/{slug}/ (code isolation)

**tmux navigation**: Ctrl+B then arrow keys to switch panes

**Next steps**:
- Use SendMessage to communicate with teammates
- Use TaskCreate/TaskUpdate to assign work (teammates auto-update markdown)
- /team-status to check progress
- /team-stop {team-name} to cleanup
```

## Agent Types (for --agents)
| Agent | subagent_type | Capabilities | Worktree |
|-------|---------------|--------------|----------|
| pm | pm | Requirements, scope, risk (read-only) | No |
| architect | architect | System design, component breakdown (read-only) | No |
| explorer | explorer | Codebase search, file discovery (read-only) | No |
| dev | dev | Full implementation (read/write) | Yes |
| qa | qa | E2E testing (read/write) | integrate/ |
| security-reviewer | security-reviewer | Security audit (read-only) | No |

**Note**: Use `general-purpose` for any agent that needs write access beyond dev scope.

## Examples

```
/team-start --agents pm,architect,explorer standby
/team-start --agents dev,dev,dev my-feature
/team-start --devs 3 add-rate-limiting
/team-start --members 3 standby
```

---

Request: $ARGUMENTS
