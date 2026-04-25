# Claude Code x Langfuse 連携環境構築計画

## Context

Claude Code の利用状況（ツール呼び出し、セッション、ターン）を可視化・分析するため、LLM オブザーバビリティプラットフォーム Langfuse と連携する。2つの参考記事を調査した結果、**Hooks ベースのアプローチ**（Langfuse Ingestion API 直接送信）を採用する。

**なぜ Hooks 方式か:**
- OTel 方式は OTel Collector のインフラが必要、属性名変換が必要、サブエージェントのトレース伝搬が未対応
- Hooks 方式は既存プロジェクトのフックパターンに適合し、Langfuse Cloud API へ直接送信可能
- 既に5つのフックスクリプトが `.claude/hooks/` にあり、拡張が自然

**参考記事:**
- https://tubone-project24.xyz/2026/03/13/claude-code-langfuse-hooks-tracing/
- https://qiita.com/aoyagiry/items/96e5ccf11dfd7ddc318e

**Langfuse ホスティング:** Cloud Hobby プラン（無料）
- 月 50,000 ユニット、30日保持、2ユーザー、クレカ不要
- 個人開発用途なら十分（1セッション 50〜150 ユニット程度）

## 変更ファイル一覧

| ファイル | 操作 | 概要 |
|---------|------|------|
| `.claude/hooks/langfuse-logger.sh` | 新規 | Langfuse 送信スクリプト（メイン実装） |
| `.claude/settings.json` | 修正 | 4イベントにフック登録追加 |
| `docs/SETUP.md` | 修正 | Langfuse セットアップ手順追加 |
| `.gitignore` | 修正 | `.env.langfuse` エントリ追加 |

## 実装詳細

### 1. `.claude/hooks/langfuse-logger.sh`（新規 ~250行）

全フックイベントで同一スクリプトを呼び出し、内部で `hook_event_name` によりルーティング。

**入力JSON（stdin から読み取り）:**
- 全イベント共通: `session_id`, `transcript_path`, `cwd`, `hook_event_name`
- PreToolUse/PostToolUse: `tool_name`, `tool_input`, `tool_use_id`, `permission_mode`
- PostToolUse のみ: `tool_response`, `duration_ms`
- SessionStart のみ: `source`, `model`
- Stop のみ: `stop_reason`

**クレデンシャル:** `~/.claude/.env.langfuse` から読み込み（プロジェクト外、guard-secrets の対象外）
- ファイルが無ければ即座に `exit 0`（グレースフルデグラデーション）

**状態管理:** `/tmp/claude-langfuse/${SESSION_ID}/` に以下を保持
- `trace_id` - 現在のターンのトレースID
- `turn_count` - ターンカウンタ
- `model` - 使用モデル名
- `spans/` - ツール呼び出しごとのスパンファイル（tool_use_id.json）

**UUID生成:** `uuidgen` が未インストールのため bash の `$RANDOM` でv4 UUID を生成

**Langfuse API 送信:**
```bash
curl -s -X POST "${LANGFUSE_HOST}/api/public/ingestion" \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -d "$payload" \
  --max-time 5 \
  >/dev/null 2>&1 &
```
- バックグラウンド実行（`&`）で Claude Code をブロックしない
- 5秒タイムアウト
- stdout/stderr は `/dev/null` に捨てる

**イベントハンドラ:**

| イベント | Langfuse 操作 | 内容 |
|---------|--------------|------|
| `SessionStart` | なし（状態初期化のみ） | `model` を保存、`turn_count` を 0 に |
| `PreToolUse` | `trace-create` + `span-create` | アクティブトレースが無ければ新規作成。ツールスパンを開始 |
| `PostToolUse` | `span-update` | `duration_ms` と `tool_response`（先頭1000文字に切り詰め）でスパンを更新 |
| `Stop` | `trace-update` | トレースを終了、`stop_reason` をメタデータに。`trace_id` ファイル削除で次ターンへ |

**データモデルマッピング:**
```
Langfuse Session (= session_id)
  └─ Trace (= 1ターン / prompt-response サイクル)
       └─ Span (= 1ツール呼び出し、PreToolUse → PostToolUse)
```

**重要な制約:**
- stdout に JSON を出力しない（`permissionDecision` を返さない）
- 常に `exit 0` で終了（既存ガードフックと干渉しない）
- `tool_response` は巨大になりうるため先頭 1000 文字に切り詰め

### 2. `.claude/settings.json`（修正）

既存の `PreToolUse` フックはそのまま保持し、4つのイベントに Langfuse ロガーを追加。

```json
"hooks": {
  "PreToolUse": [
    { "matcher": "Bash", "hooks": [ /* 既存4つのガード */ ] },
    { "matcher": "Read", "hooks": [ /* 既存 guard-secrets-read */ ] },
    {
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/langfuse-logger.sh",
        "timeout": 10
      }]
    }
  ],
  "PostToolUse": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/langfuse-logger.sh",
      "timeout": 10
    }]
  }],
  "Stop": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/langfuse-logger.sh",
      "timeout": 10
    }]
  }],
  "SessionStart": [{
    "matcher": "",
    "hooks": [{
      "type": "command",
      "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/langfuse-logger.sh",
      "timeout": 10
    }]
  }]
}
```

### 3. `docs/SETUP.md`（修正）

「Langfuse オブザーバビリティ（任意）」セクションを追加:

1. https://cloud.langfuse.com でサインアップ（Hobby プラン / 無料）
2. プロジェクト作成 → API キー取得
3. `~/.claude/.env.langfuse` を作成:
   ```
   LANGFUSE_PUBLIC_KEY=pk-lf-xxxxxxxx
   LANGFUSE_SECRET_KEY=sk-lf-xxxxxxxx
   LANGFUSE_HOST=https://cloud.langfuse.com
   ```
4. Claude Code セッション再起動
5. ダッシュボードでトレース確認

### 4. `.gitignore`（修正）

```
.env.langfuse
```

## 実装順序

1. **`langfuse-logger.sh` 作成** - 全ハンドラを含むスクリプト
2. **`settings.json` 更新** - 4イベントのフック登録
3. **`docs/SETUP.md` 更新** - セットアップ手順
4. **`.gitignore` 更新** - `.env.langfuse` 追加

## 検証手順

1. **フック読み込み確認**: セッション再起動後、`/hooks` でイベント登録を確認
2. **既存フック非干渉**: `.env` 読み取りガード等が引き続き動作することを確認
3. **グレースフルデグラデーション**: `~/.claude/.env.langfuse` 無しでもエラーなく動作
4. **Langfuse ダッシュボード**: ツール呼び出しがトレース・スパンとして表示されること
5. **パフォーマンス**: curl がバックグラウンド実行で Claude Code の応答を遅延させないこと

## フェーズ2（将来拡張、今回スコープ外）

- `UserPromptSubmit` フック: ユーザープロンプトをトレース入力として記録
- `SubagentStart/Stop`: サブエージェントをネストスパンとして追跡
- トランスクリプト JSONL 解析: LLM Generation（トークン数・コスト）の追跡
- コスト計算: モデル別トークン単価による API コスト算出
- ステータスライン統合: Langfuse トレース URL を表示
