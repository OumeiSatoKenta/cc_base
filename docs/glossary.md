<!-- 生成日: 20260425 -->

# プロジェクト用語集 (Glossary)

## 概要

このドキュメントは、Claude Code x Langfuse 連携プロジェクトで使用される用語の定義を管理します。

**更新日**: 2026-04-25

## ドメイン用語

### セッション (Session)

**定義**: Claude Code の1回の起動から終了までの単位

**説明**: `SessionStart` イベントで開始し、Claude Code プロセス終了で完了する。Langfuse 上では Session オブジェクトにマッピングされ、配下のトレースをグルーピングする。

**関連用語**: ターン, トレース

**英語表記**: Session

### ターン (Turn)

**定義**: 1回のユーザー入力に対する Claude の応答サイクル

**説明**: ユーザーがプロンプトを入力してから Claude が応答を完了（`Stop` イベント）するまでの一連の処理。1ターン内で複数のツール呼び出しが行われることがある。Langfuse 上では Trace にマッピングされる。

**関連用語**: セッション, スパン

**英語表記**: Turn

### フック (Hook)

**定義**: Claude Code のライフサイクルイベントに応じて実行されるシェルコマンド

**説明**: `settings.json` の `hooks` セクションで登録。イベント JSON を stdin で受け取り、任意の処理を実行する。本プロジェクトでは Langfuse へのトレース送信と、セキュリティガードの2種類のフックを運用。

**関連用語**: イベント, マッチャー

**英語表記**: Hook

### ガードフック (Guard Hook)

**定義**: 危険な操作をブロックするためのフック

**説明**: `guard-secrets.sh`, `guard-aws-cli.sh` 等。stdin の `tool_input` を検査し、ブロック時は `permissionDecision: deny` を stdout に出力する。Langfuse ロガーとは異なりブロッキング動作を行う。

**関連用語**: フック

**英語表記**: Guard Hook

### グレースフルデグラデーション (Graceful Degradation)

**定義**: Langfuse 設定が未構成でも Claude Code が通常通り動作すること

**説明**: `~/.claude/.env.langfuse` が存在しない場合、`langfuse-logger.sh` は即座に `exit 0` で終了する。エラーメッセージを出力せず、Claude Code の動作に一切影響を与えない。

**英語表記**: Graceful Degradation

## 技術用語

### Langfuse

**定義**: LLM アプリケーション向けのオブザーバビリティプラットフォーム

**本プロジェクトでの用途**: Claude Code のツール呼び出しをトレース・スパンとして記録し、ダッシュボードで可視化

**バージョン**: Cloud Hobby プラン（Ingestion API v1）

### Langfuse Ingestion API

**定義**: Langfuse にトレース・スパン・イベントを送信するための REST API

**本プロジェクトでの用途**: `curl` で `POST /api/public/ingestion` にバッチペイロードを送信

**認証**: Basic 認証（`LANGFUSE_PUBLIC_KEY:LANGFUSE_SECRET_KEY` を Base64 エンコード）

### Claude Code Hooks

**定義**: Claude Code が提供するイベント駆動のフックシステム

**本プロジェクトでの用途**: `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop` の4イベントで `langfuse-logger.sh` を実行

## 略語・頭字語

### OTel

**正式名称**: OpenTelemetry

**意味**: オブザーバビリティのためのオープンスタンダード（トレース・メトリクス・ログ）

**本プロジェクトでの使用**: 採用しない。Claude Code の OTel 出力はメトリクス/ログのみでトレース階層を出せないため、Hooks 方式を選択

### UUID

**正式名称**: Universally Unique Identifier

**意味**: 128ビットの一意識別子

**本プロジェクトでの使用**: トレースID・スパンIDの生成。`uuidgen` 未インストールのため bash `$RANDOM` で v4 UUID を生成

### MVP

**正式名称**: Minimum Viable Product

**意味**: 最小限の実用可能な製品

**本プロジェクトでの使用**: フェーズ1（SessionStart / PreToolUse / PostToolUse / Stop の4イベント対応）を MVP とし、トランスクリプト解析やサブエージェント追跡はフェーズ2

## アーキテクチャ用語

### イベント駆動パイプライン

**定義**: Claude Code のフックイベントをトリガーとして、一方向にデータを処理・送信するアーキテクチャ

**本プロジェクトでの適用**: Claude Code → stdin JSON → langfuse-logger.sh → curl POST → Langfuse Cloud

```
Claude Code ──stdin──▶ langfuse-logger.sh ──curl──▶ Langfuse API
                              │
                     /tmp/claude-langfuse/ （状態管理）
```

### Fire-and-Forget

**定義**: 結果を待たずにリクエストを送信するパターン

**本プロジェクトでの適用**: `curl ... &` でバックグラウンド実行し、レスポンスを確認しない。API 障害時でもスクリプトは正常終了する

## Langfuse データモデル用語

### トレース (Trace)

**定義**: Langfuse における1つの処理単位

**説明**: 本プロジェクトでは1ターン = 1トレース。`name` は `turn-1`, `turn-2` 等。`sessionId` でセッションに紐づく。

**主要フィールド**:
- `id`: UUID v4
- `sessionId`: Claude Code の session_id
- `name`: `turn-{N}`
- `metadata`: `{model, cwd, stop_reason}`

### スパン (Span)

**定義**: Langfuse における1つの操作の時間区間

**説明**: 本プロジェクトでは1ツール呼び出し = 1スパン。`PreToolUse` で作成、`PostToolUse` で完了。

**主要フィールド**:
- `id`: UUID v4
- `traceId`: 親トレースの ID
- `name`: ツール名（`Bash`, `Read`, `Edit` 等）
- `startTime` / `endTime`: ISO 8601
- `input`: ツール入力の要約
- `output`: ツール出力（先頭1000文字）

## フックイベント

| イベント名 | 発火タイミング | 主要フィールド |
|-----------|--------------|--------------|
| `SessionStart` | セッション開始時 | `session_id`, `model`, `source` |
| `PreToolUse` | ツール実行前 | `tool_name`, `tool_input`, `tool_use_id` |
| `PostToolUse` | ツール実行後 | `tool_name`, `tool_response`, `tool_use_id`, `duration_ms` |
| `Stop` | Claude 応答完了時 | `stop_reason` |
