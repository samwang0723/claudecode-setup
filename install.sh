#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code Master Engineering Setup — v6
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

# ---------------------------------------------------------------------------
# Backup & manifest paths
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/.kit-backup"
MANIFEST_FILE="$CLAUDE_DIR/.kit-manifest"

manifest() {
	echo "$1:$2" >>"$MANIFEST_FILE"
}

# ---------------------------------------------------------------------------
# Revert function — restores pre-install state from manifest
# ---------------------------------------------------------------------------
revert_kit() {
	echo ""
	echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}║   Claude Code Kit — Revert                                  ║${NC}"
	echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
	echo ""

	if [ ! -f "$MANIFEST_FILE" ]; then
		err "No kit manifest found at $MANIFEST_FILE"
		info "Nothing to revert (kit may not have been installed)"
		return 1
	fi

	local errors=0

	while IFS= read -r line; do
		# Skip comments and blank lines
		[[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

		local action="${line%%:*}"
		local filepath="${line#*:}"
		# Strip extra info after second colon
		filepath="${filepath%%:*}"
		# Expand ~ to $HOME
		filepath="${filepath/#\~/$HOME}"

		case "$action" in
		CREATED)
			if [ -f "$filepath" ]; then
				rm -f "$filepath"
				log "Deleted: $filepath"
			else
				info "Already gone: $filepath"
			fi
			;;
		CREATED_DIR)
			if [ -d "$filepath" ] && [ -z "$(ls -A "$filepath" 2>/dev/null)" ]; then
				rmdir "$filepath"
				log "Removed empty dir: $filepath"
			else
				info "Skipped non-empty or missing dir: $filepath"
			fi
			;;
		BACKED_UP)
			local backup_name
			backup_name=$(basename "$filepath")
			local backup_path="$BACKUP_DIR/$backup_name"
			if [ -f "$backup_path" ]; then
				cp "$backup_path" "$filepath"
				log "Restored: $filepath (from backup)"
			else
				warn "No backup found for $filepath — skipping"
				((errors++)) || true
			fi
			;;
		CREATED_MINIMAL)
			if [ -f "$filepath" ]; then
				warn "Kept: $filepath (may contain user edits — review manually)"
			fi
			;;
		*)
			warn "Unknown action '$action' for $filepath — skipping"
			;;
		esac
	done <"$MANIFEST_FILE"

	# Auto-strip legacy kit sections from CLAUDE.md
	local global_claude_md="$CLAUDE_DIR/CLAUDE.md"
	if [ -f "$global_claude_md" ] && grep -qnF "## Architecture: Skills + Agents" "$global_claude_md"; then
		cp "$global_claude_md" "$BACKUP_DIR/CLAUDE.md.pre-strip"
		local marker_line
		marker_line=$(grep -nF "## Architecture: Skills + Agents" "$global_claude_md" | head -1 | cut -d: -f1)
		# Also strip preceding blank lines (up to 2)
		local start_line=$((marker_line > 2 ? marker_line - 2 : marker_line))
		sed -i '' "${start_line},\$d" "$global_claude_md"
		# Trim trailing blank lines
		sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$global_claude_md"
		log "Stripped old kit sections from CLAUDE.md (backed up to .kit-backup/)"
	fi

	# Clean up empty directories
	for skill_dir in "$CLAUDE_DIR/skills"/*/; do
		[ -d "$skill_dir" ] && [ -z "$(ls -A "$skill_dir" 2>/dev/null)" ] && rmdir "$skill_dir" 2>/dev/null || true
	done
	[ -d "$CLAUDE_DIR/skills" ] && [ -z "$(ls -A "$CLAUDE_DIR/skills" 2>/dev/null)" ] && rmdir "$CLAUDE_DIR/skills" 2>/dev/null || true
	[ -d "$CLAUDE_DIR/agents" ] && [ -z "$(ls -A "$CLAUDE_DIR/agents" 2>/dev/null)" ] && rmdir "$CLAUDE_DIR/agents" 2>/dev/null || true
	[ -d "$CLAUDE_DIR/rules/kit" ] && [ -z "$(ls -A "$CLAUDE_DIR/rules/kit" 2>/dev/null)" ] && rmdir "$CLAUDE_DIR/rules/kit" 2>/dev/null || true

	# Remove manifest and backup dir
	rm -f "$MANIFEST_FILE"
	if [ -d "$BACKUP_DIR" ]; then
		rm -rf "$BACKUP_DIR"
		log "Removed backup directory"
	fi

	echo ""
	if [ "$errors" -eq 0 ]; then
		log "Revert complete. Kit files removed, backups restored."
	else
		warn "Revert completed with $errors warning(s). Review output above."
	fi
	echo ""
}

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--revert" ]; then
	revert_kit
	exit 0
fi

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
# 1. Directories + manifest init
# ---------------------------------------------------------------------------
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"
RULES_KIT_DIR="$CLAUDE_DIR/rules/kit"

mkdir -p "$AGENTS_DIR" "$RULES_KIT_DIR" "$BACKUP_DIR"

SKILL_NAMES="lead-start lead-summary lead-cleanup review-pr arch-review investigate strategy scope quick-scan team-start team-status team-stop"
for skill in $SKILL_NAMES; do
	mkdir -p "$SKILLS_DIR/$skill"
done

# Initialize manifest (overwrite any previous)
cat >"$MANIFEST_FILE" <<MANIFEST_HEADER
# claudecode-setup kit manifest
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
MANIFEST_HEADER

manifest "CREATED_DIR" "~/.claude/agents"
manifest "CREATED_DIR" "~/.claude/rules/kit"
for skill in $SKILL_NAMES; do
	manifest "CREATED_DIR" "~/.claude/skills/$skill"
done

log "Created ~/.claude/agents/, ~/.claude/rules/kit/, and ~/.claude/skills/*/"

# ---------------------------------------------------------------------------
# 2. settings.json — merge with existing (preserves user customizations)
# ---------------------------------------------------------------------------
SETTINGS_FILE="$CLAUDE_DIR/settings.json"

# Kit default settings
KIT_DEFAULTS=$(cat <<'DEFAULTS_EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "MAX_MCP_OUTPUT_TOKENS": "60000",
    "BASH_DEFAULT_TIMEOUT_MS": "300000",
    "BASH_MAX_TIMEOUT_MS": "600000",
    "MAX_THINKING_TOKENS": "8192",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000",
    "CLAUDE_CODE_FILE_READ_MAX_OUTPUT_TOKENS": "45000",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "model": "opus",
  "effortLevel": "high",
  "alwaysThinkingEnabled": true,
  "showTurnDuration": true,
  "cleanupPeriodDays": 365,
  "includeCoAuthoredBy": false,
  "includeGitInstructions": true,
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
      "Bash(rtk *)",
      "Bash(fd *)",
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
  "teammateMode": "tmux"
}
DEFAULTS_EOF
)

# Validate KIT_DEFAULTS JSON before any merge/write
if ! echo "$KIT_DEFAULTS" | jq empty 2>/dev/null; then
	err "KIT_DEFAULTS contains invalid JSON — aborting settings.json update"
	exit 1
fi

if [ -f "$SETTINGS_FILE" ]; then
	# Validate existing JSON before attempting merge
	if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
		warn "Existing settings.json is invalid JSON — backing up and creating fresh"
		cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json.invalid"
		echo "$KIT_DEFAULTS" | jq . >"$SETTINGS_FILE"
		manifest "BACKED_UP" "~/.claude/settings.json"
		log "Created settings.json (fresh — invalid original backed up)"
	else
		cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json"
		manifest "BACKED_UP" "~/.claude/settings.json"

		# Deep merge: kit defaults as base, user values override
		# Objects merge recursively (user wins per key)
		# Arrays union + deduplicate (both kit and user entries kept)
		# Scalars: user value wins if present
		MERGED=$(jq -n \
			--argjson kit "$KIT_DEFAULTS" \
			--slurpfile user "$SETTINGS_FILE" \
			'
			def deep_merge(a; b):
				if (a | type) == "object" and (b | type) == "object" then
					([a, b] | map(keys) | add | unique) | map(
						. as $k |
						if (a | has($k)) and (b | has($k)) then
							{($k): deep_merge(a[$k]; b[$k])}
						elif (b | has($k)) then
							{($k): b[$k]}
						else
							{($k): a[$k]}
						end
					) | add // {}
				elif (a | type) == "array" and (b | type) == "array" then
					(a + b) | unique
				else
					b
				end;

			deep_merge($kit; $user[0])
			')

		# Validate merge output before writing
		if echo "$MERGED" | jq empty 2>/dev/null; then
			echo "$MERGED" | jq . >"$SETTINGS_FILE"
			log "Merged settings.json (user values preserved)"
		else
			err "settings.json merge produced invalid JSON — restoring backup"
			cp "$BACKUP_DIR/settings.json" "$SETTINGS_FILE"
			exit 1
		fi
	fi
else
	echo "$KIT_DEFAULTS" | jq . >"$SETTINGS_FILE"
	log "Created settings.json (kit defaults)"
fi

# Final validation: ensure settings.json is valid before continuing
if ! jq empty "$SETTINGS_FILE" 2>/dev/null; then
	err "settings.json is invalid after write — restoring backup if available"
	if [ -f "$BACKUP_DIR/settings.json" ]; then
		cp "$BACKUP_DIR/settings.json" "$SETTINGS_FILE"
		warn "Restored settings.json from backup"
	fi
	exit 1
fi

# ---------------------------------------------------------------------------
# 2b. statusline.sh → ~/.claude/statusline.sh
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/statusline.sh" ]; then
	if [ -f "$CLAUDE_DIR/statusline.sh" ]; then
		cp "$CLAUDE_DIR/statusline.sh" "$BACKUP_DIR/statusline.sh"
		manifest "BACKED_UP" "~/.claude/statusline.sh"
	fi
	cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
	chmod +x "$CLAUDE_DIR/statusline.sh"
	manifest "CREATED" "~/.claude/statusline.sh"
	log "Copied statusline.sh → ~/.claude/statusline.sh"
else
	warn "statusline.sh not found in $SCRIPT_DIR — skipping"
fi

# ---------------------------------------------------------------------------
# 3. Kit rules — ~/.claude/rules/kit/CLAUDE-kit.md (auto-loaded by Claude Code)
# ---------------------------------------------------------------------------
KIT_RULES_FILE="$RULES_KIT_DIR/CLAUDE-kit.md"

cat >"$KIT_RULES_FILE" <<'KIT_EOF'
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
KIT_EOF

manifest "CREATED" "~/.claude/rules/kit/CLAUDE-kit.md"
log "Created rules/kit/CLAUDE-kit.md (auto-loaded by Claude Code)"

# --- Handle CLAUDE.md: strip legacy markers, create minimal if missing ---
GLOBAL_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
LEGACY_MARKER="## Architecture: Skills + Agents"

KIT_REF_MARKER="@rules/kit/CLAUDE-kit.md"

if [ -f "$GLOBAL_CLAUDE_MD" ]; then
	if grep -qF "$LEGACY_MARKER" "$GLOBAL_CLAUDE_MD"; then
		warn "Found old kit sections in CLAUDE.md — stripping (content now in rules/kit/)"
		cp "$GLOBAL_CLAUDE_MD" "$BACKUP_DIR/CLAUDE.md"
		manifest "BACKED_UP" "~/.claude/CLAUDE.md"
		MARKER_LINE=$(grep -nF "$LEGACY_MARKER" "$GLOBAL_CLAUDE_MD" | head -1 | cut -d: -f1)
		# Also strip preceding blank lines (up to 2)
		START_LINE=$((MARKER_LINE > 2 ? MARKER_LINE - 2 : MARKER_LINE))
		sed -i '' "${START_LINE},\$d" "$GLOBAL_CLAUDE_MD"
		# Trim trailing blank lines
		sed -i '' -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$GLOBAL_CLAUDE_MD"
		log "Stripped old kit sections from CLAUDE.md (backed up to .kit-backup/)"
	fi

	# Add kit reference if not already present
	if ! grep -qF "$KIT_REF_MARKER" "$GLOBAL_CLAUDE_MD"; then
		printf '\n%s\n' "$KIT_REF_MARKER" >>"$GLOBAL_CLAUDE_MD"
		log "Added kit reference to CLAUDE.md"
	else
		info "CLAUDE.md already has kit reference — skipping"
	fi
else
	warn "No CLAUDE.md found — creating minimal one"
	cat >"$GLOBAL_CLAUDE_MD" <<'CLAUDE_MINIMAL_EOF'
# CLAUDE.md

Global instructions for Claude Code.

Add your personal instructions below.

@rules/kit/CLAUDE-kit.md
CLAUDE_MINIMAL_EOF
	manifest "CREATED_MINIMAL" "~/.claude/CLAUDE.md"
	log "Created minimal CLAUDE.md (with kit reference)"
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

## Team Mode (Agent Teams)

When operating with Agent Teams (spawned via `/team-start`), you manage **dual state tracking**:

### Dual State: JSON Tasks + Markdown

| System | Location | Purpose |
|--------|----------|---------|
| JSON tasks | `~/.claude/tasks/{team-name}/` | Real-time teammate coordination (built-in) |
| Markdown state | `.claude/tasks/{slug}/` | Persistent memory, audit trail, resume support |

**Both MUST stay in sync.** When updating JSON tasks (TaskCreate/TaskUpdate), also update:
1. `_status.md` — Phase, checklist, Team Members table
2. Role-specific `.md` files — written by teammates when they complete work

### Team Mode Pipeline

Same phases as standard pipeline, but execution uses Agent Teams:

1. **PLAN** — Send requirements task to pm teammate, design task to architect teammate
2. **BUILD** — Assign dev teammates to worktrees. Each dev works in `.worktrees/{slug}/dev-{N}/`
3. **PEER_REVIEW** — Dev teammates cross-review (skip if 1 dev)
4. **MERGE** — Create integrate worktree, merge dev branches
5. **QA** — qa teammate tests in integrate worktree
6. **GATE** — security-reviewer + architect review in integrate worktree
7. **REPORT** — Write `summary.md`, mark DONE

### Teammate Markdown Instructions

When assigning tasks to teammates via SendMessage, ALWAYS remind them:
```
Remember to:
1. Read .claude/tasks/{slug}/_status.md for current state
2. Write your report to .claude/tasks/{slug}/{role}-{N}.md when done
3. Update _status.md Team Members table with your status
```

### Syncing State

After each phase transition:
1. Update `_status.md` Phase + checklist
2. Verify all role `.md` files exist for completed phases
3. Update Team Members table with latest status

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
manifest "CREATED" "~/.claude/agents/team-lead.md"

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
You will use /write-tech-spec to write formal CDC Tech spec with mermaid diagram, and use /md-to-confluence to upload to Confluence Wiki

## MANDATORY: Markdown State Tracking
Whether spawned via `/lead-start` or `/team-start`, you MUST:
1. **Read** `.claude/tasks/{slug}/_status.md` before starting work.
2. **Write** your report to `.claude/tasks/{slug}/architect.md` (design) or `.claude/tasks/{slug}/arch-gate.md` (gate) when completing work.
3. **Update** `_status.md` Phase, Devs count, checklist, and Team Members table (if table exists).

## Design Phase

1. Mermaid diagrams. Break into N areas (check `_status.md` Devs — if TBD, decide 1-5).
2. Each area independently implementable with clear interfaces.
3. Update `_status.md`: set `Devs: {N}`, expand BUILD checklist.

Write to `.claude/tasks/{slug}/architect.md`:
```markdown
# Architect Report: Design
Task: {slug}
Date: {date}
Status: COMPLETED | IN_PROGRESS | BLOCKED

## Architecture Overview
[Mermaid diagrams]

## Component Breakdown
| Area | Dev | Scope | Interfaces |
|------|-----|-------|------------|

## Key Design Decisions
## API Contracts
## Risks & Trade-offs
```

## Gate Phase

Review code in `.worktrees/{slug}/integrate/`. Check design compliance, drift, coupling.

Write to `.claude/tasks/{slug}/arch-gate.md`:
```markdown
# Architect Gate Review
Task: {slug}
Date: {date}
Gate Decision: PASS ✅ | CONDITIONAL ⚠️ | FAIL 🛑

## Design Compliance
## Drift from Original Design
## Coupling Analysis
## Findings
```
AGENT_EOF

log "Created agent: architect"
manifest "CREATED" "~/.claude/agents/architect.md"

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

## MANDATORY: Markdown State Tracking
Whether spawned via `/lead-start` or `/team-start`, you MUST:
1. **Read** `.claude/tasks/{slug}/_status.md` before starting work.
2. **Write** your report to `.claude/tasks/{slug}/dev-{N}.md` when completing work.
3. **Update** `_status.md` Team Members table with your status (if table exists).

### Report Format: `dev-{N}.md`
```markdown
# Dev Report: dev-{N}
Task: {slug}
Date: {date}
Area: {area}
Status: COMPLETED | IN_PROGRESS | BLOCKED

## Summary
[Scope, approach, key decisions]

## TDD Cycle
| Step | Test | Status |
|------|------|--------|
| RED | {test name} | Failing ✅ |
| GREEN | {test name} | Passing ✅ |
| REFACTOR | cleanup | Done ✅ |

## Files Modified
[List with brief descriptions]

## Test Results
[Test output, coverage]

## Interfaces / APIs Added
[Signatures, types]

## Concerns
[Anything team-lead should know]
```

## SKILLS to Choose based on task
- /effective-go when handling Golang
- /effective-rails when handling Rails
- /effective-rust when handling Rust

## MANDATORY: TDD
```
RED    → Write failing tests first
GREEN  → Minimum code to pass
REFACTOR → Clean up, tests stay green
```
**NEVER write implementation before tests.**

Test frameworks: vitest/jest (TS), go test (Go), #[test] (Rust), rspec (Rails)

## Peer Review: append to `peer-review.md`
Check TDD compliance, correctness, edge cases. Verdict: APPROVED ✅ | NEEDS CHANGES 🔄 | BLOCKED 🛑
AGENT_EOF

log "Created agent: dev"
manifest "CREATED" "~/.claude/agents/dev.md"

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

## MANDATORY: Markdown State Tracking
Whether spawned via `/lead-start` or `/team-start`, you MUST:
1. **Read** `.claude/tasks/{slug}/_status.md` before starting work.
2. **Write** your report to `.claude/tasks/{slug}/qa.md` when completing work.
3. **Update** `_status.md` Team Members table with your status (if table exists).

## Worktree: Test in `.worktrees/{slug}/integrate/`. Docs → main repo.
## Focus: e2e ONLY (not unit tests). Integration, user flows, error flows, contract compliance.

## Report: `qa.md`

Write to `.claude/tasks/{slug}/qa.md`:
```markdown
# QA Report
Task: {slug}
Date: {date}
Status: COMPLETED | IN_PROGRESS | BLOCKED
Verdict: PASS ✅ | FAIL 🛑

## Test Environment
[Worktree, tooling, config]

## Integration Matrix
| Component A | Component B | Status |
|-------------|-------------|--------|

## Test Results
### User Flows
### Error Paths
### Contract Compliance

## Issues Found
| # | Severity | Description | Status |
|---|----------|-------------|--------|

## Recommendations
```
AGENT_EOF

log "Created agent: qa"
manifest "CREATED" "~/.claude/agents/qa.md"

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

## MANDATORY: Markdown State Tracking
Whether spawned via `/lead-start` or `/team-start`, you MUST:
1. **Read** `.claude/tasks/{slug}/_status.md` before starting work.
2. **Write** your report to `.claude/tasks/{slug}/security.md` when completing work.
3. **Update** `_status.md` Team Members table with your status (if table exists).

## Worktree: Review in `.worktrees/{slug}/integrate/`. Docs → main repo.
## STRIDE: Spoofing, Tampering, Repudiation, Info Disclosure, DoS, Elevation.

## Report: `security.md`

Write to `.claude/tasks/{slug}/security.md`:
```markdown
# Security Review
Task: {slug}
Date: {date}
Status: COMPLETED | IN_PROGRESS | BLOCKED
Risk Level: LOW | MEDIUM | HIGH | CRITICAL
Gate Decision: PASS ✅ | CONDITIONAL ⚠️ | FAIL 🛑

## Threat Model (STRIDE)
| Threat | Applicable | Mitigated | Notes |
|--------|-----------|-----------|-------|
| Spoofing | | | |
| Tampering | | | |
| Repudiation | | | |
| Info Disclosure | | | |
| DoS | | | |
| Elevation | | | |

## Findings by Severity
### Critical
### High
### Medium
### Low

## Compliance
[PCI-DSS, SOC2, crypto wallet security notes]

## Recommendations
```
AGENT_EOF

log "Created agent: security-reviewer"
manifest "CREATED" "~/.claude/agents/security-reviewer.md"

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
You will use /write-prd to write formal CDC PRD spec with mermaid diagram, and use /md-to-confluence to upload to Confluence Wiki.

## MANDATORY: Markdown State Tracking
Whether spawned via `/lead-start` or `/team-start`, you MUST:
1. **Read** `.claude/tasks/{slug}/_status.md` before starting work.
2. **Write** your report to `.claude/tasks/{slug}/pm.md` when completing work.
3. **Update** `_status.md` Team Members table with your status (if table exists).

## Report: `pm.md`

Write to `.claude/tasks/{slug}/pm.md`:
```markdown
# PM Report
Task: {slug}
Date: {date}
Status: COMPLETED | IN_PROGRESS | BLOCKED

## Requirements (MoSCoW)
### Must Have
### Should Have
### Could Have
### Won't Have

## Success Criteria
## Estimates & Milestones
## Risks & Mitigations
## Recommendation
```
AGENT_EOF

log "Created agent: pm"
manifest "CREATED" "~/.claude/agents/pm.md"

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

## MANDATORY: Markdown State Tracking
Whether spawned via `/lead-start` or `/team-start`, you MUST:
1. **Read** `.claude/tasks/{slug}/_status.md` before starting work (if slug is provided).
2. **Write** your findings to `.claude/tasks/{slug}/explorer.md` when completing work.
3. **Update** `_status.md` Team Members table with your status (if table exists).

### Report Format: `explorer.md`
```markdown
# Explorer Report
Task: {slug}
Date: {date}
Status: COMPLETED

## Codebase Structure
[Key directories, entry points]

## Relevant Files
[Paths with brief descriptions]

## Patterns & Conventions
[Coding style, frameworks, naming]

## Key Findings
[Anything the team should know]
```
AGENT_EOF

log "Created agent: explorer"
manifest "CREATED" "~/.claude/agents/explorer.md"

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
manifest "CREATED" "~/.claude/skills/lead-start/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/lead-summary/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/lead-cleanup/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/review-pr/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/arch-review/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/investigate/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/strategy/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/scope/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/quick-scan/SKILL.md"

# ---------------------------------------------------------------------------
# 5b. AGENT TEAM SKILLS
# ---------------------------------------------------------------------------

cat >"$SKILLS_DIR/team-start/SKILL.md" <<'SKILL_EOF'
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
SKILL_EOF

log "Created skill: /team-start"
manifest "CREATED" "~/.claude/skills/team-start/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/team-status/SKILL.md"

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
manifest "CREATED" "~/.claude/skills/team-stop/SKILL.md"

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
echo -e "${BOLD}║   Setup Complete — v6 · Skills + Agents + Teams            ║${NC}"
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
echo -e "    ${DIM}~/.claude/settings.json (merged with existing)${NC}"
echo -e "    ${DIM}~/.claude/rules/kit/CLAUDE-kit.md (auto-loaded)${NC}"
echo -e "    ${DIM}~/.claude/agents/*.md  (7 agents)${NC}"
echo -e "    ${DIM}~/.claude/skills/*/SKILL.md  (12 skills: 9 pipeline + 3 team)${NC}"
echo -e "    ${DIM}~/.claude/statusline.sh${NC}"
echo ""
echo -e "  ${BOLD}Revert:${NC}"
echo -e "    ${YELLOW}./install.sh --revert${NC}  ${DIM}← removes kit files, restores backups${NC}"
echo -e "    ${DIM}Manifest: ~/.claude/.kit-manifest${NC}"
echo -e "    ${DIM}Backups:  ~/.claude/.kit-backup/${NC}"
echo ""
