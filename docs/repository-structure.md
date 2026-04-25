<!-- 生成日: 20260425 -->

# リポジトリ構造定義書 (Repository Structure Document)

## プロジェクト構造

```
cc_langfuse/
├── .claude/                    # Claude Code 設定
│   ├── agents/                 # サブエージェント定義
│   ├── commands/               # スラッシュコマンド
│   ├── hooks/                  # フックスクリプト ★本プロジェクトのメイン実装
│   ├── skills/                 # タスクモード別スキル
│   ├── settings.json           # プロジェクト設定（フック登録含む）
│   └── settings.local.json     # ローカル設定（gitignore対象）
├── .devcontainer/              # devcontainer 設定
│   ├── devcontainer.json       # コンテナ定義
│   ├── install-tools.sh        # ツールインストールスクリプト
│   └── serena_config.yml       # Serena 設定
├── .serena/                    # Serena コード分析設定
├── .steering/                  # 作業単位のステアリングファイル
├── docs/                       # 永続的ドキュメント
│   ├── ideas/                  # 壁打ち・アイデア
│   ├── product-requirements.md # PRD
│   ├── functional-design.md    # 機能設計書
│   ├── architecture.md         # 技術仕様書
│   ├── repository-structure.md # リポジトリ構造定義書（本文書）
│   ├── development-guidelines.md # 開発ガイドライン
│   ├── glossary.md             # 用語集
│   └── SETUP.md                # セットアップガイド
├── knowledge/                  # ナレッジベース（教訓・ルール）
├── scripts/                    # 初期化・ユーティリティスクリプト
│   └── init-project.sh         # プロジェクト名置換スクリプト
├── .gitignore                  # Git 除外設定
├── .mcp.json                   # MCP サーバー設定
├── CLAUDE.md                   # Claude Code メインプロンプト
└── README.md                   # プロジェクト概要
```

## ディレクトリ詳細

### .claude/hooks/（フックスクリプト — メイン実装）

**役割**: Claude Code のフックイベントを処理するシェルスクリプト群

**配置ファイル**:
- `langfuse-logger.sh`: Langfuse トレーシングロガー（新規追加）
- `guard-*.sh`: セキュリティガードスクリプト（既存）
- `validate-commit-message.sh`: コミットメッセージ検証（既存）

**命名規則**:
- ガードスクリプト: `guard-{対象}.sh`（例: `guard-secrets.sh`）
- ロガースクリプト: `{サービス名}-logger.sh`（例: `langfuse-logger.sh`）

**ファイル一覧**:
```
.claude/hooks/
├── langfuse-logger.sh          # ★新規: Langfuse トレーシング
├── guard-aws-cli.sh            # 既存: AWS CLI 書込みブロック
├── guard-secrets.sh            # 既存: .env ファイル書込みブロック
├── guard-secrets-read.sh       # 既存: 機密ファイル読取りブロック
├── guard-terraform.sh          # 既存: terraform destroy ブロック
└── validate-commit-message.sh  # 既存: Conventional Commits 検証
```

### docs/（永続的ドキュメント）

**役割**: プロジェクト全体の「何を作るか」「どう作るか」を定義

**配置ドキュメント**:
- `product-requirements.md`: プロダクト要求定義書
- `functional-design.md`: 機能設計書
- `architecture.md`: 技術仕様書
- `repository-structure.md`: リポジトリ構造定義書（本文書）
- `development-guidelines.md`: 開発ガイドライン
- `glossary.md`: 用語集
- `SETUP.md`: 環境セットアップ手順

**サブディレクトリ**:
- `ideas/`: 壁打ち・ブレインストーミングの成果物

### ユーザーホーム（リポジトリ外）

**役割**: ユーザー固有の設定・クレデンシャル

```
~/.claude/
└── .env.langfuse     # Langfuse API キー（手動作成）
```

### ランタイム一時ファイル（リポジトリ外）

**役割**: フックスクリプトの状態管理

```
/tmp/claude-langfuse/
└── {session_id}/
    ├── trace_id      # 現在のトレースID
    ├── turn_count    # ターンカウンタ
    ├── model         # 使用モデル名
    └── spans/        # スパン状態ファイル
        └── {tool_use_id}
```

## ファイル配置規則

### フックスクリプト

| ファイル種別 | 配置先 | 命名規則 | 例 |
|------------|--------|---------|-----|
| セキュリティガード | `.claude/hooks/` | `guard-{対象}.sh` | `guard-secrets.sh` |
| ロガー | `.claude/hooks/` | `{サービス}-logger.sh` | `langfuse-logger.sh` |
| バリデータ | `.claude/hooks/` | `validate-{対象}.sh` | `validate-commit-message.sh` |

### ドキュメント

| ファイル種別 | 配置先 | 命名規則 |
|------------|--------|---------|
| 永続設計書 | `docs/` | `kebab-case.md` |
| アイデア | `docs/ideas/` | 自由形式 `.md` |
| ステアリング | `.steering/{YYYYMMDD}-{task}/` | `requirements.md`, `design.md`, `tasklist.md` |

### 設定ファイル

| ファイル種別 | 配置先 | 説明 |
|------------|--------|------|
| Claude Code 設定 | `.claude/settings.json` | フック登録、パーミッション |
| MCP サーバー設定 | `.mcp.json` | MCP サーバー接続定義 |
| devcontainer 設定 | `.devcontainer/devcontainer.json` | コンテナ定義 |
| Langfuse クレデンシャル | `~/.claude/.env.langfuse` | リポジトリ外 |

## 除外設定

### .gitignore

```
# 環境変数
.env
.env.local
.env.*.local
.env.langfuse

# Claude Code ローカル設定
.claude/settings.local.json

# ステアリングファイル
.steering/*
!.steering/.gitkeep

# Node.js
node_modules/
dist/
build/

# OS・IDE
.DS_Store
.vscode/
.idea/

# Serena キャッシュ
.serena/cache/
.serena/memories/
```

## スケーリング戦略

### フック追加時

新しいフックスクリプトを追加する場合:

1. `.claude/hooks/` にスクリプトを配置
2. `.claude/settings.json` の `hooks` セクションに登録
3. 既存フックとの干渉がないことを確認

### フェーズ2 拡張時

`langfuse-logger.sh` 内に新しいイベントハンドラを追加:

```bash
case "$EVENT" in
  SessionStart) handle_session_start ;;
  PreToolUse) handle_pre_tool_use ;;
  PostToolUse) handle_post_tool_use ;;
  Stop) handle_stop ;;
  UserPromptSubmit) handle_user_prompt ;;    # フェーズ2
  SubagentStart) handle_subagent_start ;;    # フェーズ2
  SubagentStop) handle_subagent_stop ;;      # フェーズ2
  *) ;;
esac
```

必要に応じて `settings.json` に新しいイベントタイプを登録。
