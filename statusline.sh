#!/bin/bash
input=$(cat)

# ── Parse all fields in a single jq call ─────────────────────────────────
IFS=$'\t' read -r MODEL DIR COST PCT DURATION_MS \
	IN_TOK OUT_TOK CACHE_W CACHE_R <<< "$(
	echo "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.workspace.current_dir // "."),
    (.cost.total_cost_usd // 0 | tostring),
    (.context_window.used_percentage // 0 | floor | tostring),
    (.cost.total_duration_ms // 0 | floor | tostring),
    (.context_window.total_input_tokens // 0 | tostring),
    (.context_window.total_output_tokens // 0 | tostring),
    (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
    (.context_window.current_usage.cache_read_input_tokens // 0 | tostring)
  ] | join("\t")'
)"

# ── Token formatter (15234 -> 15.2k, 1823400 -> 1.8M) ──────────────────
fmt() {
	local n=$1
	if (( n >= 1000000 )); then
		printf '%d.%dM' $((n / 1000000)) $(( (n % 1000000) / 100000 ))
	elif (( n >= 1000 )); then
		printf '%d.%dk' $((n / 1000)) $(( (n % 1000) / 100 ))
	else
		printf '%d' "$n"
	fi
}

# ── Colors ───────────────────────────────────────────────────────────────
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'
RESET='\033[0m'

# ── Context bar (color by usage) ─────────────────────────────────────────
if [ "$PCT" -ge 90 ]; then
	BAR_COLOR="$RED"
elif [ "$PCT" -ge 70 ]; then
	BAR_COLOR="$YELLOW"
else BAR_COLOR="$GREEN"; fi

FILLED=$((PCT / 10))
EMPTY=$((10 - FILLED))
BAR=$(printf "%${FILLED}s" | tr ' ' '█')$(printf "%${EMPTY}s" | tr ' ' '░')

# ── Duration ─────────────────────────────────────────────────────────────
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))

# ── Git branch ───────────────────────────────────────────────────────────
BRANCH=""
git rev-parse --git-dir >/dev/null 2>&1 && BRANCH=" | \033[35m⎇ $(git branch --show-current 2>/dev/null)\033[0m"

# ── Format values ────────────────────────────────────────────────────────
COST_FMT=$(printf '$%.2f' "$COST")
IN_F=$(fmt "$IN_TOK")
OUT_F=$(fmt "$OUT_TOK")
CW_F=$(fmt "$CACHE_W")
CR_F=$(fmt "$CACHE_R")
TOTAL_F=$(fmt $((IN_TOK + OUT_TOK)))

# ── Render ───────────────────────────────────────────────────────────────
echo -e "  ${CYAN}[${MODEL}]${RESET} 📁 \033[94m${DIR##*/}${RESET}${BRANCH} | ${BAR_COLOR}${BAR}${RESET} ${PCT}% | ${YELLOW}${COST_FMT}${RESET} | ⏱️ ${DIM}${MINS}m ${SECS}s${RESET}"
echo -e "  ${DIM}in${RESET} ${IN_F} ${DIM}·${RESET} ${DIM}out${RESET} ${OUT_F} ${DIM}·${RESET} ${DIM}cached${RESET} ${CW_F} ${DIM}·${RESET} ${DIM}read${RESET} ${CR_F} ${DIM}·${RESET} ${DIM}total${RESET} ${TOTAL_F}"
