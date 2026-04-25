#!/bin/bash

set -e
trap 'exit 0' ERR
umask 077

# --- 設定読み込み ---

ENV_FILE="${HOME}/.claude/.env.langfuse"
if [ ! -f "$ENV_FILE" ]; then
  exit 0
fi

LANGFUSE_PUBLIC_KEY=$(grep -m1 '^LANGFUSE_PUBLIC_KEY=' "$ENV_FILE" | cut -d= -f2-) || true
LANGFUSE_SECRET_KEY=$(grep -m1 '^LANGFUSE_SECRET_KEY=' "$ENV_FILE" | cut -d= -f2-) || true
LANGFUSE_HOST=$(grep -m1 '^LANGFUSE_HOST=' "$ENV_FILE" | cut -d= -f2-) || true

if [ -z "$LANGFUSE_PUBLIC_KEY" ] || [ -z "$LANGFUSE_SECRET_KEY" ] || [ -z "$LANGFUSE_HOST" ]; then
  exit 0
fi

AUTH=$(printf '%s:%s' "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" | base64 | tr -d '\n')

# --- 入力読み取り ---

INPUT=$(cat) || exit 0

IFS=$'\t' read -r EVENT SESSION_ID TOOL_NAME TOOL_USE_ID CWD <<< \
  "$(echo "$INPUT" | jq -r '[.hook_event_name // "", .session_id // "", .tool_name // "", .tool_use_id // "", .cwd // ""] | @tsv')" || exit 0

if [ -z "$EVENT" ] || [ -z "$SESSION_ID" ]; then
  exit 0
fi

SESSION_ID="${SESSION_ID//[^a-zA-Z0-9\-]/}"
TOOL_USE_ID="${TOOL_USE_ID//[^a-zA-Z0-9\-_]/}"

mkdir -m 700 -p "/tmp/claude-langfuse" 2>/dev/null || true
STATE_DIR="/tmp/claude-langfuse/${SESSION_ID}"

# --- ヘルパー関数 ---

# uuidgen が devcontainer に無いため bash $RANDOM で代替
generate_uuid() {
  printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x' \
    $RANDOM $RANDOM $RANDOM \
    $(( ($RANDOM & 0x0FFF) | 0x4000 )) \
    $(( ($RANDOM & 0x3FFF) | 0x8000 )) \
    $RANDOM $RANDOM $RANDOM
}

send_to_langfuse() {
  local PAYLOAD="$1"
  echo "$PAYLOAD" | curl -s -X POST "${LANGFUSE_HOST}/api/public/ingestion" \
    -H "Authorization: Basic ${AUTH}" \
    -H "Content-Type: application/json" \
    -d @- \
    --max-time 5 \
    >/dev/null 2>&1 &
}

truncate_string() {
  local STR="$1"
  local MAX_LEN="${2:-1000}"
  if [ "${#STR}" -gt "$MAX_LEN" ]; then
    echo "${STR:0:$MAX_LEN}..."
  else
    echo "$STR"
  fi
}

get_input_summary() {
  local TOOL_INPUT="$1"
  local SUMMARY=""

  SUMMARY=$(echo "$TOOL_INPUT" | jq -r '
    if .command then "command: " + (.command | tostring | .[0:200])
    elif .file_path then "file_path: " + (.file_path | tostring)
    elif .query then "query: " + (.query | tostring | .[0:200])
    elif .prompt then "prompt: " + (.prompt | tostring | .[0:200])
    elif .skill then "skill: " + (.skill | tostring)
    elif .content then "content: " + (.content | tostring | .[0:200])
    else (tostring | .[0:200])
    end
  ' 2>/dev/null) || SUMMARY="(parse error)"

  echo "$SUMMARY"
}

# --- イベントハンドラ ---

# API送信はPreToolUseで遅延実行（トレースをツール到着時に作成する設計）
handle_session_start() {
  mkdir -p "${STATE_DIR}/spans"

  local MODEL
  MODEL=$(echo "$INPUT" | jq -r '.model // "unknown"') || MODEL="unknown"

  echo "$MODEL" > "${STATE_DIR}/model"
  echo "0" > "${STATE_DIR}/turn_count"
}

handle_pre_tool_use() {
  [ -z "$TOOL_USE_ID" ] && exit 0
  mkdir -p "${STATE_DIR}/spans"

  local TRACE_ID=""
  if [ -f "${STATE_DIR}/trace_id" ]; then
    TRACE_ID=$(cat "${STATE_DIR}/trace_id")
  fi

  local NOW
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  if [ -z "$TRACE_ID" ]; then
    TRACE_ID=$(generate_uuid)
    echo "$TRACE_ID" > "${STATE_DIR}/trace_id"

    local TURN_COUNT=0
    if [ -f "${STATE_DIR}/turn_count" ]; then
      TURN_COUNT=$(cat "${STATE_DIR}/turn_count")
    fi
    TURN_COUNT=$((TURN_COUNT + 1))
    echo "$TURN_COUNT" > "${STATE_DIR}/turn_count"

    local MODEL="unknown"
    if [ -f "${STATE_DIR}/model" ]; then
      MODEL=$(cat "${STATE_DIR}/model")
    fi

    local TRACE_EVENT_ID
    TRACE_EVENT_ID=$(generate_uuid)

    local TRACE_PAYLOAD
    TRACE_PAYLOAD=$(jq -n \
      --arg eventId "$TRACE_EVENT_ID" \
      --arg ts "$NOW" \
      --arg traceId "$TRACE_ID" \
      --arg sessionId "$SESSION_ID" \
      --arg name "turn-${TURN_COUNT}" \
      --arg model "$MODEL" \
      --arg cwd "$CWD" \
      '{batch: [{id: $eventId, type: "trace-create", timestamp: $ts, body: {id: $traceId, sessionId: $sessionId, name: $name, metadata: {model: $model, cwd: $cwd}}}]}')

    send_to_langfuse "$TRACE_PAYLOAD"
  fi

  local SPAN_ID
  SPAN_ID=$(generate_uuid)

  local INPUT_SUMMARY
  INPUT_SUMMARY=$(echo "$INPUT" | jq -c '.tool_input // {}' 2>/dev/null) || INPUT_SUMMARY="{}"
  INPUT_SUMMARY=$(get_input_summary "$INPUT_SUMMARY")

  echo "${SPAN_ID}|${NOW}" > "${STATE_DIR}/spans/${TOOL_USE_ID}"

  local SPAN_EVENT_ID
  SPAN_EVENT_ID=$(generate_uuid)

  local SPAN_PAYLOAD
  SPAN_PAYLOAD=$(jq -n \
    --arg eventId "$SPAN_EVENT_ID" \
    --arg ts "$NOW" \
    --arg spanId "$SPAN_ID" \
    --arg traceId "$TRACE_ID" \
    --arg name "${TOOL_NAME:-unknown}" \
    --arg startTime "$NOW" \
    --arg input "$INPUT_SUMMARY" \
    --arg toolUseId "${TOOL_USE_ID:-}" \
    '{batch: [{id: $eventId, type: "span-create", timestamp: $ts, body: {id: $spanId, traceId: $traceId, name: $name, startTime: $startTime, input: {summary: $input}, metadata: {tool_use_id: $toolUseId}}}]}')

  send_to_langfuse "$SPAN_PAYLOAD"
}

handle_post_tool_use() {
  [ -z "$TOOL_USE_ID" ] && exit 0
  local SPAN_FILE="${STATE_DIR}/spans/${TOOL_USE_ID}"

  if [ ! -f "$SPAN_FILE" ]; then
    exit 0
  fi

  local SPAN_DATA
  SPAN_DATA=$(cat "$SPAN_FILE")

  local SPAN_ID="${SPAN_DATA%%|*}"
  local START_TIME="${SPAN_DATA#*|}"

  local NOW
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  local DURATION_MS
  DURATION_MS=$(echo "$INPUT" | jq -r '.duration_ms // 0' 2>/dev/null) || DURATION_MS=0
  DURATION_MS=$(( ${DURATION_MS:-0} + 0 )) 2>/dev/null || DURATION_MS=0

  local TOOL_RESPONSE_RAW
  TOOL_RESPONSE_RAW=$(echo "$INPUT" | jq -r '.tool_response // "" | tostring' 2>/dev/null) || TOOL_RESPONSE_RAW=""

  local TOOL_RESPONSE_TRUNCATED
  TOOL_RESPONSE_TRUNCATED=$(truncate_string "$TOOL_RESPONSE_RAW" 1000)

  local TRACE_ID=""
  if [ -f "${STATE_DIR}/trace_id" ]; then
    TRACE_ID=$(cat "${STATE_DIR}/trace_id")
  fi

  local SPAN_EVENT_ID
  SPAN_EVENT_ID=$(generate_uuid)

  local SPAN_PAYLOAD
  SPAN_PAYLOAD=$(jq -n \
    --arg eventId "$SPAN_EVENT_ID" \
    --arg ts "$NOW" \
    --arg spanId "$SPAN_ID" \
    --arg traceId "${TRACE_ID:-}" \
    --arg endTime "$NOW" \
    --arg output "$TOOL_RESPONSE_TRUNCATED" \
    --argjson durationMs "${DURATION_MS:-0}" \
    --arg toolUseId "${TOOL_USE_ID:-}" \
    '{batch: [{id: $eventId, type: "span-update", timestamp: $ts, body: {id: $spanId, traceId: $traceId, endTime: $endTime, output: {response: $output}, metadata: {tool_use_id: $toolUseId, duration_ms: $durationMs}}}]}')

  send_to_langfuse "$SPAN_PAYLOAD"

  rm -f "$SPAN_FILE"
}

handle_stop() {
  if [ ! -f "${STATE_DIR}/trace_id" ]; then
    exit 0
  fi

  local TRACE_ID
  TRACE_ID=$(cat "${STATE_DIR}/trace_id")

  local NOW
  NOW=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  local STOP_REASON
  STOP_REASON=$(echo "$INPUT" | jq -r '.stop_reason // "unknown"' 2>/dev/null) || STOP_REASON="unknown"

  local TRACE_EVENT_ID
  TRACE_EVENT_ID=$(generate_uuid)

  local TRACE_PAYLOAD
  TRACE_PAYLOAD=$(jq -n \
    --arg eventId "$TRACE_EVENT_ID" \
    --arg ts "$NOW" \
    --arg traceId "$TRACE_ID" \
    --arg stopReason "$STOP_REASON" \
    '{batch: [{id: $eventId, type: "trace-update", timestamp: $ts, body: {id: $traceId, metadata: {stop_reason: $stopReason}}}]}')

  send_to_langfuse "$TRACE_PAYLOAD"

  rm -f "${STATE_DIR}/trace_id"
}

# --- ルーティング ---

case "$EVENT" in
  SessionStart) handle_session_start ;;
  PreToolUse) handle_pre_tool_use ;;
  PostToolUse) handle_post_tool_use ;;
  Stop) handle_stop ;;
  *) ;;
esac

exit 0
