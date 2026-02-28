#!/bin/bash
# Claude Code PreToolUse hook: git commit メッセージのバリデーション
#
# チェック内容:
# 1. サブジェクト行（1行目）が空でないこと
# 2. サブジェクト行が72文字以内であること
# 3. 本文がある場合、サブジェクト行と本文の間に空行があること
#
# stdin: Claude Code から渡される JSON (tool_input.command を含む)
# stdout: permissionDecision を含む JSON
# exit 0: 正常終了（JSON出力で allow/deny を制御）

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# コマンドが空ならスキップ
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# git commit コマンドかどうか判定
# コマンドの先頭、または && / ; の後に git commit がある場合のみ対象
# パイプ先やecho/文字列内のgit commitは無視する
IS_GIT_COMMIT=false
if echo "$COMMAND" | grep -qE '(^|&&|;)[[:space:]]*git[[:space:]]+commit[[:space:]]+-m'; then
  IS_GIT_COMMIT=true
fi

if [[ "$IS_GIT_COMMIT" != "true" ]]; then
  exit 0
fi

# --- コミットメッセージの抽出 ---

MESSAGE=""

# パターン1: HEREDOC 形式 $(cat <<'EOF' ... EOF)
# ship-pr スキルが使用する形式
if echo "$COMMAND" | grep -q "cat <<"; then
  MESSAGE=$(echo "$COMMAND" | sed -n "/cat <<.*EOF/,/^EOF/{
    /cat <<.*EOF/d
    /^EOF/d
    p
  }")
fi

# パターン2: 通常の -m "message" または -m 'message' 形式
if [[ -z "$MESSAGE" ]]; then
  # ダブルクォート: git commit -m "message" を抽出
  MESSAGE=$(echo "$COMMAND" | sed -n 's/.*git[[:space:]]\+commit[[:space:]]\+.*-m[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi
if [[ -z "$MESSAGE" ]]; then
  # シングルクォート: git commit -m 'message' を抽出
  MESSAGE=$(echo "$COMMAND" | sed -n "s/.*git[[:space:]]\+commit[[:space:]]\+.*-m[[:space:]]*'\([^']*\)'.*/\1/p" | head -1)
fi

# メッセージが抽出できなければスキップ
if [[ -z "$MESSAGE" ]]; then
  exit 0
fi

# --- バリデーション ---

# サブジェクト行（1行目）を取得
SUBJECT=$(echo "$MESSAGE" | head -n 1)

ERRORS=()

# チェック1: サブジェクト行が空でないこと
if [[ -z "$SUBJECT" || "$SUBJECT" =~ ^[[:space:]]*$ ]]; then
  ERRORS+=("サブジェクト行（1行目）が空です")
fi

# チェック2: サブジェクト行が72文字以内であること
SUBJECT_LEN=${#SUBJECT}
if [[ $SUBJECT_LEN -gt 72 ]]; then
  ERRORS+=("サブジェクト行が長すぎます（${SUBJECT_LEN}文字 / 上限72文字）")
fi

# チェック3: 本文がある場合、2行目が空行であること（git の慣例）
LINE_COUNT=$(echo "$MESSAGE" | wc -l)
if [[ $LINE_COUNT -gt 1 ]]; then
  SECOND_LINE=$(echo "$MESSAGE" | sed -n '2p')
  if [[ -n "$SECOND_LINE" && ! "$SECOND_LINE" =~ ^[[:space:]]*$ ]]; then
    ERRORS+=("サブジェクト行と本文の間に空行が必要です（2行目が空でありません）")
  fi
fi

# --- 結果出力 ---

# バリデーション通過
if [[ ${#ERRORS[@]} -eq 0 ]]; then
  exit 0
fi

# バリデーション失敗 — deny で Claude にフィードバック
REASON=$(printf '%s\n' "${ERRORS[@]}" | jq -Rs '.')

jq -n \
  --argjson reason "$REASON" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'

exit 0
