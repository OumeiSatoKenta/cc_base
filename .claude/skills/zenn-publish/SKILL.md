---
name: zenn-publish
description: Zenn記事をZennリポジトリにコピー・コミット・pushして下書き公開するスキル。「Zennに下書き公開」「記事をpush」「Zennにデプロイ」「記事を公開して」「Zennにコピー」等のリクエストでトリガーする。
---

# Zenn記事デプロイスキル

`zenn/articles/` の記事を &lt;your-zenn-repo&gt; リポジトリにコピーし、コミット・pushしてZennに下書き表示させる。

## 前提

- &lt;your-zenn-repo&gt; リポジトリがローカルにclone済み（パスはユーザーに確認する）
- Zenn GitHub連携が設定済み（mainへのpushで自動デプロイ）
- 記事の `published: false` → Zenn上で下書き表示、`published: true` → 公開

## ワークフロー

### 1. 対象記事の確認

ユーザーに対象を確認する。指定がなければ全記事を対象にする。

```bash
# 現在の下書き記事を一覧
ls zenn/articles/*.md
```

### 2. &lt;your-zenn-repo&gt;リポジトリのパス確認

初回はユーザーに &lt;your-zenn-repo&gt; リポジトリのローカルパスを確認する。
典型的なパス:
- devcontainer環境: `/workspaces/&lt;your-zenn-repo&gt;`
- ローカル環境: `~/workspace/&lt;your-zenn-repo&gt;` 等

### 3. &lt;your-zenn-repo&gt;の最新化

```bash
cd {ZENN_SATOKEN_PATH}
git pull origin main
```

### 4. 記事のコピー

```bash
# 全記事コピー
cp {PROJECT_ROOT}/zenn/articles/*.md {ZENN_SATOKEN_PATH}/articles/

# または特定の記事のみ
cp {PROJECT_ROOT}/zenn/articles/{slug}.md {ZENN_SATOKEN_PATH}/articles/
```

### 5. published: false の確認

下書き公開の場合、コピーした記事が `published: false` であることを確認する。

```bash
grep "published:" {ZENN_SATOKEN_PATH}/articles/{対象ファイル}
```

ユーザーが「公開して」と明示した場合のみ `published: true` に変更する。

### 6. コミット & push

```bash
cd {ZENN_SATOKEN_PATH}
git add articles/
git status
git commit -m "add: {記事の簡潔な説明}"
git push origin main
```

### 7. 確認

pushが成功したら以下を案内する:

- 下書き確認: https://zenn.dev/dashboard/articles
- デプロイ状況: https://zenn.dev/dashboard/deploys
