#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Claude Code Master Engineering Setup — v6
# Skills-based · Agents + Skills · Git Worktrees · Stateful Tasks
# All Opus 4.6 · TDD Pipeline
# ============================================================================

KIT_VERSION="6.0.0"

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

BOX_W=60
box_top()  { local bar; bar=$(printf '%0.s=' $(seq 1 $BOX_W)); echo -e "${BOLD}+${bar}+${NC}"; }
box_bot()  { local bar; bar=$(printf '%0.s=' $(seq 1 $BOX_W)); echo -e "${BOLD}+${bar}+${NC}"; }
box_line() { printf -v _pad "%-${BOX_W}s" "$1"; echo -e "${BOLD}|${_pad}|${NC}"; }

TOTAL_STEPS=9
CURRENT_STEP=0
step() {
	((CURRENT_STEP++))
	echo ""
	echo -e "${GREEN}[$CURRENT_STEP/$TOTAL_STEPS]${NC} ${BOLD}$1${NC}"
}

DRY_RUN=false
YES_FLAG=false

# ---------------------------------------------------------------------------
# Script & template paths
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# ---------------------------------------------------------------------------
# Backup & manifest paths
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/.kit-backup"
MANIFEST_FILE="$CLAUDE_DIR/.kit-manifest"

manifest() {
	echo "$1:$2" >>"$MANIFEST_FILE"
}

# Install a template file to ~/.claude/, recording in manifest
# Usage: install_template <relative-path>  (e.g. "agents/team-lead.md")
install_template() {
	local rel="$1"
	local src="$TEMPLATES_DIR/$rel"
	local dst="$CLAUDE_DIR/$rel"
	if [ ! -f "$src" ]; then
		err "Template not found: $src"
		exit 1
	fi
	mkdir -p "$(dirname "$dst")"
	cp "$src" "$dst"
	manifest "CREATED" "~/.claude/$rel"
}

# ---------------------------------------------------------------------------
# Revert function — restores pre-install state from manifest
# ---------------------------------------------------------------------------
revert_kit() {
	echo ""
	box_top
	box_line "   Claude Code Kit -- Revert"
	box_bot
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
		# Cross-platform sed: use temp file + mv instead of sed -i
		sed "${start_line},\$d" "$global_claude_md" > "$global_claude_md.tmp" && mv "$global_claude_md.tmp" "$global_claude_md"
		# Trim trailing blank lines
		sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$global_claude_md" > "$global_claude_md.tmp" && mv "$global_claude_md.tmp" "$global_claude_md"
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
for arg in "$@"; do
	case "$arg" in
	--revert)
		revert_kit
		exit 0
		;;
	--dry-run)
		DRY_RUN=true
		;;
	--yes)
		YES_FLAG=true
		;;
	*)
		err "Unknown flag: $arg"
		echo "  Usage: ./install.sh [--revert] [--dry-run] [--yes]"
		exit 1
		;;
	esac
done

echo ""
box_top
box_line "   Claude Code -- Master Engineering Setup v${KIT_VERSION}"
box_line "   Skills + Agents + Worktrees + Stateful Tasks + TDD"
box_bot
echo ""

if $DRY_RUN; then
	info "${YELLOW}DRY RUN${NC} — no files will be modified"
	echo ""
fi

# ---------------------------------------------------------------------------
# 0. Pre-flight
# ---------------------------------------------------------------------------
step "Checking prerequisites..."
if ! command -v claude &>/dev/null; then
	err "Claude Code CLI not found. Install first:"
	echo "  npm install -g @anthropic-ai/claude-code"
	exit 1
fi
log "Claude Code CLI detected"

if [ ! -d "$TEMPLATES_DIR" ]; then
	err "Templates directory not found: $TEMPLATES_DIR"
	info "Ensure you run install.sh from the repository root"
	exit 1
fi
log "Templates directory found"

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

if ! command -v claude-powerline &>/dev/null; then
	info "Installing claude-powerline..."
	npm install -g @owloops/claude-powerline
	log "claude-powerline installed"
else
	log "claude-powerline available"
fi

# ---------------------------------------------------------------------------
# 1. Directories + manifest init
# ---------------------------------------------------------------------------
step "Creating directories..."
AGENTS_DIR="$CLAUDE_DIR/agents"
SKILLS_DIR="$CLAUDE_DIR/skills"
RULES_KIT_DIR="$CLAUDE_DIR/rules/kit"

# Auto-discover agents and skills from templates/
AGENT_NAMES=""
for f in "$TEMPLATES_DIR"/agents/*.md; do
	[ -f "$f" ] && AGENT_NAMES="$AGENT_NAMES $(basename "$f" .md)"
done
AGENT_NAMES="${AGENT_NAMES# }"  # trim leading space

SKILL_NAMES=""
for d in "$TEMPLATES_DIR"/skills/*/; do
	[ -f "$d/SKILL.md" ] && SKILL_NAMES="$SKILL_NAMES $(basename "$d")"
done
SKILL_NAMES="${SKILL_NAMES# }"  # trim leading space

AGENT_COUNT=$(echo "$AGENT_NAMES" | wc -w | tr -d ' ')
SKILL_COUNT=$(echo "$SKILL_NAMES" | wc -w | tr -d ' ')

if $DRY_RUN; then
	info "Would create ~/.claude/agents/"
	info "Would create ~/.claude/rules/kit/"
	info "Would create ~/.claude/.kit-backup/"
	for skill in $SKILL_NAMES; do
		info "Would create ~/.claude/skills/$skill/"
	done
else
	mkdir -p "$AGENTS_DIR" "$RULES_KIT_DIR" "$BACKUP_DIR"
	for skill in $SKILL_NAMES; do
		mkdir -p "$SKILLS_DIR/$skill"
	done

	# Version tracking — detect upgrade vs re-install
	if [ -f "$MANIFEST_FILE" ]; then
		INSTALLED_VERSION=$(grep "^VERSION:" "$MANIFEST_FILE" 2>/dev/null | cut -d: -f2 || true)
		if [ -n "$INSTALLED_VERSION" ]; then
			if [ "$INSTALLED_VERSION" = "$KIT_VERSION" ]; then
				info "Re-installing v${KIT_VERSION}"
			else
				info "Upgrading v${INSTALLED_VERSION} → v${KIT_VERSION}"
			fi
		fi
	fi

	# Initialize manifest (overwrite any previous)
	cat >"$MANIFEST_FILE" <<MANIFEST_HEADER
VERSION:${KIT_VERSION}
# claudecode-setup kit manifest
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
MANIFEST_HEADER

	manifest "CREATED_DIR" "~/.claude/agents"
	manifest "CREATED_DIR" "~/.claude/rules/kit"
	for skill in $SKILL_NAMES; do
		manifest "CREATED_DIR" "~/.claude/skills/$skill"
	done
	log "Created ~/.claude/agents/, ~/.claude/rules/kit/, and ~/.claude/skills/*/"
fi

# ---------------------------------------------------------------------------
# 2. settings.json — merge with existing (preserves user customizations)
# ---------------------------------------------------------------------------
step "Merging settings.json..."
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
    "command": "claude-powerline --style=powerline --theme=tokyo-night --config=~/.claude/powerline.json"
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

if $DRY_RUN; then
	if [ -f "$SETTINGS_FILE" ]; then
		info "Would merge kit defaults into existing ~/.claude/settings.json"
		info "Settings diff preview:"
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
			# Force-override: statusLine always uses kit value
			| if $kit | has("statusLine") then .statusLine = $kit.statusLine else . end
			' 2>/dev/null || echo "$KIT_DEFAULTS")
		diff <(jq --sort-keys . "$SETTINGS_FILE") <(echo "$MERGED" | jq --sort-keys .) || true
	else
		info "Would create ~/.claude/settings.json (kit defaults)"
	fi
else
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
			# Exception: "statusLine" is always overridden by kit (force-update)
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
				# Force-override: statusLine always uses kit value
				| if $kit | has("statusLine") then .statusLine = $kit.statusLine else . end
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
fi

# ---------------------------------------------------------------------------
# 2b. powerline.json → ~/.claude/powerline.json
# ---------------------------------------------------------------------------
if $DRY_RUN; then
	if [ -f "$TEMPLATES_DIR/powerline.json" ]; then
		info "Would copy powerline.json → ~/.claude/powerline.json"
	fi
else
	if [ -f "$TEMPLATES_DIR/powerline.json" ]; then
		if [ -f "$CLAUDE_DIR/powerline.json" ]; then
			cp "$CLAUDE_DIR/powerline.json" "$BACKUP_DIR/powerline.json"
			manifest "BACKED_UP" "~/.claude/powerline.json"
		fi
		cp "$TEMPLATES_DIR/powerline.json" "$CLAUDE_DIR/powerline.json"
		manifest "CREATED" "~/.claude/powerline.json"
		log "Copied powerline.json → ~/.claude/powerline.json"
	else
		warn "powerline.json not found in $TEMPLATES_DIR — skipping"
	fi
fi

# ---------------------------------------------------------------------------
# 3. Kit rules — ~/.claude/rules/kit/CLAUDE-kit.md (auto-loaded by Claude Code)
# ---------------------------------------------------------------------------
step "Setting up kit rules..."
if $DRY_RUN; then
	info "Would create ~/.claude/rules/kit/CLAUDE-kit.md"
	info "Would handle CLAUDE.md legacy markers + kit reference"
else

install_template "rules/kit/CLAUDE-kit.md"
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
		# Cross-platform sed: use temp file + mv instead of sed -i
		sed "${START_LINE},\$d" "$GLOBAL_CLAUDE_MD" > "$GLOBAL_CLAUDE_MD.tmp" && mv "$GLOBAL_CLAUDE_MD.tmp" "$GLOBAL_CLAUDE_MD"
		# Trim trailing blank lines
		sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$GLOBAL_CLAUDE_MD" > "$GLOBAL_CLAUDE_MD.tmp" && mv "$GLOBAL_CLAUDE_MD.tmp" "$GLOBAL_CLAUDE_MD"
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

fi # end dry-run check for section 3

# ---------------------------------------------------------------------------
# 4. AGENTS
# ---------------------------------------------------------------------------
step "Installing agents ($AGENT_COUNT)..."

if $DRY_RUN; then
	for agent in $AGENT_NAMES; do
		info "Would create ~/.claude/agents/$agent.md"
	done
else

for agent in $AGENT_NAMES; do
	install_template "agents/$agent.md"
	log "Created agent: $agent"
done

fi # end dry-run check for section 4

# ---------------------------------------------------------------------------
# 5. SKILLS
# ---------------------------------------------------------------------------
step "Installing skills ($SKILL_COUNT)..."

if $DRY_RUN; then
	for skill in $SKILL_NAMES; do
		info "Would create ~/.claude/skills/$skill/SKILL.md"
	done
else

for skill in $SKILL_NAMES; do
	install_template "skills/$skill/SKILL.md"
	log "Created skill: /$skill"
done

fi # end dry-run check for section 5

# ---------------------------------------------------------------------------
# 6. Clean up old commands
# ---------------------------------------------------------------------------
step "Checking for deprecated files..."
if [ -d "$CLAUDE_DIR/commands" ] && [ "$(ls -A "$CLAUDE_DIR/commands" 2>/dev/null)" ]; then
	warn "Found old ~/.claude/commands/ (deprecated)"
	info "Skills in ~/.claude/skills/ now replace commands."
	info "Remove old commands manually: rm -rf ~/.claude/commands/"
else
	log "No deprecated files found"
fi

# ---------------------------------------------------------------------------
# 7. RTK (Rust Token Killer) — token-optimized CLI proxy
# ---------------------------------------------------------------------------
step "Installing RTK..."
if $DRY_RUN; then
	info "Would install RTK (Rust Token Killer) if not present"
	info "Would run 'rtk init -g --auto-patch --claude-md -u'"
elif command -v rtk &>/dev/null; then
	log "RTK already installed ($(rtk --version 2>/dev/null || echo 'unknown version'))"
	rtk init -g --auto-patch --claude-md -u 2>/dev/null && log "RTK global config updated" || warn "rtk init -g had issues — check manually"
else
	info "Installing RTK (Rust Token Killer)..."
	if command -v brew &>/dev/null; then
		brew install rtk 2>/dev/null && log "RTK installed via Homebrew" || {
			warn "brew install failed — trying curl installer..."
			curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh && log "RTK installed via curl" || err "RTK installation failed — install manually: https://github.com/rtk-ai/rtk#installation"
		}
	elif command -v cargo &>/dev/null; then
		cargo install --git https://github.com/rtk-ai/rtk 2>/dev/null && log "RTK installed via cargo" || err "RTK installation failed — install manually: https://github.com/rtk-ai/rtk#installation"
	else
		curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh && log "RTK installed via curl" || err "RTK installation failed — install manually: https://github.com/rtk-ai/rtk#installation"
	fi
	if command -v rtk &>/dev/null; then
		rtk init -g --auto-patch --claude-md -u 2>/dev/null && log "RTK global config initialized" || warn "rtk init -g had issues — check manually"
	fi
fi

# ---------------------------------------------------------------------------
# 8. Agent Browser (optional) — browser automation for AI agents
# ---------------------------------------------------------------------------
step "Agent Browser (optional)..."
AGENT_BROWSER_SKILL_URL="https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md"

if $DRY_RUN; then
	info "Would ask to install agent-browser (optional)"
else
	INSTALL_AB=false
	if $YES_FLAG; then
		INSTALL_AB=true
	else
		echo ""
		echo -e "${CYAN}agent-browser${NC} provides browser automation for AI agents (navigate, click, fill forms, screenshots)."
		echo -n -e "  Install agent-browser? [y/N] "
		read -r AB_ANSWER
		case "$AB_ANSWER" in
		[yY] | [yY][eE][sS]) INSTALL_AB=true ;;
		*) INSTALL_AB=false ;;
		esac
	fi

	if $INSTALL_AB; then
		if ! command -v agent-browser &>/dev/null; then
			info "Installing agent-browser..."
			npm install -g agent-browser && log "agent-browser installed" || {
				err "agent-browser npm install failed — install manually: npm install -g agent-browser"
				INSTALL_AB=false
			}
		else
			log "agent-browser already installed"
		fi

		if $INSTALL_AB; then
			info "Running agent-browser install (downloads Chrome)..."
			agent-browser install 2>/dev/null && log "agent-browser Chrome installed" || warn "agent-browser install had issues — run 'agent-browser install' manually"

			# Download and install the skill
			mkdir -p "$SKILLS_DIR/agent-browser"
			if curl -fsSL "$AGENT_BROWSER_SKILL_URL" -o "$SKILLS_DIR/agent-browser/SKILL.md" 2>/dev/null; then
				manifest "CREATED" "~/.claude/skills/agent-browser/SKILL.md"
				manifest "CREATED_DIR" "~/.claude/skills/agent-browser"
				log "Downloaded agent-browser skill → ~/.claude/skills/agent-browser/SKILL.md"
			else
				warn "Failed to download agent-browser skill — download manually from:"
				info "$AGENT_BROWSER_SKILL_URL"
			fi
		fi
	else
		info "Skipping agent-browser"
	fi
fi

# ---------------------------------------------------------------------------
# 9. Summary
# ---------------------------------------------------------------------------
if $DRY_RUN; then
	echo ""
	box_top
	box_line "   Dry Run Complete -- no files were modified"
	box_bot
	echo ""
	info "Run without --dry-run to apply changes"
	echo ""
	exit 0
fi

echo ""
box_top
box_line "   Setup Complete -- v${KIT_VERSION} + Skills + Agents + Teams"
box_bot
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
echo -e "    ${DIM}~/.claude/agents/*.md  ($AGENT_COUNT agents)${NC}"
echo -e "    ${DIM}~/.claude/skills/*/SKILL.md  ($SKILL_COUNT skills)${NC}"
echo -e "    ${DIM}~/.claude/powerline.json${NC}"
echo ""
echo -e "  ${BOLD}Revert:${NC}"
echo -e "    ${YELLOW}./install.sh --revert${NC}  ${DIM}← removes kit files, restores backups${NC}"
echo -e "    ${DIM}Manifest: ~/.claude/.kit-manifest${NC}"
echo -e "    ${DIM}Backups:  ~/.claude/.kit-backup/${NC}"
echo ""
