<!-- 生成日: 20260425 -->

# 技術仕様書 (Architecture Design Document)

## テクノロジースタック

### 言語・ランタイム

| 技術 | バージョン |
|------|-----------|
| Bash | 5.x（devcontainer 標準） |
| jq | 1.6+（devcontainer 標準） |
| curl | 7.x+（devcontainer 標準） |

### 外部サービス

| 技術 | 用途 | 選定理由 |
|------|------|----------|
| Langfuse Cloud | オブザーバビリティ | Hobby プラン無料、Ingestion API でトレース送信 |
| Claude Code Hooks | イベントソース | 組込みフックシステム、stdin で JSON を受信 |

### 開発ツール

| 技術 | バージョン | 用途 | 選定理由 |
|------|-----------|------|----------|
| devcontainer | - | 開発環境 | 全ツールがプリインストール済み |
| Claude Code | latest | AI コーディング | フック対象のランタイム |

## アーキテクチャパターン

### イベント駆動パイプライン

```
┌──────────────────────────────────────────────────────┐
│ Claude Code Runtime                                  │
│                                                      │
│  SessionStart / PreToolUse / PostToolUse / Stop       │
│         │                                            │
│         ▼ stdin (JSON)                               │
│  ┌──────────────────────────────────────────┐        │
│  │ langfuse-logger.sh                       │        │
│  │                                          │        │
│  │  [設定読込] → [入力パース] → [ルーティング]  │        │
│  │       │            │              │       │        │
│  │       ▼            ▼              ▼       │        │
│  │  .env.langfuse   jq parse    case 文     │        │
│  │                                  │       │        │
│  │              ┌───────────────────┤       │        │
│  │              ▼                   ▼       │        │
│  │        [状態管理]          [API 送信]     │        │
│  │     /tmp/claude-langfuse/  curl &        │        │
│  └──────────────────────────────────────────┘        │
│         │                                            │
│         ▼ exit 0（常に成功）                           │
│  Claude Code は通常通り動作                             │
└──────────────────────────────────────────────────────┘
          │
          ▼ HTTPS POST (async)
┌──────────────────────┐
│ Langfuse Cloud       │
│ /api/public/ingestion│
│                      │
│ Session > Trace > Span│
└──────────────────────┘
```

**特徴**:
- 単方向パイプライン（Claude Code → Hook → Langfuse）
- フックは副作用なし（stdout に JSON を出さない、exit 0 固定）
- API 送信は fire-and-forget（バックグラウンド curl）

## データ永続化戦略

### ストレージ方式

| データ種別 | ストレージ | フォーマット | ライフサイクル |
|-----------|----------|-------------|-------------|
| セッション状態 | `/tmp/claude-langfuse/{session_id}/` | テキストファイル | セッション終了 or OS 再起動で消滅 |
| トレースデータ | Langfuse Cloud | Langfuse 内部 DB | 30日保持（Hobby プラン） |
| API クレデンシャル | `~/.claude/.env.langfuse` | shell 変数 | ユーザーが手動管理 |

### バックアップ戦略

バックアップ不要。状態ファイルは一時的で再生成可能。トレースデータは Langfuse Cloud が管理。

## パフォーマンス要件

### レスポンスタイム

| 操作 | 目標時間 | 測定環境 |
|------|---------|---------|
| スクリプト同期処理（stdin 読取〜curl 発行） | 200ms 以内 | devcontainer |
| Langfuse API 送信（非同期） | 5 秒タイムアウト | バックグラウンド |

### リソース使用量

| リソース | 上限 | 理由 |
|---------|------|------|
| メモリ | ~10MB | bash + jq + curl のプロセスメモリ |
| ディスク | ~1MB | 状態ファイルはセッションあたり数KB |
| ネットワーク | ~数KB/リクエスト | JSON ペイロードは小さい |

## セキュリティアーキテクチャ

### データ保護

- **API キー**: `~/.claude/.env.langfuse` に保存（プロジェクト外）。`guard-secrets-read.sh` の `.env.*` パターンで Read ツールからも保護
- **リポジトリ保護**: `.gitignore` に `.env.langfuse` を追加
- **送信データ制限**: `tool_response` を先頭 1000 文字に切り詰め

### 入力検証

- **stdin JSON**: jq パース失敗時は `exit 0`（エラーを無視）
- **必須フィールド**: `hook_event_name`, `session_id` が空なら `exit 0`
- **ディレクトリトラバーサル**: `session_id` は Langfuse が生成する UUID 形式。追加のサニタイズは不要（`mkdir -p` でパス区切り文字は問題にならない）

## スケーラビリティ設計

### データ増加への対応

- **Langfuse Hobby プラン**: 月 50,000 ユニット。1セッション 50〜150 ユニットとして月 300〜1,000 セッションに対応
- **状態ファイル**: セッション終了時にクリーンアップ可能。`/tmp/` は OS 再起動で自動消去
- **ペイロードサイズ**: `tool_response` 切り詰めで 1 リクエストあたり数 KB に抑制

### 機能拡張性

- **フェーズ2 拡張ポイント**: `handle_stop` 内にトランスクリプト JSONL 解析を追加可能（`transcript_path` が全イベントで渡される）
- **新規イベント追加**: `case` 文に新しいハンドラを追加するだけ
- **メタデータ拡充**: `trace-update` / `span-update` の `metadata` フィールドで任意の情報を付加可能

## テスト戦略

### 手動テスト（主要）

- Claude Code セッションで実際にツールを呼び、Langfuse ダッシュボードを確認
- `~/.claude/.env.langfuse` 削除時にエラーが出ないことを確認

### スクリプト単体テスト

```bash
# イベント JSON を stdin に渡してスクリプトを実行
echo '{"hook_event_name":"SessionStart","session_id":"test","model":"opus"}' | \
  bash .claude/hooks/langfuse-logger.sh
echo $?  # 0 であること
ls /tmp/claude-langfuse/test/  # model, turn_count が存在すること
```

### 非干渉テスト

- 既存ガードフック 5 本のテスト: `.env` 読み取りブロック、`terraform destroy` ブロック、AWS 書込みブロック

## 技術的制約

### 環境要件
- **OS**: Linux（devcontainer: Debian Bookworm）
- **必須コマンド**: `bash`, `jq`, `curl`（全て devcontainer にプリインストール済み）
- **ネットワーク**: Langfuse Cloud（`https://cloud.langfuse.com`）への HTTPS アクセス

### パフォーマンス制約
- Claude Code のフックタイムアウト: 10 秒（`settings.json` で設定）
- Langfuse Ingestion API レートリミット: 1,000 req/min（Hobby プラン）

### セキュリティ制約
- `tool_response` にソースコードや機密情報が含まれる可能性あり → 1000 文字切り詰めで軽減
- Langfuse Cloud にデータが送信される → ユーザーが opt-in（`.env.langfuse` 作成）で明示的に許可

## 依存関係管理

| ツール | 用途 | バージョン管理方針 |
|-------|------|-------------------|
| bash | スクリプト実行 | OS 標準 |
| jq | JSON パース | OS 標準 |
| curl | HTTP リクエスト | OS 標準 |
| Langfuse API | トレース送信 | v1 Ingestion API（安定） |

外部ライブラリ・npm パッケージへの依存なし。
