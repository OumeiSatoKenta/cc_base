---
name: web-artifacts-builder
description: モダンなフロントエンドWeb技術（React、Tailwind CSS、shadcn/ui）を使用した精巧なマルチコンポーネントのclaude.ai HTMLアーティファクトを構築するためのツールスイート。状態管理、ルーティング、shadcn/uiコンポーネントを必要とする複雑なアーティファクトに使用する。単純なシングルファイルHTML/JSXアーティファクトには使用しない。
---

<!--
  このファイルは Apache License 2.0 に基づき、以下のリポジトリから派生したものです:
  https://github.com/anthropics/skills/tree/main/skills/web-artifacts-builder
  Copyright 2025 Anthropic, PBC

  変更内容 (2026-02-28):
  - 英語から日本語への全文翻訳
  - 日本語の利用コンテキストに合わせた description の調整
  - 注: 元のスキルは scripts/init-artifact.sh と scripts/bundle-artifact.sh を参照します。
    これらのスクリプトが必要な場合は元のリポジトリから取得してください。
  ライセンス全文: .claude/skills/APACHE-2.0-LICENSE
-->

# Webアーティファクトビルダー

強力なフロントエンドclaude.aiアーティファクトを構築するには、以下の手順に従う:
1. `scripts/init-artifact.sh` を使用してフロントエンドリポジトリを初期化
2. 生成されたコードを編集してアーティファクトを開発
3. `scripts/bundle-artifact.sh` を使用してすべてのコードを単一HTMLファイルにバンドル
4. アーティファクトをユーザーに表示
5. （オプション）アーティファクトをテスト

**技術スタック**: React 18 + TypeScript + Vite + Parcel（バンドリング）+ Tailwind CSS + shadcn/ui

## デザインとスタイルのガイドライン

非常に重要: いわゆる「AIスロップ」を避けるため、過度な中央揃えレイアウト、パープルグラデーション、均一な角丸、Interフォントの使用を避ける。

## クイックスタート

### ステップ1: プロジェクトの初期化

初期化スクリプトを実行して新しいReactプロジェクトを作成する:
```bash
bash scripts/init-artifact.sh <project-name>
cd <project-name>
```

これにより、以下が完全に設定されたプロジェクトが作成される:
- React + TypeScript（Vite経由）
- Tailwind CSS 3.4.1（shadcn/uiテーマシステム付き）
- パスエイリアス（`@/`）設定済み
- 40+ shadcn/uiコンポーネントをプリインストール
- すべてのRadix UI依存関係を含む
- Parcelバンドリング設定済み（.parcelrc経由）
- Node 18+ 互換性（自動検出とViteバージョンの固定）

### ステップ2: アーティファクトの開発

アーティファクトを構築するには、生成されたファイルを編集する。ガイダンスについては以下の**一般的な開発タスク**を参照。

### ステップ3: 単一HTMLファイルにバンドル

ReactアプリをシングルHTMLアーティファクトにバンドルするには:
```bash
bash scripts/bundle-artifact.sh
```

これにより、すべてのJavaScript、CSS、依存関係がインラインされた自己完結型のアーティファクトである `bundle.html` が作成される。このファイルはClaude会話でアーティファクトとして直接共有できる。

**要件**: プロジェクトのルートディレクトリに `index.html` が必要。

**スクリプトの動作内容**:
- バンドリング依存関係をインストール（parcel、@parcel/config-default、parcel-resolver-tspaths、html-inline）
- パスエイリアスサポート付きの `.parcelrc` 設定を作成
- Parcelでビルド（ソースマップなし）
- html-inlineを使用してすべてのアセットを単一HTMLにインライン化

### ステップ4: アーティファクトをユーザーと共有

最後に、バンドルされたHTMLファイルを会話でユーザーと共有し、アーティファクトとして表示できるようにする。

### ステップ5: アーティファクトのテスト/可視化（オプション）

注: これは完全にオプションのステップ。必要な場合またはリクエストされた場合にのみ実行する。

アーティファクトをテスト/可視化するには、利用可能なツール（他のスキルやPlaywright、Puppeteerなどの組み込みツールを含む）を使用する。一般的に、リクエストと完成アーティファクトの表示の間にレイテンシーが追加されるため、事前のテストは避ける。アーティファクトを提示した後、リクエストされた場合や問題が発生した場合にテストする。

## リファレンス

- **shadcn/uiコンポーネント**: https://ui.shadcn.com/docs/components
