---
name: ship-pr
description: 修正内容のリストアップ、ブランチ作成、機能単位での複数コミット、リモートPush、PR作成までを一貫して実行するスキル。コードの変更をPRとしてまとめたいとき、ブランチを切ってPushしたいとき、PRを作成したいとき、変更を出荷したいときに使用する。「PR作って」「プルリク出して」「変更をPushして」「ブランチ切ってコミットして」といった依頼で必ずトリガーする。
---

# Ship PR — 変更内容をPRとして出荷するワークフロー

ローカルの変更内容を整理し、ブランチ作成からPR作成まで一貫して実行する。

## ワークフロー概要

```
0. Git認証の確認
1. 変更内容のリストアップ
2. ブランチ名の決定と作成
3. 変更を機能単位でコミットに分割
4. リモートリポジトリにPush
5. コミット内容からサマリーを生成してPR作成
```

## ステップ0: Git認証の確認

Push・PR作成に必要な認証が通っているかを最初に確認する。
GitHub CLI (`gh`) を使って認証状態を管理する。

```bash
# gh の認証状態を確認
gh auth status
```

**認証済みの場合**: そのまま次のステップに進む。

**未認証の場合**: 以下の手順で認証を設定する。

```bash
# GitHub CLI でログイン（git の認証情報も自動設定される）
gh auth login

# git の credential helper として gh を設定
gh auth setup-git
```

`gh auth setup-git` を実行すると、`git push` 等のgit操作でも
gh の認証トークンが自動的に使用されるようになる。
これにより SSH鍵やPersonal Access Tokenの個別設定が不要になる。

**認証の確認ポイント:**
- `gh auth status` で `Logged in to github.com` が表示されること
- `Token scopes` に `repo` が含まれていること（Push・PR作成に必要）
- スコープが不足している場合は `gh auth refresh -s repo` で追加する

## ステップ1: 変更内容のリストアップ

以下を並列で実行し、変更の全体像を把握する:

```bash
# 未追跡ファイルとステータス確認
git status

# ステージ済み・未ステージの差分確認
git diff
git diff --cached

# 直近のコミット履歴（コミットメッセージスタイルの参考用）
git log --oneline -10
```

変更内容を以下のカテゴリに分類する:
- **docs**: ドキュメント変更（`.md`, `docs/`, `.steering/`）
- **config**: 設定ファイル変更（`.json`, `.yml`, `.env`, `.claude/`）
- **feat**: 新機能のソースコード（`src/`内の新規ファイル、大きな機能追加）
- **fix**: バグ修正（既存ファイルの修正）
- **refactor**: リファクタリング（動作を変えないコード改善）
- **test**: テスト関連（`tests/`, `*.test.*`, `*.spec.*`）
- **style**: スタイル変更（CSS, フォーマット修正）
- **chore**: その他（依存関係更新、ビルド設定など）

分類結果をユーザーに提示し、コミットのグルーピングを確認する。

## ステップ2: ブランチ名の決定と作成

### ブランチ命名規則

```
feature/YYYYMMDD-簡潔な説明（英語ケバブケース）
```

**例:**
- `feature/20260228-import-anthropic-skills`
- `feature/20260228-add-user-profile`
- `feature/20260228-fix-login-validation`

### 決定手順

1. 変更内容の主要な目的を特定する
2. 日付（今日）を `YYYYMMDD` 形式で取得する
3. 目的を英語のケバブケース（3〜5語）で簡潔に表現する
4. ブランチ名の候補をユーザーに提示し、承認を得る

### ブランチ作成

```bash
# 現在のブランチを確認
git branch --show-current

# 新しいブランチを作成してチェックアウト
git checkout -b feature/YYYYMMDD-説明
```

main ブランチ上にいない場合は、まず main に移動してから分岐するか確認する。

## ステップ3: 機能単位でのコミット

### コミット分割の方針

ステップ1で分類した変更を、**機能的な意味のある単位**でコミットに分割する。
1つのコミットは「1つの論理的な変更」を表す。

**分割の判断基準:**
- 異なる目的の変更は別コミットにする（ドキュメント追加 vs ソースコード変更）
- 密接に関連するファイルは同じコミットにまとめる
- 設定変更とそれを使うコード変更は一緒にコミットしてよい
- ライセンスファイルなどのメタ情報は独立したコミットにする

### コミットメッセージ規約

**1行メッセージ形式**を使用する。Conventional Commits の type 接頭辞を付けた簡潔な1行で記述する。

```
<type>(<scope>): <簡潔な説明（72文字以内）>
```

**ルール:**
- メッセージは必ず**1行**で完結させる（本文・複数行は使わない）
- サブジェクト行は**72文字以内**に収める
- Co-Authored-By は `git commit` の `--trailer` オプションで付与する

**type一覧:** feat, fix, docs, style, refactor, test, chore, ci, perf

**例:**
- `feat(auth): add JWT-based authentication`
- `docs(skills): import 7 skills from anthropic/skills repository`
- `fix(login): resolve validation error on empty email`
- `chore(deps): update React to v19.2`

### コミット実行

各コミットについて:
1. 対象ファイルを具体的なパス指定で `git add` する（`git add .` は使わない）
2. `-m` で1行メッセージ、`--trailer` で Co-Authored-By を付与する
3. `git status` で結果を確認する

```bash
# ファイルを個別にステージング
git add path/to/file1 path/to/file2

# 1行コミット + trailer
git commit -m "type(scope): 説明" --trailer "Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

## ステップ4: リモートリポジトリにPush

```bash
# リモートの存在確認
git remote -v

# 新しいブランチをリモートにPush（上流追跡を設定）
git push -u origin feature/YYYYMMDD-説明
```

Push前にユーザーに確認を取る。リモートが設定されていない場合はその旨を伝える。

## ステップ5: PR作成

### サマリー生成

コミット履歴から自動的にPRのサマリーを生成する:

```bash
# main との差分コミット一覧
git log main..HEAD --oneline

# main との差分ファイル一覧
git diff main..HEAD --stat

# main との全差分（サマリー生成用）
git diff main..HEAD
```

これらの情報を元に:
1. **Summary**: 変更の目的と背景を1〜3文で記述
2. **Changes**: 変更内容をカテゴリ別の箇条書きで記述
3. **Commits**: 各コミットの要約リスト

### PR作成

`templates/pr-template.md` のテンプレートを使い、プレースホルダーを実際の内容で置換する。

```bash
gh pr create \
  --base main \
  --title "PRタイトル（70文字以内）" \
  --body "$(cat <<'EOF'
## Summary

[自動生成されたサマリー]

## Changes

[カテゴリ別の変更リスト]

## Commits

[コミット一覧]

## Test Plan

- [ ] 変更内容のセルフレビュー完了
- [ ] 関連するテストの実行確認
- [ ] ビルドが通ることを確認

---

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### PRタイトルの規約

- 70文字以内
- 変更の「何を」ではなく「なぜ」を表現する
- Conventional Commits のtype接頭辞を使用可能

**例:**
- `feat: Import 7 Anthropic skills translated to Japanese`
- `fix: Resolve login validation error on empty email`

## 完了

PR URLをユーザーに提示して完了。

## 注意事項

- `.env`、`credentials.json` 等のシークレットを含むファイルは絶対にコミットしない
- コミット前に `git diff --cached` で内容を確認する
- pre-commit hookが失敗した場合は原因を調査して修正し、新しいコミットを作成する（`--amend` しない）
- `--force` push は行わない
- `--no-verify` は使用しない
