# cc_base

Claude Code を使ったスペック駆動開発のためのプロジェクトテンプレートです。
カスタムスキル・エージェント・MCP サーバー・フック・セキュリティガードを一式備えており、すぐに本格的な AI 駆動開発を始められます。

## 特徴

### カスタムスキル（25+）

`/` コマンドで呼び出せるスキルを多数収録しています。

| カテゴリ | スキル例 |
|---------|---------|
| **開発フロー** | `ship-pr`, `add-feature`, `steering`, `review-codes`, `review-docs` |
| **ドキュメント** | `prd-writing`, `architecture-design`, `functional-design`, `glossary-creation` |
| **フロントエンド** | `frontend-design`, `web-artifacts-builder`, `theme-factory`, `webapp-testing` |
| **TiDB** | `tidb-cloud`, `tidb-sql`, `tidb-python`, `tidb-kysely`, `tidb-serverless-driver` |
| **コンテンツ** | `zenn-article`, `zenn-publish`, `zenn-review`\*、`pptx-build`, `internal-comms` |
| **AI開発** | `claude-api`, `skill-creator`, `doc-coauthoring` |

### カスタムエージェント

チームとして協調作業する専門エージェント群:

- `code-reviewer` — コード品質・パターン準拠レビュー
- `code-reviewer-structural` — 構造・アーキテクチャレビュー
- `code-reviewer-secondary` — 欠陥・セキュリティレビュー
- `code-reviewer-docs` — API使用の正確性レビュー
- `frontend-developer` — フロントエンドコンポーネント実装
- `test-writer` — テストコード作成
- `doc-reviewer` — ドキュメントレビュー
- `implementation-validator` — スペックとの整合性検証

### MCP サーバー構成

`.mcp.json` に以下のサーバーを設定済み:

| サーバー | 用途 |
|---------|------|
| **serena** | セマンティックコード解析・シンボル操作 |
| **context7** | 外部ライブラリの最新ドキュメント取得 |
| **codex** | セカンドオピニオン AI（OpenAI Codex） |
| **drawio** | Draw.io 図表の生成・編集 |
| **awslabs.aws-api-mcp-server** | AWS API 呼び出し（読み取り専用） |
| **awslabs.well-architected-security-mcp-server** | Well-Architected セキュリティレビュー |
| **deploy-on-aws** (plugin) | AWS 知識・料金・IaC・構成図（awslabs/agent-plugins） |

### セキュリティフック

`pre-tool-use` フックで Claude Code の操作を自動ガード:

- `guard-secrets.sh` — シークレット・認証情報ファイルへの書き込みをブロック
- `guard-secrets-read.sh` — シークレット・認証情報ファイルの読み取りをブロック
- `guard-aws-cli.sh` — AWS CLI の破壊的操作（`delete`, `terminate` 等）をブロック
- `guard-terraform.sh` — `terraform destroy` をブロック
- `validate-commit-message.sh` — Conventional Commits 形式を強制

### devcontainer

`.devcontainer/` に開発環境を定義済み。コンテナ起動時に以下を自動セットアップ:

- Node.js (LTS) / GitHub CLI / AWS CLI / Docker outside of Docker
- Claude Code / OpenAI Codex CLI / bubblewrap（Codex サンドボックス用）
- uv / uvx（MCP サーバー実行用）
- aws-vault / AWS SSM Session Manager Plugin
- Draw.io MCP / Serena
- deploy-on-aws プラグイン（awslabs/agent-plugins）

> \* `zenn-article` / `zenn-publish` / `zenn-review` は、Zenn と GitHub 連携した別リポジトリがローカルに存在することを前提とします。

## セットアップ

→ [docs/SETUP.md](docs/SETUP.md)

## 開発フロー

このテンプレートは**スペック駆動開発**を採用しています。

```
1. /setup-project    # 永続ドキュメントを対話的に作成（初回のみ）
2. /add-feature      # 機能実装（ステアリングファイル → 実装 → 検証）
3. /ship-pr          # ブランチ作成 → コミット → PR 作成
```

詳細なワークフローは [CLAUDE.md](CLAUDE.md) を参照してください。

## ライセンス

スキルの一部は [Apache License 2.0](.claude/skills/APACHE-2.0-LICENSE) の下でライセンスされています。
