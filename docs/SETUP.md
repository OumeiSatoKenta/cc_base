# 開発環境セットアップ手順

## 前提条件

- Docker Desktop がインストール済みであること
- VS Code + Dev Containers 拡張機能がインストール済みであること
- GitHub アカウントがあり、リポジトリへのアクセス権があること

## 0. プロジェクトの初期設定（テンプレートから新規作成時のみ）

このリポジトリをテンプレートとして新しいプロジェクトを作成した場合、最初にプロジェクト名の置換を行う。

```bash
# リポジトリをクローン
git clone <repository-url>
cd <project-name>

# プロジェクト名を一括置換（引数でプロジェクト名を指定）
bash scripts/init-project.sh <project-name>
```

このスクリプトは以下のファイル内の `cc_base` を指定した名前に置換する:

| ファイル | 置換箇所 |
|---------|---------|
| `.devcontainer/devcontainer.json` | `name`, `workspaceFolder` |
| `.mcp.json` | serena の `--project` パス |
| `.serena/project.yml` | `project_name` |
| `.devcontainer/serena_config.yml` | `projects` リスト |
| `docs/SETUP.md` | ドキュメント内の参照 |

置換後、devcontainer を起動する（次のセクションへ進む）。

> **注意**: 既存プロジェクトをクローンした場合（置換済み）はこのステップは不要。

## 1. devcontainer の起動

```bash
# VS Code で開く
code .
```

VS Code が `.devcontainer/devcontainer.json` を検出し、「Reopen in Container」を提案する。承認するとコンテナがビルドされ、以下が自動的にセットアップされる:

### devcontainer features（自動インストール）

| ツール | 用途 |
|--------|------|
| Node.js (LTS) | アプリケーションランタイム |
| GitHub CLI (`gh`) | PR作成・Issue管理 |
| AWS CLI | AWSリソース操作 |
| Docker outside of Docker | コンテナ操作 |

### install-tools.sh（自動実行）

| ツール | 用途 |
|--------|------|
| PulseAudio クライアント | macOS ホストからの音声入力転送 |
| ALSA PulseAudio プラグイン | ALSA → PulseAudio リダイレクト |
| Claude Code | AI コーディングアシスタント |
| OpenAI Codex CLI | セカンドオピニオン用AI |
| uv / uvx | Python パッケージマネージャー（MCP サーバー実行用） |
| aws-vault | AWS 認証情報の安全な管理 |
| AWS SSM Session Manager Plugin | EC2 インスタンスへのセッション接続 |
| Draw.io MCP (`@drawio/mcp`) | 図表生成用 MCP サーバー |

コンテナ起動後、`package.json` が存在すれば `npm install` も自動実行される。

## 2. GitHub CLI 認証

PR作成やリポジトリ操作に必要。

```bash
# 認証（ブラウザ認証フローが開始される）
gh auth login

# git の credential helper として gh を設定
gh auth setup-git

# 確認
gh auth status
```

`Token scopes` に `repo` が含まれていることを確認する。不足している場合:

```bash
gh auth refresh -s repo
```

## 3. AWS 認証の設定

AWS 認証情報は以下の用途で使用される:

- **AWS 系 MCP サーバー**: Claude Code が AWS API を呼び出してリソース情報を取得する（`aws-api-mcp-server` 等）
- **Terraform / IaC 操作**: `terraform plan` / `apply` 等のインフラ操作コマンドの実行
- **AWS CLI 直接操作**: S3、CloudFormation、SSM 等の手動操作

これらが不要であればこのセクションはスキップできる。

### 3-1. AWS CLI の基本設定

```bash
aws configure
```

以下を入力する:
- **AWS Access Key ID**: IAM ユーザーのアクセスキー
- **AWS Secret Access Key**: IAM ユーザーのシークレットキー
- **Default region name**: `ap-northeast-1`
- **Default output format**: `json`

### 3-2. 名前付きプロファイルの設定

`.mcp.json` の `awslabs.aws-api-mcp-server` は `AWS_PROFILE=your-profile` を参照する。このプロファイルを設定する:

```bash
aws configure --profile your-profile
```

または `~/.aws/credentials` を直接編集:

```ini
[your-profile]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

```ini
# ~/.aws/config
[profile your-profile]
region = ap-northeast-1
output = json
```

### 3-3. aws-vault を使う場合（推奨）

認証情報を OS のキーチェーンで安全に管理できる:

```bash
# プロファイルを追加
aws-vault add your-profile

# 認証が通るか確認
aws-vault exec your-profile -- aws sts get-caller-identity
```

### 3-4. 認証の確認

```bash
# デフォルトプロファイル
aws sts get-caller-identity

# 名前付きプロファイル
aws sts get-caller-identity --profile your-profile
```

## 4. MCP サーバーの確認

`.mcp.json` に定義されている MCP サーバーは、Claude Code 起動時に自動的に接続される。手動での起動は不要。

### MCP サーバー一覧

| サーバー名 | 実行方式 | 用途 |
|-----------|---------|------|
| **serena** | `uvx` (stdio) | セマンティックコード解析・シンボル操作 |
| **context7** | `npx` (stdio) | 外部ライブラリの最新ドキュメント取得 |
| **codex** | `codex` (stdio) | セカンドオピニオン取得 |
| **drawio** | `npx` (stdio) | Draw.io 図表の生成・編集 |
| **awslabs.aws-api-mcp-server** | `uvx` (stdio) | AWS API 呼び出し（読み取り専用） |
| **awslabs.well-architected-security-mcp-server** | `uvx` (stdio) | Well-Architected セキュリティレビュー |

### 依存関係

- **npx 系**（context7, drawio）: Node.js があれば動作する（devcontainer で自動インストール済み）
- **uvx 系**（serena, aws-api, well-architected-security）: uv が必要（install-tools.sh で自動インストール済み）
- **codex**: OpenAI Codex CLI が必要（install-tools.sh で自動インストール済み）
- **AWS 系 MCP サーバー**: AWS 認証情報の設定が必要（セクション3を参照）
- **deploy-on-aws プラグイン**: devcontainer 起動時に自動インストール済み（セクション5を参照）

## 5. agent-plugins for AWS（自動インストール済み）

本テンプレートは AWS Labs の `deploy-on-aws` プラグイン（[awslabs/agent-plugins](https://github.com/awslabs/agent-plugins)）を AWS 系の中核ツールとして使用する。

devcontainer の初回起動時に `install-tools.sh` で自動インストールされるため、手動での操作は不要。

### 含まれるツール

| 種別 | 名前 | 用途 |
|------|------|------|
| Skill | `deploy` | IaC 生成・コスト見積もり |
| Skill | `aws-architecture-diagram` | AWS4 アイコン付き draw.io XML 構成図生成 |
| MCP | `awsknowledge` | AWS アーキテクチャ・ベストプラクティス |
| MCP | `awspricing` | AWS 料金情報 |
| MCP | `awsiac` | IaC プロバイダドキュメント・構成生成 |

### 手動で再インストールする場合

```bash
# マーケットプレイスが未登録の場合は先に追加
claude plugin marketplace add awslabs/agent-plugins
claude plugin install deploy-on-aws@agent-plugins-for-aws --scope user
```

必要に応じて他の agent-plugins（`aws-serverless`, `databases-on-aws` 等）も追加可能:

```bash
# 利用可能なプラグイン一覧は GitHub で確認
# https://github.com/awslabs/agent-plugins
claude plugin install <plugin-name>@agent-plugins-for-aws --scope user
```

## 6. Claude Code Voice 機能の設定（macOS ホストのみ）

DevContainer 内で Claude Code の `/voice` を使うには、macOS ホスト側で PulseAudio を起動し、コンテナへ音声を転送する必要がある。

### 6-1. macOS ホスト側のセットアップ（初回のみ）

```bash
# PulseAudio をインストール
brew install pulseaudio

# TCP 接続を許可する設定を追加（ローカル・Docker ネットワークのみ許可）
echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1;172.16.0.0/12;192.168.0.0/16;10.0.0.0/8" >> $(brew --prefix)/etc/pulse/default.pa
```

### 6-2. PulseAudio デーモンの起動（毎回）

DevContainer で Voice 機能を使う前に、macOS 側で PulseAudio を起動する:

```bash
pulseaudio --exit-idle-time=-1 --daemon
```

> **注意**: macOS を再起動するたびにこのコマンドの実行が必要。

> **セキュリティ注意**: `auth-anonymous=1` は使用しないこと。認証なしで誰でもマイクにアクセス可能になる。`auth-ip-acl` でローカル・Docker ネットワーク範囲に制限する。

### 6-3. コンテナ側の確認

コンテナ側のセットアップは `install-tools.sh` で自動的に行われる:

- `pulseaudio-utils`, `libsox-fmt-pulse`, `libasound2-plugins` のインストール
- `~/.asoundrc` による ALSA → PulseAudio リダイレクト設定
- `containerEnv` の `PULSE_SERVER` / `AUDIODRIVER` 環境変数

接続確認:

```bash
# PulseAudio 接続テスト
pactl info

# 録音テスト（1秒間録音）
rec -t wav /tmp/test.wav trim 0 1
```

正常であれば Claude Code で `/voice` が使用可能。

## 7. 開発サーバーの起動

```bash
npm run dev
```

## トラブルシューティング

### MCP サーバーが接続できない

```bash
# uvx が使えるか確認
uvx --version

# パスが通っていない場合
source ~/.local/bin/env
```

### AWS 系 MCP でエラーが出る

1. `aws sts get-caller-identity` で認証が通るか確認
2. `~/.aws/credentials` にプロファイルが正しく設定されているか確認
3. `AWS_PROFILE=your-profile` のプロファイルが存在するか確認

### Claude Code Voice でエラーが出る

1. macOS ホスト側で PulseAudio が起動しているか確認:
   ```bash
   # ホスト側で実行
   pulseaudio --check && echo "running" || echo "not running"
   ```
2. コンテナから接続できるか確認:
   ```bash
   pactl info
   ```
3. `Cannot open shared library libasound_module_pcm_pulse.so` エラーの場合:
   ```bash
   sudo apt-get install -y libasound2-plugins
   ```
4. ALSA エラー（`Unknown PCM default`）の場合、`~/.asoundrc` が正しく設定されているか確認:
   ```bash
   cat ~/.asoundrc
   # pcm.!default { type pulse } と ctl.!default { type pulse } があること
   ```

### draw.io MCP が見つからない

```bash
# グローバルにインストールされているか確認
npm list -g @drawio/mcp

# 再インストール
npm i -g @drawio/mcp
```
