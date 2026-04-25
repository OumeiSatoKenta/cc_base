# /add-feature 実行コマンド一覧

## 実行前の手動タスク

1. **Langfuse Cloud アカウント作成**: https://cloud.langfuse.com
2. **API キー設定**: `~/.claude/.env.langfuse` を作成
   ```
   LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxx
   LANGFUSE_SECRET_KEY=sk-lf-xxxxxxxx
   LANGFUSE_HOST=https://cloud.langfuse.com
   ```

## フェーズ1: MVP（上から順に実行）

### 1. メインスクリプト実装（F1〜F3）

```
/add-feature langfuse-logger-script
```

`.claude/hooks/langfuse-logger.sh` を新規作成する。以下の4つのイベントハンドラを含む単一スクリプト:

- **SessionStart**: `/tmp/claude-langfuse/{session_id}/` に状態ディレクトリ作成。`model`, `turn_count=0` を保存
- **PreToolUse**: アクティブトレースが無ければ `trace-create` で新規トレース作成（`turn-N` 命名）。`span-create` でツールスパン開始。`tool_use_id` をキーにスパンファイルを `spans/` に保存
- **PostToolUse**: `tool_use_id` で対応スパンを検索し `span-update`。`duration_ms` と `tool_response`（先頭1000文字に切り詰め）を送信
- **Stop**: `trace-update` でトレース終了。`stop_reason` をメタデータに含める。`trace_id` ファイル削除で次ターンに備える

共通機能:
- `~/.claude/.env.langfuse` から `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST` を読み込み。ファイル未存在なら即 `exit 0`
- `generate_uuid()`: bash `$RANDOM` で UUID v4 生成（uuidgen が devcontainer に無いため）
- `send_to_langfuse()`: `curl -s -X POST "${LANGFUSE_HOST}/api/public/ingestion"` を Basic 認証でバックグラウンド実行（`&`）、5秒タイムアウト
- `truncate_string()`: 文字列を指定長で切り詰め
- `get_input_summary()`: `tool_input` から `command`, `file_path`, `query` 等を抽出して要約
- stdout に JSON を出力しない（`permissionDecision` を返さない）、常に `exit 0`

対象ファイル: `.claude/hooks/langfuse-logger.sh`（新規）

### 2. フック登録 + gitignore + クレデンシャル管理（F4〜F5）

```
/add-feature langfuse-hook-registration
```

`.claude/settings.json` の `hooks` セクションに Langfuse ロガーを登録する:

- **PreToolUse**: 既存の `Bash`/`Read` マッチャーはそのまま保持。空マッチャー `""` で `langfuse-logger.sh` を追加（timeout: 10秒）
- **PostToolUse**: 空マッチャー `""` で `langfuse-logger.sh` を登録（新規セクション）
- **Stop**: 空マッチャー `""` で `langfuse-logger.sh` を登録（新規セクション）
- **SessionStart**: 空マッチャー `""` で `langfuse-logger.sh` を登録（新規セクション）

`.gitignore` に `.env.langfuse` エントリを追加（プロジェクトルートに誤作成した場合の保護）。

対象ファイル: `.claude/settings.json`（修正）, `.gitignore`（修正）

### 3. セットアップドキュメント

```
/add-feature langfuse-setup-docs
```

`docs/SETUP.md` に「Langfuse オブザーバビリティ（任意）」セクションを追加:

1. Langfuse Cloud Hobby プラン（無料）へのサインアップ手順
2. プロジェクト作成と API キー（Public Key / Secret Key）の取得方法
3. `~/.claude/.env.langfuse` ファイルの作成手順（3変数: `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST`）
4. Claude Code セッション再起動による反映
5. Langfuse ダッシュボードでのトレース確認方法
6. 無効化方法（`.env.langfuse` を削除またはリネーム）

対象ファイル: `docs/SETUP.md`（修正）

## フェーズ2: 拡張（MVP 完了後に必要に応じて）

### 4. ユーザープロンプト記録（F6）

```
/add-feature langfuse-user-prompt-tracking
```

`langfuse-logger.sh` に `handle_user_prompt_submit` ハンドラを追加。`UserPromptSubmit` イベントで受け取るユーザー入力テキストを、新規トレースの `input` フィールドに記録する。`settings.json` に `UserPromptSubmit` イベント登録を追加。

対象ファイル: `.claude/hooks/langfuse-logger.sh`（修正）, `.claude/settings.json`（修正）

### 5. サブエージェント追跡（F7）

```
/add-feature langfuse-subagent-tracking
```

`langfuse-logger.sh` に `handle_subagent_start` / `handle_subagent_stop` ハンドラを追加。サブエージェントを親スパンとして作成し、その配下のツール呼び出しを子スパンとしてネストする。`settings.json` に `SubagentStart` / `SubagentStop` イベント登録を追加。

対象ファイル: `.claude/hooks/langfuse-logger.sh`（修正）, `.claude/settings.json`（修正）

### 6. トランスクリプト解析 + トークンコスト（F8）

```
/add-feature langfuse-transcript-analysis
```

`handle_stop` ハンドラを拡張し、`transcript_path`（全イベントで渡される）から JSONL トランスクリプトを解析。assistant メッセージの `usage` フィールドから `input_tokens`, `output_tokens`, `cache_read_tokens`, `cache_creation_tokens` を抽出し、Langfuse `generation-create` として送信する。モデル別トークン単価テーブルでコスト計算を行い、`totalCost` フィールドに含める。

対象ファイル: `.claude/hooks/langfuse-logger.sh`（修正）

### 7. ステータスライン統合（F9）

```
/add-feature langfuse-statusline-integration
```

`.claude/statusline.sh` に Langfuse ダッシュボードの直リンク（`${LANGFUSE_HOST}/project/{project_id}/traces/{trace_id}`）を表示するセクションを追加。現在のセッションのトレースIDを `/tmp/claude-langfuse/{session_id}/trace_id` から読み取る。

対象ファイル: `.claude/statusline.sh`（修正）
