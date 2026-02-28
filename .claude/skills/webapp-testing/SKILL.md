---
name: webapp-testing
description: Playwrightを使用してローカルWebアプリケーションの操作とテストを行うためのツールキット。フロントエンドの機能検証、UIの動作デバッグ、ブラウザスクリーンショットのキャプチャ、ブラウザログの確認に対応する。
---

<!--
  このファイルは Apache License 2.0 に基づき、以下のリポジトリから派生したものです:
  https://github.com/anthropics/skills/tree/main/skills/webapp-testing
  Copyright 2025 Anthropic, PBC

  変更内容 (2026-02-28):
  - 英語から日本語への全文翻訳
  - 日本語の利用コンテキストに合わせた description の調整
  - 注: 元のスキルは scripts/with_server.py と examples/ ディレクトリを参照します。
    これらのファイルが必要な場合は元のリポジトリから取得してください。
  ライセンス全文: .claude/skills/APACHE-2.0-LICENSE
-->

# Webアプリケーションテスト

ローカルWebアプリケーションをテストするには、ネイティブのPython Playwrightスクリプトを記述する。

**利用可能なヘルパースクリプト**:
- `scripts/with_server.py` - サーバーのライフサイクルを管理（複数サーバー対応）

**スクリプトは必ず最初に `--help` で実行すること** — 使い方を確認する。カスタマイズされたソリューションが絶対に必要であることを確認するまでソースコードを読まない。これらのスクリプトは非常に大きくなる可能性があり、コンテキストウィンドウを汚染する。コンテキストウィンドウに取り込むのではなく、ブラックボックススクリプトとして直接呼び出す形で設計されている。

## ディシジョンツリー: アプローチの選択

```
ユーザータスク → 静的HTMLか？
    ├─ はい → HTMLファイルを直接読んでセレクタを特定
    │         ├─ 成功 → セレクタを使ってPlaywrightスクリプトを記述
    │         └─ 失敗/不完全 → 動的として扱う（以下）
    │
    └─ いいえ（動的Webアプリ） → サーバーは既に起動しているか？
        ├─ いいえ → 実行: python scripts/with_server.py --help
        │        次にヘルパー + 簡略化されたPlaywrightスクリプトを使用
        │
        └─ はい → 偵察してから行動:
            1. ナビゲートしてnetworkidleを待つ
            2. スクリーンショットを撮るかDOMを検査する
            3. レンダリングされた状態からセレクタを特定する
            4. 発見されたセレクタを使ってアクションを実行する
```

## 例: with_server.py の使用

サーバーを起動するには、まず `--help` を実行し、次にヘルパーを使用する:

**単一サーバー:**
```bash
python scripts/with_server.py --server "npm run dev" --port 5173 -- python your_automation.py
```

**複数サーバー（例: バックエンド + フロントエンド）:**
```bash
python scripts/with_server.py \
  --server "cd backend && python server.py" --port 3000 \
  --server "cd frontend && npm run dev" --port 5173 \
  -- python your_automation.py
```

オートメーションスクリプトを作成するには、Playwrightロジックのみを含める（サーバーは自動的に管理される）:
```python
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True) # 常にChromiumをヘッドレスモードで起動
    page = browser.new_page()
    page.goto('http://localhost:5173') # サーバーは既に起動して準備完了
    page.wait_for_load_state('networkidle') # 重要: JSの実行を待つ
    # ... オートメーションロジック
    browser.close()
```

## 偵察してから行動パターン

1. **レンダリング済みDOMを検査する**:
   ```python
   page.screenshot(path='/tmp/inspect.png', full_page=True)
   content = page.content()
   page.locator('button').all()
   ```

2. 検査結果から**セレクタを特定する**

3. 発見されたセレクタを使って**アクションを実行する**

## よくある落とし穴

- **やってはいけない**: 動的アプリで `networkidle` を待つ前にDOMを検査する
- **正しい方法**: 検査の前に `page.wait_for_load_state('networkidle')` を待つ

## ベストプラクティス

- **バンドルされたスクリプトをブラックボックスとして使用する** — タスクを達成するために、`scripts/` にある利用可能なスクリプトが役立つかどうかを検討する。これらのスクリプトは、コンテキストウィンドウを汚染することなく、一般的で複雑なワークフローを確実に処理する。`--help` で使い方を確認し、直接呼び出す。
- 同期スクリプトには `sync_playwright()` を使用する
- 完了時にはブラウザを必ず閉じる
- 説明的なセレクタを使用する: `text=`、`role=`、CSSセレクタ、またはID
- 適切な待機を追加する: `page.wait_for_selector()` または `page.wait_for_timeout()`

## 参照ファイル

- **examples/** - 一般的なパターンを示すサンプル:
  - `element_discovery.py` - ページ上のボタン、リンク、入力要素の発見
  - `static_html_automation.py` - ローカルHTMLに file:// URLを使用
  - `console_logging.py` - オートメーション中のコンソールログのキャプチャ
