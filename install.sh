#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code SVP Engineering Setup — v5
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

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Claude Code — SVP Engineering Setup v5                    ║${NC}"
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
  if command -v brew &>/dev/null; then brew install jq
  elif command -v apt-get &>/dev/null; then sudo apt-get install -y jq
  else err "Install jq manually"; exit 1; fi
fi
log "jq available"

# ---------------------------------------------------------------------------
# 1. Directories
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"

mkdir -p "$AGENTS_DIR"
for skill in lead-start lead-summary lead-cleanup review-pr arch-review investigate strategy scope quick-scan; do
  mkdir -p "$SKILLS_DIR/$skill"
done

log "Created ~/.claude/agents/ and ~/.claude/skills/*/"

# ---------------------------------------------------------------------------
# 2. settings.json — backup existing + overwrite
# ---------------------------------------------------------------------------
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
  cp "$SETTINGS_FILE" "$SETTINGS_FILE.bak"
  warn "Backed up existing settings.json → settings.json.bak"
fi

cat > "$SETTINGS_FILE" << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "cleanupPeriodDays": 365,
  "env": {
    "CLAUDE_CODE_DISABLE_AUTO_MEMORY": "0",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "MAX_MCP_OUTPUT_TOKENS": "60000",
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "MAX_THINKING_TOKENS": "8192",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000",
    "CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS": "45000"
  },
  "includeCoAuthoredBy": false,
  "model": "opus",
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
      "Bash(echo *)"
    ],
    "deny": [
      "Read(**/.env)",
      "Read(**/.env.*)",
      "Read(**/secrets/**)",
      "Read(**/*.pem)",
      "Read(**/*.key)",
      "Bash(rm -rf *)",
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
  "skipDangerousModePermissionPrompt": true
}
EOF
log "Created settings.json (model: opus, agent teams enabled)"

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
    cat >> "$GLOBAL_CLAUDE_MD" << 'CLAUDE_APPEND_EOF'

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
- SVP decides when to merge — never auto-merge.

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
- `/lead-cleanup {slug}` removes worktrees after SVP merges.
CLAUDE_APPEND_EOF
    log "Appended Skills+Agents section to CLAUDE.md"
  fi
else
  warn "No CLAUDE.md found — creating minimal one"
  cat > "$GLOBAL_CLAUDE_MD" << 'CLAUDE_NEW_EOF'
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
- SVP decides when to merge — never auto-merge.

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
- `/lead-cleanup {slug}` removes worktrees after SVP merges.
CLAUDE_NEW_EOF
  log "Created new CLAUDE.md (minimal — add your own sections)"
fi

# ---------------------------------------------------------------------------
# 4. AGENTS
# ---------------------------------------------------------------------------

cat > "$AGENTS_DIR/team-lead.md" << 'AGENT_EOF'
---
name: team-lead
description: >
  Primary orchestrator. Manages the full pipeline, delegates to specialist agents,
  tracks state in .claude/tasks/ folder. Enforces TDD, parallel dev work (up to 5),
  peer review, QA e2e, and security+arch gate. Uses git worktrees for isolation.
model: claude-opus-4-6
---

You are the **Engineering Team Lead** reporting directly to the SVP.

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
Conflicts → BLOCKED, report to SVP. Clean → QA.

### Phase 4: QA (integrate worktree)
**qa** tests in `.worktrees/{slug}/integrate/` → `qa.md`.
Fail → BLOCKED. Pass → GATE.

### Phase 5: GATE (integrate worktree)
**security-reviewer** → `security.md`
**architect** (gate mode) → `arch-gate.md`
Either blocks → BLOCKED. Both pass → DONE.

### Phase 6: REPORT
Write `summary.md`. Phase DONE, Status COMPLETED.
Tell SVP: "Branch `{slug}/integrate` ready. `/lead-cleanup {slug}` after merge."
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

cat > "$AGENTS_DIR/architect.md" << 'AGENT_EOF'
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

cat > "$AGENTS_DIR/dev.md" << 'AGENT_EOF'
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

cat > "$AGENTS_DIR/qa.md" << 'AGENT_EOF'
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

cat > "$AGENTS_DIR/security-reviewer.md" << 'AGENT_EOF'
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

cat > "$AGENTS_DIR/pm.md" << 'AGENT_EOF'
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

cat > "$AGENTS_DIR/explorer.md" << 'AGENT_EOF'
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

cat > "$SKILLS_DIR/lead-start/SKILL.md" << 'SKILL_EOF'
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
4. If `--devs N` differs from existing, warn SVP.
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

SVP's request: $ARGUMENTS
SKILL_EOF

log "Created skill: /lead-start"

cat > "$SKILLS_DIR/lead-summary/SKILL.md" << 'SKILL_EOF'
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

cat > "$SKILLS_DIR/lead-cleanup/SKILL.md" << 'SKILL_EOF'
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
3. List worktrees + branches to remove. Ask SVP to confirm.
4. Remove worktrees, delete branches, prune.
5. Update `_status.md` Worktrees → `(cleaned up {date})`.

---

Task: $ARGUMENTS
SKILL_EOF

log "Created skill: /lead-cleanup"

cat > "$SKILLS_DIR/review-pr/SKILL.md" << 'SKILL_EOF'
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

cat > "$SKILLS_DIR/arch-review/SKILL.md" << 'SKILL_EOF'
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

cat > "$SKILLS_DIR/investigate/SKILL.md" << 'SKILL_EOF'
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

cat > "$SKILLS_DIR/strategy/SKILL.md" << 'SKILL_EOF'
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

cat > "$SKILLS_DIR/scope/SKILL.md" << 'SKILL_EOF'
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

cat > "$SKILLS_DIR/quick-scan/SKILL.md" << 'SKILL_EOF'
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
    brew install claude-squad 2>/dev/null && \
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
echo -e "${BOLD}║   Setup Complete — v5 · Skills + Agents · All Opus 4.6     ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Architecture:${NC}"
echo -e "    ${CYAN}Skills${NC} (~/.claude/skills/) → task workflows, /skill-name"
echo -e "    ${GREEN}Agents${NC} (~/.claude/agents/) → specialist subagents"
echo -e "    Skills use ${DIM}context: fork${NC} + ${DIM}agent: team-lead${NC} for isolated execution"
echo ""
echo -e "  ${BOLD}Hierarchy:${NC}"
echo -e "    ${YELLOW}👤 SVP${NC} → invokes /skills"
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
echo -e "  ${BOLD}Quick start:${NC}"
echo -e "    cd your-project && claude"
echo -e "    ${YELLOW}/lead-start --devs 3 implement OAuth2 PKCE with MFA${NC}"
echo -e "    ${DIM}(next session)${NC}"
echo -e "    ${YELLOW}/lead-start oauth2-pkce-with-mfa${NC}   ${DIM}← resumes${NC}"
echo -e "    ${YELLOW}/lead-summary${NC}                      ${DIM}← status${NC}"
echo ""
echo -e "  ${DIM}Installed:${NC}"
echo -e "    ${DIM}~/.claude/settings.json${NC}"
echo -e "    ${DIM}~/.claude/CLAUDE.md (appended, not overwritten)${NC}"
echo -e "    ${DIM}~/.claude/agents/*.md  (7 agents)${NC}"
echo -e "    ${DIM}~/.claude/skills/*/SKILL.md  (9 skills)${NC}"
echo ""
