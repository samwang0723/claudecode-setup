# Claude Code Kit — Skills, Agents & Teams

## Architecture: Skills + Agents

### Skills (`~/.claude/skills/`)
Skills are task workflows invoked via `/skill-name` or auto-triggered.
Each has a `SKILL.md` with frontmatter. Skills use `context: fork` + `agent: team-lead`
to delegate work to the team-lead agent in an isolated context.

| Skill | Trigger |
|-------|---------|
| `/lead-start` | Start or resume a task |
| `/lead-summary` | Progress + blockers |
| `/lead-cleanup` | Remove worktrees after merge |
| `/review-pr` | PR review pipeline |
| `/arch-review` | Architecture audit |
| `/investigate` | Incident investigation |
| `/strategy` | Strategic decisions |
| `/scope` | Project scoping |
| `/quick-scan` | Health check |
| `/team-start` | Spawn agent team (parallel instances) |
| `/team-status` | Monitor team member progress |
| `/team-stop` | Clean up team resources |

### Agents (`~/.claude/agents/`)
Specialist subagents delegated to by team-lead. Each has tools and a reporting chain.

| Agent | Role |
|-------|------|
| `team-lead` | Orchestrator — all skills fork into this agent |
| `architect` | Design + final gate |
| `dev` | TDD implementation + peer review (×1-5, in worktrees) |
| `qa` | e2e testing (on integrate worktree) |
| `security-reviewer` | Security audit (final gate) |
| `pm` | Requirements, scope, risk |
| `explorer` | Fast codebase scout |

### Two Orchestration Modes

| Mode | Skills | How it works |
|------|--------|-------------|
| **Subagent** | `/lead-start` | Single session, Task tool, sequential |
| **Agent Team** | `/team-start` | Separate instances, true parallel |

Use **subagents** for tightly coordinated work. Use **agent teams** for embarrassingly parallel tasks (different files/modules).

## Task State System

All work tracked in `.claude/tasks/` with per-role markdown files and `_status.md` as source of truth.
See individual agent `.md` files for formats.

### _status.md Format
```markdown
# Task: {title}
Created: {date}
Updated: {date}
Phase: {PLAN|BUILD|PEER_REVIEW|MERGE|QA|GATE|DONE|BLOCKED}
Status: {IN_PROGRESS|COMPLETED|BLOCKED}
Devs: {1-5 or TBD}
Base Commit: {sha}

## Worktrees
(created at BUILD phase)

## Phase Checklist
- [ ] PLAN — pm requirements
- [ ] PLAN — architect design
- [ ] BUILD — dev-1 ({area})
... (only as many as Devs count)
- [ ] PEER_REVIEW (skip if Devs=1)
- [ ] MERGE — integrate branch
- [ ] QA — e2e testing
- [ ] GATE — security review
- [ ] GATE — architect review
- [ ] REPORT — summary

## Blockers
(none)
```

### Rules
- Every agent reads `_status.md` before work, updates it after.
- Every agent reads their memory log (`~/.claude/agents/memory/{agent}.md`) at task start, writes a reflection at task end.
- Code in worktrees, task docs in main repo `.claude/tasks/`.
- Master decides when to merge — never auto-merge.

## Agent Memory System

Persistent learning logs at `~/.claude/agents/memory/{agent}.md`. Each agent maintains a compressed diary of lessons learned across all tasks.

### Lifecycle
1. **Read** memory log at task start — filter by `Project:` tag, prioritize same-repo lessons
2. **Append** dated reflection at task end via Bash (`cat >>`) — never overwrite (safe for parallel agents)
3. **Diary merge** when file exceeds **150 lines** (`wc -l`) — intelligent compression, not simple truncation

### Entry Format
Each entry includes `Project: {repo-name}` for cross-repo filtering and `Critical: yes/no` to protect important lessons from compression. Agents prioritize lessons from the current repo but can learn from cross-project patterns too.

### Diary Merge (Compression)
When triggered (>150 lines), agents perform an intelligent merge rather than deleting old entries:
1. Read entire file — existing `## Wisdom` section + all individual entries
2. Identify themes across old and new entries, group lessons by topic
3. Re-synthesize `## Wisdom` by merging old wisdom with new patterns. Strengthen repeated lessons, preserve `Critical: yes` lessons verbatim, drop routine lessons that never recurred
4. Keep 10 most recent entries intact below Wisdom
5. Delete individual entries that were absorbed into Wisdom

The Wisdom section is a **living document** — each compression re-synthesizes it, so no important lesson is lost.

### Memory Files
| File | Agent | Notes |
|------|-------|-------|
| `memory/team-lead.md` | Delegation patterns, pipeline bottlenecks | |
| `memory/architect.md` | Design trade-offs, gate review insights | |
| `memory/dev.md` | TDD patterns, implementation pitfalls | **Shared** across parallel dev-1..5 instances |
| `memory/code-reviewer.md` | Severity calibration, false positive patterns | |
| `memory/qa.md` | Test strategies, integration failure patterns | |
| `memory/security-reviewer.md` | Vulnerability patterns, compliance gaps | |
| `memory/pm.md` | Scope estimation accuracy, risk predictions | |
| `memory/explorer.md` | Search strategies, codebase landmarks | Reads memory only if <100 lines (speed priority) |

## Git Worktree Isolation

```
.worktrees/{task-slug}/
├── dev-1/     ← branch: {slug}/dev-1
├── dev-2/     ← branch: {slug}/dev-2
└── integrate/ ← branch: {slug}/integrate (QA + gate)
```

- team-lead creates worktrees at BUILD start, records base commit.
- Each dev works ONLY in their worktree. Never touch main repo code.
- After peer review, team-lead merges dev branches → integrate.
- QA and gate review in integrate worktree.
- `/lead-cleanup {slug}` removes worktrees after Master merges.

## Agent Teams (Experimental)

Agent Teams spawn **separate Claude Code instances** (teammates) that work in parallel,
each with their own context window. This is different from subagents (which run within
a single session). Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

### Teams vs Subagents

| Feature | Subagents (Task tool) | Agent Teams |
|---------|----------------------|-------------|
| Execution | Within single session | Separate Claude instances |
| Context | Own window, results return to caller | Fully independent context |
| Communication | Report results back to main only | Teammates message each other directly |
| Task tracking | Manual via `_status.md` | **Dual: JSON tasks + markdown `_status.md`** |
| Worktrees | Yes (`.worktrees/{slug}/`) | **Yes (aligned with subagent workflow)** |
| Parallelism | Via Task tool parallel calls | True parallel execution |
| Cost | Lower (results summarized back) | Higher (N × full context) |
| Best for | Focused tasks where only result matters | Complex work requiring collaboration |

### Team Lifecycle

```
/team-start --devs N <task>
  ↓
Create .claude/tasks/{slug}/_status.md (markdown state)
  ↓
Create .worktrees/{slug}/dev-{1..N}/ (git worktrees)
  ↓
TeamCreate → spawns N teammates
  ↓
TaskCreate → assigns work items (JSON + markdown dual tracking)
  ↓
Members work in worktrees, write role reports to .claude/tasks/{slug}/
  ↓
SendMessage → coordinate, share findings
  ↓
/team-status → monitor progress (reads both JSON tasks + _status.md)
  ↓
/team-stop <team-name> → cleanup worktrees + team resources
```

### Dual State Tracking

Agent Teams maintain **both** systems in sync:

| System | Location | Purpose |
|--------|----------|---------|
| JSON tasks | `~/.claude/tasks/{team-name}/` | Real-time teammate coordination |
| Markdown | `.claude/tasks/{slug}/_status.md` | Persistent memory, audit trail, resume |
| Role reports | `.claude/tasks/{slug}/{role}-{N}.md` | Detailed work output per member |
| Worktrees | `.worktrees/{slug}/dev-{N}/` | Code isolation per dev |

All teammates MUST write markdown reports alongside JSON task updates.

### Team Skills

| Skill | Purpose |
|-------|---------|
| `/team-start` | Create team, assign parallel work |
| `/team-status` | Check member progress + messages |
| `/team-stop` | Clean up team resources |

### Best Practices

- 3-5 teammates max (token costs scale linearly)
- 5-6 tasks per teammate keeps everyone productive
- Break work so each teammate owns **different files** to avoid conflicts
- Start with research/review tasks, not parallel implementation
- Use `teammateMode: "tmux"` for split panes (requires tmux or iTerm2)
- Teammates inherit lead's model; specify in prompt to override
- Monitor and steer constantly — teammates work autonomously
- Wait for teammates to finish before lead does dependent work
- Use `/resume` carefully — in-process teammates don't survive session resumption

### Display Modes

- **tmux** (default): Each teammate gets own tmux pane. Requires tmux or iTerm2.
- **in-process**: All teammates in main terminal. Shift+Down to cycle.

Configure via `teammateMode` in `settings.json` or `claude --teammate-mode tmux`.

### Model Consistency

- **Agent Teams (teammates)**: Inherit the lead's model automatically. Can override per-teammate in prompts.
- **Subagents (Task tool)**: Controlled by `CLAUDE_CODE_SUBAGENT_MODEL` env var.

Both are set to use Opus 4.5 for consistent behavior across all agents.
