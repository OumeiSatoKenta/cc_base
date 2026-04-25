<!-- 生成日: 20260425 -->

# 開発ガイドライン (Development Guidelines)

## コーディング規約

### 言語: Bash

本プロジェクトのメイン実装は Bash スクリプト。以下の規約に従う。

#### 命名規則

```bash
# 関数: snake_case、動詞で始める
handle_session_start()
send_to_langfuse()
generate_uuid()
get_input_summary()

# 変数（ローカル）: UPPER_SNAKE_CASE
local TRACE_ID="..."
local SPAN_ID="..."

# 変数（グローバル/環境）: UPPER_SNAKE_CASE
LANGFUSE_PUBLIC_KEY="..."
SESSION_ID="..."
EVENT="..."

# ファイル名: kebab-case.sh
langfuse-logger.sh
guard-secrets.sh
```

#### スクリプト構造

```bash
#!/bin/bash
# 1行目: shebang
# ファイル冒頭にスクリプトの目的を書かない（CLAUDE.md のコメント規約に従う）

set -e

# --- 設定読み込み ---
# ... 

# --- 入力読み取り ---
# ...

# --- ヘルパー関数 ---
# ...

# --- イベントハンドラ ---
# ...

# --- ルーティング ---
case "$EVENT" in
  ...
esac

exit 0
```

#### エラーハンドリング方針

**原則**: すべてのエラーケースで `exit 0` を返す。Claude Code をブロックしない。

```bash
# 設定ファイルが無い → 即終了（エラーではない）
if [ ! -f "$ENV_FILE" ]; then
  exit 0
fi

# jq パース失敗 → 即終了
EVENT=$(echo "$INPUT" | jq -r '.hook_event_name // empty') || exit 0

# curl 失敗 → バックグラウンドなので影響なし
curl ... >/dev/null 2>&1 &
```

#### コメント規約

CLAUDE.md の方針に従い、デフォルトでコメントを書かない。WHY が非自明な場合のみ。

```bash
# ✅ OK: uuidgen が devcontainer に無いため bash で代替
generate_uuid() {
  printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x' \
    $RANDOM $RANDOM $RANDOM \
    $(( ($RANDOM & 0x0FFF) | 0x4000 )) \
    $(( ($RANDOM & 0x3FFF) | 0x8000 )) \
    $RANDOM $RANDOM $RANDOM
}

# ❌ NG: コードを読めば分かる
# 入力を読み取る
INPUT=$(cat)
```

### JSON 処理（jq）

```bash
# 複数フィールドを1回の jq で抽出（パイプチェーンを避ける）
read -r EVENT SESSION_ID TOOL_NAME <<< \
  "$(echo "$INPUT" | jq -r '[.hook_event_name, .session_id, .tool_name] | @tsv')"

# 出力用 JSON の組み立て
PAYLOAD=$(jq -n \
  --arg id "$SPAN_ID" \
  --arg traceId "$TRACE_ID" \
  --arg name "$TOOL_NAME" \
  '{batch: [{id: $id, type: "span-create", body: {id: $id, traceId: $traceId, name: $name}}]}')
```

## Git 運用ルール

### ブランチ戦略

```
main
  └─ feature/{YYYYMMDD}-{機能名}
```

- `main`: 安定版。PR マージでのみ更新
- `feature/{YYYYMMDD}-{機能名}`: 機能開発・バグ修正

**例**:
```
feature/20260425-langfuse-hooks
feature/20260425-add-transcript-analysis
```

### コミットメッセージ規約

Conventional Commits 形式（`validate-commit-message.sh` で検証済み）:

```
<type>(<scope>): <subject>
```

| Type | 用途 |
|------|------|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `docs` | ドキュメント |
| `chore` | ビルド・設定変更 |
| `refactor` | リファクタリング |

**例**:
```
feat(hooks): add Langfuse tracing logger
fix(hooks): handle missing trace_id in PostToolUse
docs(setup): add Langfuse configuration section
chore(settings): register Langfuse hook events
```

### プルリクエスト

`/ship-pr` スキルを使用。PR テンプレート:

```markdown
## Summary
- <変更内容を箇条書き>

## Test plan
- [ ] フック読み込み確認（/hooks）
- [ ] Langfuse ダッシュボードでトレース表示確認
- [ ] 既存ガードフック非干渉確認
- [ ] .env.langfuse 未設定時のグレースフルデグラデーション確認
```

## テスト戦略

### 主要テスト手段: 手動テスト

本プロジェクトは Bash スクリプトのため、自動テストフレームワークは使用しない。以下の手動テストで検証する。

#### 1. フック動作確認

```bash
# Claude Code セッション起動後
/hooks
# → langfuse-logger.sh が4イベントに登録されていること
```

#### 2. 状態ファイル確認

```bash
# ツール呼び出し後
ls -la /tmp/claude-langfuse/
# → session_id ディレクトリが存在すること
```

#### 3. Langfuse ダッシュボード確認

- https://cloud.langfuse.com でトレース・スパンの階層表示を目視確認

#### 4. スクリプト単体テスト

```bash
# イベント JSON を直接渡して動作確認
echo '{"hook_event_name":"SessionStart","session_id":"test-123","model":"claude-opus-4-6"}' | \
  bash .claude/hooks/langfuse-logger.sh
echo $?  # → 0

ls /tmp/claude-langfuse/test-123/
# → model, turn_count が存在
```

#### 5. グレースフルデグラデーション

```bash
# .env.langfuse を退避
mv ~/.claude/.env.langfuse ~/.claude/.env.langfuse.bak

# Claude Code で通常操作 → エラーが出ないことを確認

# 復元
mv ~/.claude/.env.langfuse.bak ~/.claude/.env.langfuse
```

## コードレビュー基準

### レビューポイント

**フック安全性**:
- [ ] stdout に JSON を出力していないか（`permissionDecision` を返さない）
- [ ] 常に `exit 0` で終了するか
- [ ] 既存ガードフックと干渉しないか

**セキュリティ**:
- [ ] API キーがリポジトリに含まれていないか
- [ ] `tool_response` が切り詰められているか
- [ ] `.gitignore` に `.env.langfuse` が含まれているか

**パフォーマンス**:
- [ ] curl がバックグラウンド実行されているか
- [ ] jq 呼び出しが最小限か
- [ ] 同期処理部分が 200ms 以内に収まるか

## 開発環境セットアップ

### 必要なツール

| ツール | バージョン | インストール方法 |
|--------|-----------|-----------------|
| bash | 5.x | devcontainer 標準 |
| jq | 1.6+ | devcontainer 標準 |
| curl | 7.x+ | devcontainer 標準 |
| Claude Code | latest | `install-tools.sh` |

### セットアップ手順

```bash
# 1. devcontainer を起動（VS Code）
#    → install-tools.sh が自動実行

# 2. Langfuse Cloud でアカウント作成
#    https://cloud.langfuse.com

# 3. API キー設定
cat > ~/.claude/.env.langfuse << 'EOF'
LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxx
LANGFUSE_SECRET_KEY=sk-lf-xxxxxxxx
LANGFUSE_HOST=https://cloud.langfuse.com
EOF

# 4. Claude Code セッション再起動
```

詳細は `docs/SETUP.md` を参照。
