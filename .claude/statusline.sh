#!/bin/bash
# Claude Code Custom Statusline
# stdin: JSON with session data from Claude Code

input=$(cat)

# --- Extract values ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // "."')
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
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

# --- Context window bar with color thresholds ---
if [ "$PCT" -ge 80 ]; then
  BAR_COLOR="$RED"
elif [ "$PCT" -ge 50 ]; then
  BAR_COLOR="$YELLOW"
else
  BAR_COLOR="$GREEN"
fi

BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
if [ "$FILLED" -gt 0 ]; then
  printf -v FILL "%${FILLED}s"
  BAR="${FILL// /▓}"
fi
if [ "$EMPTY" -gt 0 ]; then
  printf -v PAD "%${EMPTY}s"
  BAR="${BAR}${PAD// /░}"
fi

# --- Rate limits ---
LIMITS=""
if [ -n "$FIVE_H" ]; then
  FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
  if [ "$FIVE_H_INT" -ge 80 ]; then
    FIVE_C="$RED"
  elif [ "$FIVE_H_INT" -ge 50 ]; then
    FIVE_C="$YELLOW"
  else
    FIVE_C="$GREEN"
  fi
  LIMITS="${DIM}5h:${RST}${FIVE_C}${FIVE_H_INT}%${RST}"
fi
if [ -n "$SEVEN_D" ]; then
  SEVEN_D_INT=$(printf '%.0f' "$SEVEN_D")
  if [ "$SEVEN_D_INT" -ge 80 ]; then
    SEVEN_C="$RED"
  elif [ "$SEVEN_D_INT" -ge 50 ]; then
    SEVEN_C="$YELLOW"
  else
    SEVEN_C="$GREEN"
  fi
  LIMITS="${LIMITS:+${LIMITS} }${DIM}7d:${RST}${SEVEN_C}${SEVEN_D_INT}%${RST}"
fi

# --- Git branch ---
BRANCH=""
if git -C "$CWD" rev-parse --git-dir > /dev/null 2>&1; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
fi

# --- Lines changed ---
LINES_INFO="${GREEN}+${ADDED}${RST} ${RED}-${REMOVED}${RST}"

# --- Build output ---
# Line 1: Model | Context bar | Rate limits
LINE1="${CYAN}${MODEL}${RST} ${BAR_COLOR}${BAR}${RST} ${PCT}%"
if [ -n "$LIMITS" ]; then
  LINE1="${LINE1} | ${LIMITS}"
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
