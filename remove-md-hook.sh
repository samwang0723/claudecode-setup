#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Remove Markdown Write Hook Limitation from everything-claude-code Plugin
# Removes the PreToolUse hook that blocks Write operations on .md/.txt files
#
# Usage: ./remove-md-hook.sh
# Environment: VERBOSE=1 for debug output
# Exit codes: 0 = success, 1 = jq not found
# ============================================================================

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

VERBOSE=${VERBOSE:-0}

log() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1"; }
info() { echo -e "${BLUE}[→]${NC} $1"; }
debug() { [ "$VERBOSE" -eq 1 ] && echo -e "${DIM}[DEBUG]${NC} $1" || true; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Remove Markdown Hook Limitation                            ║${NC}"
echo -e "${BOLD}║   everything-claude-code plugin                              ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if ! command -v jq &>/dev/null; then
	err "jq not found. Please install jq first."
	exit 1
fi
log "jq available"

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
CLAUDE_DIR="$HOME/.claude"
PLUGIN_CACHE_DIR="$CLAUDE_DIR/plugins/cache/everything-claude-code/everything-claude-code"
PLUGIN_MARKETPLACE_DIR="$CLAUDE_DIR/plugins/marketplaces/everything-claude-code"

MODIFIED_COUNT=0

# ---------------------------------------------------------------------------
# Function: Remove the Write matcher hook that blocks .md files
# Handles two possible structures:
# 1. Nested: .hooks.PreToolUse[] array (new structure)
# 2. Flat: .hooks[] array (legacy structure)
# ---------------------------------------------------------------------------
remove_md_hook() {
	local hooks_file="$1"
	local location_desc="$2"

	if [ ! -f "$hooks_file" ]; then
		info "Not found: $location_desc — skipping"
		return
	fi

	info "Processing: $location_desc"

	# Check if it has the md blocking pattern anywhere in JSON data
	if ! jq -e '.. | select(type == "string" and contains("Unnecessary documentation file creation"))' "$hooks_file" &>/dev/null; then
		info "  No md blocking hook found — skipping"
		return
	fi

	# Backup the original file (only after confirming modification is needed)
	cp "$hooks_file" "${hooks_file}.bak"
	warn "  Backed up: ${hooks_file}.bak"

	# Determine structure type
	local structure
	structure=$(jq -r '
		if .hooks.PreToolUse then "nested"
		elif (.hooks | type == "array") then "flat"
		else "unknown"
		end
	' "$hooks_file" 2>/dev/null)

	debug "Detected structure: $structure"

	# Create secure temp file
	local temp_file
	temp_file=$(mktemp "${hooks_file}.XXXXXX") || {
		err "  Failed to create temp file"
		rm -f "${hooks_file}.bak"
		return 1
	}

	# Apply the appropriate filter based on structure
	case "$structure" in
		nested)
			debug "Applying nested structure filter"
			jq '.hooks.PreToolUse = [
				.hooks.PreToolUse[] |
				select(
					.matcher != "Write" or
					([.hooks[]? | select(.command | contains("Unnecessary documentation file creation"))] | length == 0)
				)
			]' "${hooks_file}.bak" > "$temp_file"
			;;
		flat)
			debug "Applying flat structure filter"
			jq '.hooks = [
				.hooks[] |
				select(
					.matcher != "Write" or
					([.hooks[]? | select(.command | contains("Unnecessary documentation file creation"))] | length == 0)
				)
			]' "${hooks_file}.bak" > "$temp_file"
			;;
		*)
			warn "  Unknown hooks structure in: $location_desc — manual review needed"
			mv "${hooks_file}.bak" "$hooks_file"
			rm -f "$temp_file"
			return
			;;
	esac

	# Validate jq output before replacing original
	if [ -s "$temp_file" ] && jq empty "$temp_file" 2>/dev/null; then
		mv "$temp_file" "$hooks_file"
		log "  Removed md blocking hook ($structure structure) from: $location_desc"
		((MODIFIED_COUNT++)) || true
	else
		err "  jq processing failed — file unchanged"
		mv "${hooks_file}.bak" "$hooks_file"
		rm -f "$temp_file"
	fi
}

# ---------------------------------------------------------------------------
# 1. Process cache directory (version-agnostic)
# ---------------------------------------------------------------------------
echo ""
info "Checking plugin cache directory..."

if [ -d "$PLUGIN_CACHE_DIR" ]; then
	# Enable nullglob to handle empty directories
	shopt -s nullglob
	version_dirs=("$PLUGIN_CACHE_DIR"/*/)
	shopt -u nullglob

	if [ ${#version_dirs[@]} -eq 0 ]; then
		info "No version directories found in cache"
	else
		for version_dir in "${version_dirs[@]}"; do
			version="${version_dir%/}"
			version="${version##*/}"
			hooks_file="${version_dir}hooks/hooks.json"
			remove_md_hook "$hooks_file" "cache/$version/hooks/hooks.json"
		done
	fi
else
	info "Cache directory not found: $PLUGIN_CACHE_DIR"
fi

# ---------------------------------------------------------------------------
# 2. Process marketplace directory
# ---------------------------------------------------------------------------
echo ""
info "Checking plugin marketplace directory..."

MARKETPLACE_HOOKS="$PLUGIN_MARKETPLACE_DIR/hooks/hooks.json"
remove_md_hook "$MARKETPLACE_HOOKS" "marketplaces/everything-claude-code/hooks/hooks.json"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║   Complete                                                   ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$MODIFIED_COUNT" -gt 0 ]; then
	log "Modified $MODIFIED_COUNT hooks.json file(s)"
	echo ""
	echo -e "  ${BOLD}What was removed:${NC}"
	echo -e "    ${DIM}The Write hook that blocks creation of .md/.txt files${NC}"
	echo -e "    ${DIM}(except README, CLAUDE, AGENTS, CONTRIBUTING)${NC}"
	echo ""
	echo -e "  ${BOLD}Backups created:${NC}"
	echo -e "    ${DIM}Original files saved as hooks.json.bak${NC}"
	echo ""
	echo -e "  ${YELLOW}Note:${NC} Re-run this script after plugin updates (version changes)"
else
	warn "No hooks.json files were modified"
	echo ""
	echo -e "  ${DIM}Possible reasons:${NC}"
	echo -e "    ${DIM}• Plugin not installed${NC}"
	echo -e "    ${DIM}• Hook already removed${NC}"
	echo -e "    ${DIM}• Hook structure changed${NC}"
fi
echo ""
