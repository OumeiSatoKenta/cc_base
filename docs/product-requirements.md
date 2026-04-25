<!-- 生成日: 20260425 -->

# プロダクト要求定義書 (Product Requirements Document)

## プロダクト概要

### 名称
**Claude Code Langfuse Hooks** - Claude Code セッションの Langfuse オブザーバビリティ連携

### プロダクトコンセプト
- **Hooks ベーストレーシング**: Claude Code の既存フックシステムを活用し、追加インフラなしで Langfuse にテレメトリを送信
- **グレースフルデグラデーション**: Langfuse 設定がなくても Claude Code の動作に一切影響を与えない
- **ゼロコスト運用**: Langfuse Cloud Hobby プラン（無料）で個人開発の可視化を完結

### プロダクトビジョン
Claude Code を使った開発作業の「見える化」を実現する。セッションごとのツール利用パターン、ターン数、実行時間をLangfuse ダッシュボードで振り返り可能にすることで、開発プロセスの理解と改善を支援する。設定は最小限、既存のガードフックとの共存を保証し、開発体験を損なわない。

### 目的
- Claude Code のツール呼び出し（Bash, Read, Edit, Write, Agent 等）をトレースとして記録する
- セッション → ターン → ツール呼び出しの階層構造で可視化する
- 既存の devcontainer 環境にシームレスに統合する

## ターゲットユーザー

### プライマリーペルソナ: 佐藤健太（エンジニア）
- Claude Code を日常的に使い、devcontainer ベースのプロジェクトテンプレートを運用
- 自分の Claude Code 利用パターン（どのツールをどれだけ使っているか）を把握したい
- Langfuse 等のオブザーバビリティツールに興味があるが、インフラ構築に時間をかけたくない
- 設定ファイルを数行書くだけで動き始める手軽さを求める
- 典型的なワークフロー: devcontainer 起動 → Claude Code で開発 → 振り返り時に Langfuse ダッシュボード確認

## 成功指標（KPI）

### プライマリーKPI
- フック実行成功率: 99%以上（エラーで Claude Code がブロックされない）
- Langfuse ダッシュボードにトレースが表示される: セッション開始から初回トレース表示まで1分以内

### セカンダリーKPI
- フックスクリプト実行時間: 200ms 以内（curl バックグラウンド実行前の同期部分）
- 既存ガードフック（guard-secrets, guard-aws-cli 等）への影響: ゼロ（回帰なし）

## 機能要件

### コア機能（MVP）

#### F1: セッション状態管理

**ユーザーストーリー**:
開発者として、Claude Code セッションの開始を自動検知し、Langfuse 上でセッション単位でトレースをグルーピングしたい

**受け入れ条件**:
- [ ] `SessionStart` フックで `/tmp/claude-langfuse/{session_id}/` に状態ディレクトリを作成する
- [ ] `model` と `turn_count`（初期値 0）を状態ファイルに保存する
- [ ] `~/.claude/.env.langfuse` が存在しない場合、即座に `exit 0` で終了する

**優先度**: P0（必須）

#### F2: ツール呼び出しトレーシング

**ユーザーストーリー**:
開発者として、各ツール呼び出し（Bash, Read, Edit 等）の開始・終了・所要時間を Langfuse のスパンとして記録したい

**受け入れ条件**:
- [ ] `PreToolUse` で Langfuse にスパン作成リクエストを送信する
- [ ] アクティブなトレースがなければ新規トレースを作成し、`trace_id` を状態ファイルに保存する
- [ ] `PostToolUse` で対応するスパンを `duration_ms` と `tool_response`（先頭1000文字）で更新する
- [ ] `tool_use_id` でスパンの Pre/Post を正確にペアリングする
- [ ] Langfuse ダッシュボードでスパンが `Session > Trace > Span` の階層で表示される

**優先度**: P0（必須）

#### F3: ターン終了処理

**ユーザーストーリー**:
開発者として、Claude Code の応答完了時にトレースが適切に終了し、次のターンに備えた状態リセットが行われてほしい

**受け入れ条件**:
- [ ] `Stop` イベントでトレースを `trace-update` で終了する
- [ ] `stop_reason` をトレースのメタデータに含める
- [ ] `trace_id` 状態ファイルを削除し、次ターンで新規トレースが作成されるようにする

**優先度**: P0（必須）

#### F4: クレデンシャル管理

**ユーザーストーリー**:
開発者として、Langfuse API キーを安全に管理し、リポジトリにコミットされないようにしたい

**受け入れ条件**:
- [ ] クレデンシャルは `~/.claude/.env.langfuse` に保存（プロジェクト外）
- [ ] `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY`, `LANGFUSE_HOST` の3変数を使用
- [ ] `.gitignore` に `.env.langfuse` を追加
- [ ] 既存の `guard-secrets.sh` / `guard-secrets-read.sh` と干渉しない

**優先度**: P0（必須）

#### F5: settings.json フック登録

**ユーザーストーリー**:
開発者として、既存のガードフックを壊さずに Langfuse ロガーを全イベントに登録したい

**受け入れ条件**:
- [ ] `PreToolUse`（空マッチャー）, `PostToolUse`, `Stop`, `SessionStart` の4イベントに登録
- [ ] 既存の `Bash` / `Read` マッチャーのガードフックはそのまま保持
- [ ] タイムアウト 10 秒を設定
- [ ] スクリプトは stdout に JSON を出力しない（`permissionDecision` を返さない）

**優先度**: P0（必須）

### 将来的な機能（Post-MVP）

#### F6: ユーザープロンプト記録

`UserPromptSubmit` フックでユーザーの入力テキストをトレースの入力として記録。

**優先度**: P1（重要）

#### F7: サブエージェントトラッキング

`SubagentStart/Stop` フックでサブエージェントをネストスパンとして追跡。

**優先度**: P1（重要）

#### F8: LLM Generation トラッキング

トランスクリプト JSONL を `Stop` 時に解析し、トークン数・コストを Langfuse Generation として記録。

**優先度**: P2（できれば）

#### F9: ステータスライン統合

`statusline.sh` に Langfuse トレース URL を表示。

**優先度**: P2（できれば）

## 非機能要件

### パフォーマンス
- フックスクリプトの同期処理部分（stdin 読み取り〜curl 発行前）: 200ms 以内
- Langfuse API 送信は `curl` バックグラウンド実行（`&`）で非同期化、最大 5 秒タイムアウト
- Claude Code の応答速度への体感的影響: なし

### 信頼性
- `~/.claude/.env.langfuse` 未設定時: 即座に `exit 0`（エラーなし）
- Langfuse API 到達不能時: curl がタイムアウトするだけで Claude Code に影響なし
- 状態ファイル競合: `tool_use_id` ベースの個別ファイルで回避

### セキュリティ
- API キーはプロジェクトディレクトリ外（`~/.claude/`）に保存
- `tool_response` は先頭 1000 文字に切り詰め（機密情報の漏洩リスク低減）
- `.gitignore` で `.env.langfuse` をコミット対象外に

### 互換性
- 既存ガードフック 5 本（guard-secrets, guard-secrets-read, guard-aws-cli, guard-terraform, validate-commit-message）との共存
- devcontainer 環境の `jq`（`/usr/bin/jq`）と `curl` に依存（追加インストール不要）
- `uuidgen` 未インストール環境に対応（bash `$RANDOM` フォールバック）

## スコープ外

明示的にスコープ外とする項目:
- OTel Collector を使った OpenTelemetry ベースの連携（Claude Code の OTEL はメトリクス/ログのみでトレース階層を出せない。トークンデータはトランスクリプト JSONL から Hooks で取得可能なため不要）
- Langfuse のセルフホスティング（Cloud Hobby プランで十分）
- Langfuse SDK（Node.js / Python）の利用（bash スクリプトで完結）

### フェーズ2 で対応予定（MVP スコープ外）
- トランスクリプト JSONL 解析による LLM Generation 記録（トークン数・キャッシュヒット率）
- モデル別トークン単価によるコスト計算・課金分析
