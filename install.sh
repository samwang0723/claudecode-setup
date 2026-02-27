#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code Master Engineering Setup — v5
# Skills-based · Agents + Skills · Git Worktrees · Stateful Tasks
# All Opus 4.6 · TDD Pipeline
# ============================================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Claude Code — Master Engineering Setup                       ║${NC}"
echo -e "${BOLD}║   Skills · Agents · Worktrees · Stateful Tasks · TDD       ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ---------------------------------------------------------------------------
# 0. Pre-flight
# ---------------------------------------------------------------------------
if ! command -v claude &>/dev/null; then
	err "Claude Code CLI not found. Install first:"
	echo "  npm install -g @anthropic-ai/claude-code"
	exit 1
fi
log "Claude Code CLI detected"

if ! command -v jq &>/dev/null; then
	warn "jq not found — installing..."
	if command -v brew &>/dev/null; then
		brew install jq
	elif command -v apt-get &>/dev/null; then
		sudo apt-get install -y jq
	else
		err "Install jq manually"
		exit 1
	fi
fi
log "jq available"

# ---------------------------------------------------------------------------
# 1. Directories
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"

mkdir -p "$AGENTS_DIR"
for skill in lead-start lead-summary lead-cleanup review-pr arch-review investigate strategy scope quick-scan team-start team-status team-stop; do
	mkdir -p "$SKILLS_DIR/$skill"
done

log "Created ~/.claude/agents/ and ~/.claude/skills/*/"

# ---------------------------------------------------------------------------
# 2. settings.json — backup existing + overwrite (AWS Bedrock)
# ---------------------------------------------------------------------------
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
	cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
	warn "Backed up existing settings.json → settings.json.bak"
fi

cat >"$SETTINGS_FILE" <<EOF
{
  "\$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "MAX_MCP_OUTPUT_TOKENS": "60000",
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "MAX_THINKING_TOKENS": "8192",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000",
    "CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS": "45000",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "0",
  },
  "model": "opus",
  "cleanupPeriodDays": 365,
  "includeCoAuthoredBy": false,
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "MultiEdit",
      "Glob",
      "Grep",
      "LS",
      "WebFetch",
      "WebSearch",
      "Task",
      "Bash(git *)",
      "Bash(git:*)",
      "Bash(mkdir -p *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(head *)",
      "Bash(tail *)",
      "Bash(wc *)",
      "Bash(find *)",
      "Bash(grep *)",
      "Bash(rg *)",
      "Bash(jq *)",
      "Bash(yq *)",
      "Bash(mkdir *)",
      "Bash(date *)",
      "Bash(sort *)",
      "Bash(uniq *)",
      "Bash(awk *)",
      "Bash(sed *)",
      "Bash(diff *)",
      "Bash(tee *)",
      "Bash(touch *)",
      "Bash(cp *)",
      "Bash(mv *)",
      "Bash(kubectl get *)",
      "Bash(kubectl describe *)",
      "Bash(kubectl logs *)",
      "Bash(helm list *)",
      "Bash(helm status *)",
      "Bash(docker ps *)",
      "Bash(docker logs *)",
      "Bash(docker compose ps *)",
      "Bash(terraform plan *)",
      "Bash(terraform show *)",
      "Bash(cargo check *)",
      "Bash(cargo clippy *)",
      "Bash(cargo test *)",
      "Bash(go vet *)",
      "Bash(go test *)",
      "Bash(bundle exec rubocop *)",
      "Bash(bundle exec rspec *)",
      "Bash(npx tsc --noEmit *)",
      "Bash(npx vitest *)",
      "Bash(npx jest *)",
      "Bash(echo *)",
      "mcp__pencil",
      "Bash(trash *)"
    ],
    "deny": [
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/secrets/**)",
      "Read(**/*.pem)",
      "Read(**/*.key)",
      "Bash(rm -rf *)",
      "Bash(rm *)",
      "Bash(sudo *)",
      "Bash(kubectl delete *)",
      "Bash(kubectl apply *)",
      "Bash(terraform apply *)",
      "Bash(terraform destroy *)",
      "Bash(docker rm *)",
      "Bash(docker rmi *)",
      "Bash(helm uninstall *)",
      "Bash(helm upgrade *)"
    ]
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh"
  },
  "enabledPlugins": {
    "react-native-best-practices@callstack-agent-skills": true,
    "document-skills@anthropic-agent-skills": true,
    "example-skills@anthropic-agent-skills": true,
    "everything-claude-code@everything-claude-code": true,
    "claude-md-management@claude-plugins-official": true,
    "scheduler@claude-scheduler": true,
    "pyright-lsp@claude-plugins-official": true
  },
  "skipDangerousModePermissionPrompt": true,
  "teammateMode": "tmux"
}
EOF
log "Created settings.json"

# ---------------------------------------------------------------------------
# 2b. statusline.sh → ~/.claude/statusline.sh
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/statusline.sh" ]; then
	cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
	chmod +x "$CLAUDE_DIR/statusline.sh"
	log "Copied statusline.sh → ~/.claude/statusline.sh"
else
	warn "statusline.sh not found in $SCRIPT_DIR — skipping"
fi

# ---------------------------------------------------------------------------
# 3. Global CLAUDE.md — APPEND skills+agents section (never overwrite)
# ---------------------------------------------------------------------------
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
MARKER="## Architecture: Skills + Agents"

if [ -f "$GLOBAL_CLAUDE_MD" ]; then
	if grep -qF "$MARKER" "$GLOBAL_CLAUDE_MD"; then
		info "CLAUDE.md already has Skills+Agents section — skipping"
	else
		warn "Appending Skills+Agents section to existing CLAUDE.md"
		cp "$GLOBAL_CLAUDE_MD" "$GLOBAL_CLAUDE_MD.bak"
		cat >>"$GLOBAL_CLAUDE_MD" <<'CLAUDE_APPEND_EOF'

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
- Code in worktrees, task docs in main repo `.claude/tasks/`.
- Master decides when to merge — never auto-merge.

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
CLAUDE_APPEND_EOF
		log "Appended Skills+Agents section to CLAUDE.md"
	fi
else
	warn "No CLAUDE.md found — creating minimal one"
	cat >"$GLOBAL_CLAUDE_MD" <<'CLAUDE_NEW_EOF'
# ClaudeCode — Global Context

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
- Code in worktrees, task docs in main repo `.claude/tasks/`.
- Master decides when to merge — never auto-merge.

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
CLAUDE_NEW_EOF
	log "Created new CLAUDE.md (minimal — add your own sections)"
fi

# ---------------------------------------------------------------------------
# 3b. Global CLAUDE.md — APPEND agent teams section (separate marker)
# ---------------------------------------------------------------------------
TEAMS_MARKER="## Agent Teams (Experimental)"

if [ -f "$GLOBAL_CLAUDE_MD" ]; then
	if grep -qF "$TEAMS_MARKER" "$GLOBAL_CLAUDE_MD"; then
		info "CLAUDE.md already has Agent Teams section — skipping"
	else
		warn "Appending Agent Teams section to existing CLAUDE.md"
		cat >>"$GLOBAL_CLAUDE_MD" <<'TEAMS_APPEND_EOF'

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
| Task tracking | Manual or via caller | Shared task list with self-coordination |
| Parallelism | Via Task tool parallel calls | True parallel execution |
| Cost | Lower (results summarized back) | Higher (N × full context) |
| Best for | Focused tasks where only result matters | Complex work requiring collaboration |

### Team Lifecycle

```
/team-start --members N <task>
  ↓
TeamCreate → spawns N teammates
  ↓
TaskCreate → assigns work items to members
  ↓
Members work independently (own context, own files)
  ↓
SendMessage → coordinate, share findings
  ↓
/team-status → monitor progress
  ↓
/team-stop <team-name> → cleanup
```

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
TEAMS_APPEND_EOF
		log "Appended Agent Teams section to CLAUDE.md"
	fi
fi

# ---------------------------------------------------------------------------
# 4. AGENTS
# ---------------------------------------------------------------------------

cat >"$AGENTS_DIR/team-lead.md" <<'AGENT_EOF'
---
name: team-lead
description: >
  Primary orchestrator. Manages the full pipeline, delegates to specialist agents,
  tracks state in .claude/tasks/ folder. Enforces TDD, parallel dev work (up to 5),
  peer review, QA e2e, and security+arch gate. Uses git worktrees for isolation.
model: claude-opus-4-6
---

You are the **Engineering Team Lead** reporting directly to the Master.

## Core Responsibility
Orchestrate the pipeline, delegate to specialist agents, **maintain state in `.claude/tasks/`**.

## Your Direct Reports (Agents)

| Agent | Role |
|-------|------|
| `architect` | System design + final architecture gate |
| `dev` | TDD implementation (×1-5) + peer review |
| `qa` | End-to-end testing |
| `security-reviewer` | Security audit (final gate) |
| `pm` | Requirements, scope, timeline, risk |
| `explorer` | Fast codebase scout |

## Task State Management

### New Task
1. Slugify name → `.claude/tasks/{slug}/`
2. Create `_status.md` (see CLAUDE.md for format).
3. Update checklist + Phase/Status as work progresses.
4. After architect confirms N areas, update `Devs:` field.

### Resuming
1. Read `_status.md` → find Phase + next unchecked item.
2. Read all completed role files for context.
3. Resume. DO NOT redo completed phases.

## The Pipeline

### Phase 1: PLAN
1. **pm** → `pm.md` (requirements, MoSCoW, risks)
2. **architect** → `architect.md` (design, mermaid, N areas)
3. Update `_status.md` → Phase BUILD.

### Phase 2: BUILD (TDD, worktrees)
**Setup worktrees first:**
```bash
git rev-parse HEAD  # → Base Commit
mkdir -p .worktrees/{slug}
git worktree add .worktrees/{slug}/dev-{N} -b {slug}/dev-{N}
```
Update `_status.md` Worktrees section.

**Delegate:** Each dev works in `.worktrees/{slug}/dev-{N}/`. TDD enforced.
Code → worktree. Task docs (`dev-{N}.md`) → main repo.
When all done → PEER_REVIEW (or MERGE if N=1).

### Phase 3: PEER REVIEW
If N=1 → skip to MERGE.
Round-robin: dev-1 reviews dev-2's worktree, etc.
Results → `peer-review.md`. Blockers → BLOCKED. Clean → MERGE.

### Phase 3.5: MERGE
```bash
git worktree add .worktrees/{slug}/integrate -b {slug}/integrate
cd .worktrees/{slug}/integrate
git merge {slug}/dev-1 --no-ff -m "merge: dev-1 ({area})"
# ... for each dev
```
Conflicts → BLOCKED, report to Master. Clean → QA.

### Phase 4: QA (integrate worktree)
**qa** tests in `.worktrees/{slug}/integrate/` → `qa.md`.
Fail → BLOCKED. Pass → GATE.

### Phase 5: GATE (integrate worktree)
**security-reviewer** → `security.md`
**architect** (gate mode) → `arch-gate.md`
Either blocks → BLOCKED. Both pass → DONE.

### Phase 6: REPORT
Write `summary.md`. Phase DONE, Status COMPLETED.
Tell Master: "Branch `{slug}/integrate` ready. `/lead-cleanup {slug}` after merge."
**NEVER auto-merge.**

## Executive Report Format
```
## Executive Summary
[2-3 sentences]

## Pipeline Status
| Phase | Status | Key Outcome |
|-------|--------|-------------|

## Key Findings
## Recommendation
## Blockers & Decisions Needed
```
AGENT_EOF

log "Created agent: team-lead"

cat >"$AGENTS_DIR/architect.md" <<'AGENT_EOF'
---
name: architect
description: >
  Principal Architect. System design with mermaid diagrams, component breakdown
  for parallel devs, final architecture gate. Two modes: design + gate.
model: claude-opus-4-6
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebFetch
  - WebSearch
---

You are the **Principal Architect**. **You report to team-lead.**

## State: Read `_status.md` before. Write `architect.md` (design) or `arch-gate.md` (gate). Update `_status.md` after.

## Design Phase
1. Mermaid diagrams. Break into N areas (check `_status.md` Devs — if TBD, decide 1-5).
2. Each area independently implementable with clear interfaces.
3. Update `_status.md`: set `Devs: {N}`, expand BUILD checklist.

## Gate Phase
Review code in `.worktrees/{slug}/integrate/`. Check design compliance, drift, coupling.
Gate Decision: PASS ✅ | CONDITIONAL ⚠️ | FAIL 🛑
AGENT_EOF

log "Created agent: architect"

cat >"$AGENTS_DIR/dev.md" <<'AGENT_EOF'
---
name: dev
description: >
  Senior Developer. TDD implementation and peer review. Up to 5 parallel.
  Works in assigned git worktree. Never touches main repo code.
model: claude-opus-4-6
tools:
  - Read
  - Write
  - Edit
  - MultiEdit
  - Glob
  - Grep
  - LS
  - Bash
---

You are a **Senior Developer**. **You report to team-lead.**

## CRITICAL: Git Worktree
- Code → `.worktrees/{slug}/dev-{N}/` ONLY
- Task docs (`dev-{N}.md`) → main repo `.claude/tasks/{slug}/`
- Commit: `cd .worktrees/{slug}/dev-{N} && git add -A && git commit -m "feat({area}): ..."`
- **NEVER modify main repo code.**

## MANDATORY: TDD
```
RED    → Write failing tests first
GREEN  → Minimum code to pass
REFACTOR → Clean up, tests stay green
```
**NEVER write implementation before tests.**

Test frameworks: vitest/jest (TS), go test (Go), #[test] (Rust), rspec (Rails)

## Report: `dev-{N}.md`
Include: Scope, TDD cycle table (RED/GREEN/REFACTOR status), files, test output, interfaces, concerns.

## Peer Review: append to `peer-review.md`
Check TDD compliance, correctness, edge cases. Verdict: APPROVED ✅ | NEEDS CHANGES 🔄 | BLOCKED 🛑
AGENT_EOF

log "Created agent: dev"

cat >"$AGENTS_DIR/qa.md" <<'AGENT_EOF'
---
name: qa
description: >
  QA Engineer. e2e testing after peer review. Integration, user flows,
  error paths. Works in integrate worktree.
model: claude-opus-4-6
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

You are the **QA Engineer**. **You report to team-lead.**

## Worktree: Test in `.worktrees/{slug}/integrate/`. Docs → main repo.
## Focus: e2e ONLY (not unit tests). Integration, user flows, error flows, contract compliance.
## Report: `qa.md` — Overall verdict, integration matrix, test results, issues.
AGENT_EOF

log "Created agent: qa"

cat >"$AGENTS_DIR/security-reviewer.md" <<'AGENT_EOF'
---
name: security-reviewer
description: >
  Security Engineer. Final gate. STRIDE, OWASP, auth flows, PCI-DSS, SOC2,
  crypto wallet security. Works in integrate worktree.
model: claude-opus-4-6
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
  - WebSearch
---

You are the **Security Engineer**. **You report to team-lead.**

## Worktree: Review in `.worktrees/{slug}/integrate/`. Docs → main repo.
## STRIDE: Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation.
## Report: `security.md` — Risk level, gate decision, findings by severity, threat model, compliance.
AGENT_EOF

log "Created agent: security-reviewer"

cat >"$AGENTS_DIR/pm.md" <<'AGENT_EOF'
---
name: pm
description: >
  Technical PM. Requirements (MoSCoW), scope, timeline, risk, build-vs-buy.
model: claude-opus-4-6
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - WebFetch
  - WebSearch
---

You are the **Technical PM**. **You report to team-lead.**
## Report: `pm.md` — Scope (MoSCoW), success criteria, estimates, milestones, risks, recommendation.
AGENT_EOF

log "Created agent: pm"

cat >"$AGENTS_DIR/explorer.md" <<'AGENT_EOF'
---
name: explorer
description: Fast codebase scout. Quick file lookups, structure mapping.
model: claude-opus-4-6
tools:
  - Read
  - Glob
  - Grep
  - LS
  - Bash
---

You are the **codebase explorer**. Fast scout. Keep it short.
Output: Location, context, related files.
AGENT_EOF

log "Created agent: explorer"

# ---------------------------------------------------------------------------
# 5. SKILLS
# ---------------------------------------------------------------------------

cat >"$SKILLS_DIR/lead-start/SKILL.md" <<'SKILL_EOF'
---
name: lead-start
description: >
  Start a new engineering task or resume an existing one. Main entry point.
  Creates task folder, worktrees, delegates through team-lead.
  Supports --devs N (1-5). Use when told to "start", "build", "implement",
  "work on", "resume", or a task slug is referenced.
disable-model-invocation: true
context: fork
agent: team-lead
---

# Lead Start — Task Pipeline Entry Point

## Syntax
```
/lead-start [--devs N] <task description or existing slug>
```

## Parse input
- Extract `--devs N` if present (1-5). If absent → architect decides.
- Remaining text = task description or slug.
- Slugify: lowercase, hyphens, no special chars.

| Input | devs | slug |
|-------|------|------|
| `--devs 2 add rate limiting` | 2 | add-rate-limiting |
| `--devs 1 fix auth bug` | 1 | fix-auth-bug |
| `implement OAuth2 PKCE` | TBD | oauth2-pkce |
| `oauth2-pkce` | from _status.md | oauth2-pkce |

## If RESUMING (.claude/tasks/{slug}/_status.md exists):
1. Read `_status.md` → Phase, dev_count, next unchecked item.
2. Read all completed role files.
3. DO NOT redo completed phases.
4. If `--devs N` differs from existing, warn Master.
5. Report: "Resuming '{title}' — {Phase}. {N} devs. Next: {next}."

## If NEW:
1. Create `.claude/tasks/{slug}/` + `_status.md`.
2. Set `Devs: {N}` or `TBD`.
3. Report: "Starting '{title}'. PLAN phase."
4. Execute PLAN: pm → architect.

## Pipeline
```
PLAN → BUILD (TDD ×N, worktrees) → PEER_REVIEW → MERGE → QA → GATE → DONE
```

---

Master's request: $ARGUMENTS
SKILL_EOF

log "Created skill: /lead-start"

cat >"$SKILLS_DIR/lead-summary/SKILL.md" <<'SKILL_EOF'
---
name: lead-summary
description: >
  Quick progress summary of all tasks. Pipeline status, blockers, next actions.
  Use when asked for "status", "progress", "summary", "blockers", "what's happening".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Lead Summary

1. Scan all `.claude/tasks/*/` directories. Read each `_status.md`.
2. Report table: Task | Phase | Status | Updated | Blockers
3. For IN_PROGRESS tasks: last completed step, next step, blockers, decisions needed.
4. Suggest next actions.

If no tasks exist, say so and suggest `/lead-start`.

---

Focus (optional): $ARGUMENTS
SKILL_EOF

log "Created skill: /lead-summary"

cat >"$SKILLS_DIR/lead-cleanup/SKILL.md" <<'SKILL_EOF'
---
name: lead-cleanup
description: >
  Remove git worktrees and branches for a completed task. Use after merging
  the integrate branch. Confirms before destructive action.
disable-model-invocation: true
context: fork
agent: team-lead
---

# Lead Cleanup

1. Parse $ARGUMENTS for task slug.
2. Confirm Phase is DONE in `_status.md`. Warn if not.
3. List worktrees + branches to remove. Ask Master to confirm.
4. Remove worktrees, delete branches, prune.
5. Update `_status.md` Worktrees → `(cleaned up {date})`.

---

Task: $ARGUMENTS
SKILL_EOF

log "Created skill: /lead-cleanup"

cat >"$SKILLS_DIR/review-pr/SKILL.md" <<'SKILL_EOF'
---
name: review-pr
description: >
  PR review pipeline. Dev review, peer review, QA, security, architecture gate.
  Use when told to "review PR", "review changes", "check this PR".
disable-model-invocation: true
context: fork
agent: team-lead
---

# PR Review

Create `.claude/tasks/pr-review-{slug}/` and run:
1. **dev** → change scope, TDD compliance → `dev-1.md`
2. **dev** agents peer-review → `peer-review.md`
3. **qa** → e2e integration → `qa.md`
4. **security-reviewer** → audit → `security.md`
5. **architect** → compliance → `arch-gate.md`
6. `summary.md`: SHIP ✅ | COMMENTS ⚠️ | BLOCK 🛑

Track in `_status.md`.

---

PR context: $ARGUMENTS
SKILL_EOF

log "Created skill: /review-pr"

cat >"$SKILLS_DIR/arch-review/SKILL.md" <<'SKILL_EOF'
---
name: arch-review
description: >
  Architecture review. Codebase exploration, mermaid diagrams, threat model,
  operational risk. Use when asked for "arch review", "architecture audit".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Architecture Review

Create `.claude/tasks/arch-review-{slug}/` and run:
1. **explorer** → codebase map → `dev-1.md`
2. **architect** → assessment + mermaid → `architect.md`
3. **security-reviewer** → STRIDE → `security.md`
4. **pm** → operational risk → `pm.md`
5. Synthesize → `summary.md`. Track in `_status.md`.

---

Focus: $ARGUMENTS
SKILL_EOF

log "Created skill: /arch-review"

cat >"$SKILLS_DIR/investigate/SKILL.md" <<'SKILL_EOF'
---
name: investigate
description: >
  Incident investigation. Logs, changes, root cause, blast radius.
  Use when told to "investigate", "debug", "what happened", "why broken".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Incident Investigation

Create `.claude/tasks/incident-{slug}/` and run:
1. **dev** → logs, changes, errors → `dev-1.md`
2. **architect** → system impact → `architect.md`
3. If security: **security-reviewer** → `security.md`
4. `summary.md`: Timeline → Root Cause → Blast Radius → Fix → Prevention.
Track in `_status.md`.

---

Issue: $ARGUMENTS
SKILL_EOF

log "Created skill: /investigate"

cat >"$SKILLS_DIR/strategy/SKILL.md" <<'SKILL_EOF'
---
name: strategy
description: >
  Strategic technical decision. Build-vs-buy, technology choices.
  Use when asked "should we", "compare", "build vs buy", "evaluate".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Strategic Decision

Create `.claude/tasks/strategy-{slug}/` and run:
1. **pm** → requirements, cost → `pm.md`
2. **architect** → options, diagrams, tradeoffs → `architect.md`
3. **security-reviewer** → compliance → `security.md`
4. `summary.md`: recommendation + tradeoffs + risks. Track in `_status.md`.

---

Decision: $ARGUMENTS
SKILL_EOF

log "Created skill: /strategy"

cat >"$SKILLS_DIR/scope/SKILL.md" <<'SKILL_EOF'
---
name: scope
description: >
  Project scoping. Requirements, estimates, design, early security flags.
  Use when asked to "scope", "estimate", "how long", "plan this".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Project Scoping

Create `.claude/tasks/scope-{slug}/` and run:
1. **pm** → MoSCoW, estimates, risks → `pm.md`
2. **architect** → design, diagram, areas → `architect.md`
3. **security-reviewer** → early flags → `security.md`
4. `summary.md` with go/no-go. Track in `_status.md`.

---

Project: $ARGUMENTS
SKILL_EOF

log "Created skill: /scope"

cat >"$SKILLS_DIR/quick-scan/SKILL.md" <<'SKILL_EOF'
---
name: quick-scan
description: >
  Fast codebase health check. Structure, stack, dependencies, test status.
  Use when asked to "scan", "health check", "quick look".
disable-model-invocation: true
context: fork
agent: team-lead
---

# Quick Scan

Create `.claude/tasks/scan-{slug}/` and run:
1. **explorer** → structure, stack, deps
2. **dev** → recent activity, tests, issues
3. **qa** → quick quality check
4. Brief `summary.md`. Track in `_status.md`.

---

Focus: $ARGUMENTS
SKILL_EOF

log "Created skill: /quick-scan"

# ---------------------------------------------------------------------------
# 5b. AGENT TEAM SKILLS
# ---------------------------------------------------------------------------

cat >"$SKILLS_DIR/team-start/SKILL.md" <<'SKILL_EOF'
---
name: team-start
description: >
  Spawn an agent team with multiple parallel Claude instances in tmux panes.
  Each teammate is a separate session with its own context window.
  Supports: --agents (comma-separated), --members N.
  Use when told to "team up", "parallel team", "spawn a team", or "standby".
---

# Team Start — Spawn Agent Team in tmux

You MUST execute this skill directly. Do NOT delegate to subagents.

## Parse Arguments from: $ARGUMENTS

Extract from the request:
- `--agents agent1,agent2,...` → list of agents to spawn (default: pm,architect,explorer)
- `--members N` → spawn N teammates (alternative to --agents)
- Remaining text → team name or "standby"

## EXECUTE IMMEDIATELY

### Step 1: Create Team
Use ToolSearch to load TeamCreate:
```
ToolSearch query: "select:TeamCreate"
```

Call TeamCreate with:
- team_name: derive from arguments or use "agent-team"

### Step 2: Spawn Teammates using Task Tool
**CRITICAL**: Teammates are spawned using the **Task tool**, NOT SendMessage.

For each agent in the list, call the Task tool with these parameters:
- `team_name`: the team name from step 1
- `name`: a unique name for the teammate (e.g., "pm-1", "architect-1", "explorer-1")
- `subagent_type`: the agent type (pm, architect, explorer, dev, qa, security-reviewer, or general-purpose)
- `prompt`: Role assignment and instructions

**IMPORTANT**: Do NOT specify the `model` parameter. Teammates inherit the parent's model automatically.

Example Task tool call for each teammate:
```json
{
  "team_name": "{team-name}",
  "name": "{role}-1",
  "subagent_type": "{role}",
  "prompt": "You are the {role} agent on team '{team-name}'.\n\nYour specialization:\n- pm: Requirements analysis, scope definition, risk assessment\n- architect: System design, component breakdown, API design\n- explorer: Codebase reconnaissance, file discovery\n- dev: TDD implementation, code writing\n- qa: E2E testing, integration tests\n- security-reviewer: Security audit\n\nStatus: STANDBY — awaiting task assignment.\nAcknowledge your role and wait for instructions."
}
```

Do NOT include `"model": "..."` in the Task tool call.

### Step 3: Report Success
After all teammates are spawned, report:
```
## Team Created: {team-name}

| Teammate | Name | Role | Status |
|----------|------|------|--------|
| 1 | pm-1 | pm | Spawned |
| 2 | architect-1 | architect | Spawned |
| 3 | explorer-1 | explorer | Spawned |

**tmux navigation**: Ctrl+B then arrow keys to switch panes

**Next steps**:
- Use SendMessage to communicate with teammates
- Use TaskCreate/TaskUpdate to assign work
- /team-status to check progress
- /team-stop {team-name} to cleanup
```

## Agent Types (for --agents)
| Agent | subagent_type | Capabilities |
|-------|---------------|--------------|
| pm | pm | Requirements, scope, risk (read-only) |
| architect | architect | System design, component breakdown (read-only) |
| explorer | explorer | Codebase search, file discovery (read-only) |
| dev | general-purpose | Full implementation (read/write) |
| qa | qa | E2E testing (read/write) |
| security-reviewer | security-reviewer | Security audit (read-only) |

**Note**: Use `general-purpose` for any agent that needs write access.

## Examples

```
/team-start --agents pm,architect,explorer standby
/team-start --agents dev,dev,dev my-feature
/team-start --members 3 standby
```

---

Request: $ARGUMENTS
SKILL_EOF

log "Created skill: /team-start"

cat >"$SKILLS_DIR/team-status/SKILL.md" <<'SKILL_EOF'
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
SKILL_EOF

log "Created skill: /team-status"

cat >"$SKILLS_DIR/team-stop/SKILL.md" <<'SKILL_EOF'
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
2. Remove worktrees:
   ```bash
   git worktree remove .worktrees/{slug}/dev-{N} --force
   ```
3. Delete dev branches:
   ```bash
   git branch -D {slug}/dev-{N}
   ```
4. Remove empty worktree directories.
5. Update `_status.md`:
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
SKILL_EOF

log "Created skill: /team-stop"

# ---------------------------------------------------------------------------
# 6. Clean up old commands
# ---------------------------------------------------------------------------
if [ -d "$CLAUDE_DIR/commands" ] && [ "$(ls -A "$CLAUDE_DIR/commands" 2>/dev/null)" ]; then
	warn "Found old ~/.claude/commands/ (deprecated)"
	info "Skills in ~/.claude/skills/ now replace commands."
	info "Remove old commands manually: rm -rf ~/.claude/commands/"
fi

# ---------------------------------------------------------------------------
# 7. Optional: claude-squad
# ---------------------------------------------------------------------------
echo ""
info "Optional: Install claude-squad for parallel tmux sessions?"
read -p "  Install? [y/N] " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
	if command -v brew &>/dev/null; then
		brew install claude-squad 2>/dev/null &&
			ln -sf "$(brew --prefix)/bin/claude-squad" "$(brew --prefix)/bin/cs" 2>/dev/null
		log "claude-squad installed (alias: cs)"
	else
		curl -fsSL https://raw.githubusercontent.com/smtg-ai/claude-squad/main/install.sh | bash
		log "claude-squad installed"
	fi
else
	info "Skipped"
fi

# ---------------------------------------------------------------------------
# 8. Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Setup Complete — v5 · Skills + Agents + Teams · Bedrock  ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Architecture:${NC}"
echo -e "    ${CYAN}Skills${NC} (~/.claude/skills/) → task workflows, /skill-name"
echo -e "    ${GREEN}Agents${NC} (~/.claude/agents/) → specialist subagents"
echo -e "    Skills use ${DIM}context: fork${NC} + ${DIM}agent: team-lead${NC} for isolated execution"
echo ""
echo -e "  ${BOLD}Hierarchy:${NC}"
echo -e "    ${YELLOW}👤 Master${NC} → invokes /skills"
echo -e "    ${DIM} └──${NC} ${GREEN}🎖 team-lead${NC} ${DIM}(orchestrator agent)${NC}"
echo -e "    ${DIM}      ├──${NC} ${BLUE}🏗 architect${NC} ${DIM}(design + gate)${NC}"
echo -e "    ${DIM}      ├──${NC} ${CYAN}💻 dev ×1-5${NC} ${DIM}(TDD, worktrees)${NC}"
echo -e "    ${DIM}      ├──${NC} ${BLUE}✅ qa${NC} ${DIM}(e2e, integrate worktree)${NC}"
echo -e "    ${DIM}      ├──${NC} ${BLUE}🛡 security${NC} ${DIM}(gate)${NC}"
echo -e "    ${DIM}      ├──${NC} ${BLUE}📋 pm${NC} ${DIM}(scope)${NC}"
echo -e "    ${DIM}      └──${NC} ${BLUE}🔭 explorer${NC} ${DIM}(scout)${NC}"
echo ""
echo -e "  ${BOLD}Pipeline:${NC}"
echo -e "    ${GREEN}Plan${NC} → ${CYAN}Build TDD (worktrees)${NC} → ${YELLOW}Peer Review${NC} → ${BLUE}Merge${NC} → ${BLUE}QA${NC} → ${RED}Gate${NC} → ${GREEN}Done${NC}"
echo ""
echo -e "  ${BOLD}State:${NC}  .claude/tasks/{slug}/*.md    ${BOLD}Code:${NC} .worktrees/{slug}/dev-{N}/"
echo ""
echo -e "  ${BOLD}Skills:${NC}"
echo -e "    ${YELLOW}/lead-start${NC}   — Start or resume (--devs N)"
echo -e "    ${YELLOW}/lead-summary${NC} — Progress + blockers"
echo -e "    ${YELLOW}/lead-cleanup${NC} — Remove worktrees"
echo -e "    ${BLUE}/review-pr${NC}    — PR review"
echo -e "    ${BLUE}/arch-review${NC}  — Architecture audit"
echo -e "    ${BLUE}/investigate${NC}  — Incident investigation"
echo -e "    ${BLUE}/strategy${NC}     — Strategic decisions"
echo -e "    ${BLUE}/scope${NC}        — Project scoping"
echo -e "    ${BLUE}/quick-scan${NC}   — Health check"
echo ""
echo -e "  ${BOLD}Agent Teams (parallel instances):${NC}"
echo -e "    ${GREEN}/team-start${NC}   — Spawn team (--members N)"
echo -e "    ${GREEN}/team-status${NC}  — Monitor team progress"
echo -e "    ${GREEN}/team-stop${NC}    — Clean up team"
echo ""
echo -e "  ${BOLD}Quick start:${NC}"
echo -e "    cd your-project && claude"
echo -e "    ${YELLOW}/lead-start --devs 3 implement OAuth2 PKCE with MFA${NC}"
echo -e "    ${DIM}(next session)${NC}"
echo -e "    ${YELLOW}/lead-start oauth2-pkce-with-mfa${NC}   ${DIM}← resumes${NC}"
echo -e "    ${YELLOW}/lead-summary${NC}                      ${DIM}← status${NC}"
echo -e "    ${DIM}(agent teams — true parallel)${NC}"
echo -e "    ${GREEN}/team-start --agents pm,architect,explorer {team-name}${NC}"
echo -e "    ${GREEN}/team-status {team-name}${NC}          ${DIM}← progress${NC}"
echo -e "    ${GREEN}/team-stop {team-name}${NC}             ${DIM}← cleanup${NC}"
echo ""
echo -e "  ${DIM}Installed:${NC}"
echo -e "    ${DIM}~/.claude/settings.json${NC}"
echo -e "    ${DIM}~/.claude/CLAUDE.md (appended, not overwritten)${NC}"
echo -e "    ${DIM}~/.claude/agents/*.md  (7 agents)${NC}"
echo -e "    ${DIM}~/.claude/skills/*/SKILL.md  (12 skills: 9 pipeline + 3 team)${NC}"
echo ""
