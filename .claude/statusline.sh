#!/bin/bash
# Claude Code Custom Statusline
# stdin: JSON with session data from Claude Code

input=$(cat)

# --- Extract values ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // "."')
PCT_RAW=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
if [[ "$PCT_RAW" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  PCT=$(printf '%.0f' "$PCT_RAW")
else
  PCT=0
fi
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
SEVEN_D=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
ADDED=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')

# --- Colors ---
RST='\033[0m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'

# --- Helper: get color by percentage ---
get_color() {
  local pct=$1
  if [ "$pct" -ge 80 ]; then
    echo "$RED"
  elif [ "$pct" -ge 50 ]; then
    echo "$YELLOW"
  else
    echo "$GREEN"
  fi
}

# --- Helper: make progress bar ---
make_bar() {
  local pct=$1
  local width=${2:-10}
  [ "$pct" -gt 100 ] 2>/dev/null && pct=100
  [ "$pct" -lt 0 ] 2>/dev/null && pct=0
  local filled=$((pct * width / 100))
  local empty=$((width - filled))
  local bar=""
  if [ "$filled" -gt 0 ]; then
    printf -v fill "%${filled}s"
    bar="${fill// /▓}"
  fi
  if [ "$empty" -gt 0 ]; then
    printf -v pad "%${empty}s"
    bar="${bar}${pad// /░}"
  fi
  echo "$bar"
}

# --- Rate limit bars (left side) ---
RATE_SECTION=""
if [ -n "$FIVE_H" ] && [[ "$FIVE_H" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
  FIVE_COLOR=$(get_color "$FIVE_H_INT")
  FIVE_BAR=$(make_bar "$FIVE_H_INT")
  RATE_SECTION="${DIM}5h${RST} ${FIVE_COLOR}${FIVE_BAR}${RST} ${FIVE_COLOR}${FIVE_H_INT}%${RST}"
fi
if [ -n "$SEVEN_D" ] && [[ "$SEVEN_D" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  SEVEN_D_INT=$(printf '%.0f' "$SEVEN_D")
  SEVEN_COLOR=$(get_color "$SEVEN_D_INT")
  SEVEN_BAR=$(make_bar "$SEVEN_D_INT")
  RATE_SECTION="${RATE_SECTION:+${RATE_SECTION} }${DIM}7d${RST} ${SEVEN_COLOR}${SEVEN_BAR}${RST} ${SEVEN_COLOR}${SEVEN_D_INT}%${RST}"
fi

# --- Context window bar (right side) ---
CTX_COLOR=$(get_color "$PCT")
CTX_BAR=$(make_bar "$PCT")
CTX_SECTION="${DIM}ctx${RST} ${CTX_COLOR}${CTX_BAR}${RST} ${CTX_COLOR}${PCT}%${RST}"

# --- Sanitize external inputs (strip escape sequences) ---
MODEL=$(printf '%s' "$MODEL" | sed 's/\\//g' | tr -d '\033')

# --- Git branch ---
BRANCH=""
if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
  BRANCH=$(printf '%s' "$BRANCH" | sed 's/\\//g' | tr -d '\033')
fi

# --- Lines changed ---
LINES_INFO="${GREEN}+${ADDED}${RST} ${RED}-${REMOVED}${RST}"

# --- Build output ---
# Line 1: Model | Rate bars (left) | Context bar (right)
LINE1="${CYAN}${MODEL}${RST}"
if [ -n "$RATE_SECTION" ]; then
  LINE1="${LINE1} ${RATE_SECTION} | ${CTX_SECTION}"
else
  LINE1="${LINE1} ${CTX_SECTION}"
fi

# Line 2: Git branch | Lines changed
LINE2=""
if [ -n "$BRANCH" ]; then
  LINE2="${DIM}branch:${RST}${YELLOW}${BRANCH}${RST} | ${LINES_INFO}"
else
  LINE2="${LINES_INFO}"
fi

printf '%b\n' "$LINE1"
printf '%b\n' "$LINE2"
