# PlayCover Manager

<div align="center">

![PlayCover Manager Icon](PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png)

**macOS用 PlayCover iOSアプリ管理ツール**

簡単起動 • 検索機能 • ストレージ管理

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2011.0+-lightgrey.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[機能](#-機能) • [インストール](#-インストール) • [使い方](#-使い方) • [開発](#-開発) • [配布](#-配布)

</div>

---

## 📖 概要

**PlayCover Manager** は、[PlayCover](https://github.com/PlayCover/PlayCover)でインストールしたiOSアプリを快適に管理・起動するためのGUIツールです。

### なぜPlayCover Managerが必要？

PlayCoverでインストールしたiOSアプリは、通常Finderから見つけにくい場所に保存されます。PlayCover Managerを使えば：

- ✅ インストール済みアプリを一覧表示
- ✅ ワンクリックで起動
- ✅ 検索機能で素早くアプリを発見
- ✅ ディスク使用量を確認
- ✅ ストレージ場所を管理

---

## ✨ 機能

### 🚀 クイックランチャー
- インストール済みiOSアプリをグリッド表示
- アプリアイコンとシステム言語名を表示
- ダブルクリックで即起動
- 起動中のアプリにはバッジ表示

### 🔍 検索機能
- アプリ名、Bundle IDで検索
- システム言語名・英語名の両方に対応
- リアルタイム検索結果

### 💾 ストレージ管理
- PlayCoverコンテナの自動検出
- ディスクイメージの使用量確認
- 保存先の変更（セットアップウィザード統合）

### 🛠️ メンテナンス機能
- アンマウント機能（ディスクイメージの安全な取り外し）
- キャッシュクリア
- データ管理

---

## 📦 インストール

### 方法1: Homebrew（推奨）

```bash
# リポジトリをTapに追加
brew tap HEHEX8/playcovermanager

# インストール
brew install --cask playcovermanager
```

### 方法2: GitHub Releases

1. [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)から最新の `PlayCoverManager.dmg` をダウンロード
2. DMGをマウント
3. PlayCoverManager.appを「アプリケーション」フォルダにドラッグ
4. 初回起動時は **右クリック → 「開く」** を選択

### 方法3: ソースからビルド

```bash
# リポジトリをクローン
git clone https://github.com/HEHEX8/PlayCoverManagerGUI.git
cd PlayCoverManagerGUI

# ビルド
./scripts/build_release_unsigned.sh
```

---

## 💻 動作環境

- **macOS**: 11.0 Big Sur以降
- **アーキテクチャ**: Apple Silicon / Intel両対応
- **必須**: PlayCoverがインストール済み

---

## 🎮 使い方

### 初回起動

1. PlayCover Managerを起動
2. セットアップウィザードが表示されます
3. PlayCoverの場所を選択
4. ディスクイメージの保存先を選択
5. 完了！

### アプリ起動

1. ランチャー画面でアプリを見つける
2. ダブルクリックで起動
3. または検索バーでアプリ名を入力して検索

### ストレージ管理

1. 設定（⚙️）を開く
2. 「一般」タブでディスク使用量を確認
3. 「保存先を変更」で別の場所に移動可能

---

## 🛠️ 開発

### プロジェクト構造

```
PlayCoverManagerGUI/
├── PlayCoverManager/           # メインアプリコード
│   ├── Views/                  # SwiftUI Views
│   ├── ViewModels/             # ViewModels
│   ├── Services/               # ビジネスロジック
│   ├── Models/                 # データモデル
│   └── Assets.xcassets/        # アセット
├── scripts/                    # ビルドスクリプト
├── homebrew/                   # Homebrew Cask formula
├── docs/                       # 開発ドキュメント
└── README.md                   # このファイル
```

### ビルドとテスト

```bash
# 開発用ビルド
./scripts/build_dev.sh

# リリース用ビルド
./scripts/build_release_unsigned.sh
```

### 技術スタック

- **言語**: Swift 5.9+
- **フレームワーク**: SwiftUI
- **最小ターゲット**: macOS 11.0
- **アーキテクチャ**: MVVM + Service Layer

---

## 📤 配布

このプロジェクトは **署名なし** で配布されています（個人製作のため）。

### GitHub Releasesでの配布

詳細は [DISTRIBUTION_FREE.md](DISTRIBUTION_FREE.md) を参照。

### Homebrew Caskでの配布

詳細は [homebrew/README.md](homebrew/README.md) を参照。

---

## 🤝 コントリビューション

プルリクエストを歓迎します！

### 貢献方法

1. このリポジトリをフォーク
2. フィーチャーブランチを作成 (`git checkout -b feature/amazing-feature`)
3. 変更をコミット (`git commit -m 'feat: Add amazing feature'`)
4. ブランチにプッシュ (`git push origin feature/amazing-feature`)
5. プルリクエストを作成

### 開発ドキュメント

- [開発メモ](docs/) - 実装詳細、バグフィックス履歴
- [配布ガイド](DISTRIBUTION_FREE.md) - リリース手順

---

## 📄 ライセンス

このプロジェクトは [MIT License](LICENSE) の下でライセンスされています。

---

## 🙏 謝辞

- [PlayCover](https://github.com/PlayCover/PlayCover) - iOSアプリをmacOSで実行可能にする素晴らしいプロジェクト
- SF Symbols - macOS標準アイコンセット

---

## 🔗 リンク

- [GitHub リポジトリ](https://github.com/HEHEX8/PlayCoverManagerGUI)
- [Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
- [PlayCover公式](https://github.com/PlayCover/PlayCover)

---

## 📸 スクリーンショット

### ランチャー画面
アプリ一覧、検索、起動機能

### セットアップウィザード
初回起動時の設定画面

### 設定画面
ストレージ管理、メンテナンス

*(スクリーンショット画像は後日追加予定)*

---

## ❓ FAQ

### Q: PlayCoverがインストールされていないとどうなる？
**A:** セットアップウィザードでPlayCoverの場所を指定するよう求められます。

### Q: アプリが起動しない場合は？
**A:** 以下を確認してください：
- PlayCoverが正しくインストールされているか
- ディスクイメージがマウントされているか
- アプリが削除されていないか

### Q: ディスク使用量が多い場合は？
**A:** 設定の「メンテナンス」タブからキャッシュクリアを実行してください。

### Q: 複数のPlayCoverアプリがある場合は？
**A:** 現在はPlayCover.appのみサポートしています。

---

## 🐛 問題報告

バグや機能リクエストは [GitHub Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues) で報告してください。

---

<div align="center">

Made with ❤️ for PlayCover users

[⬆ トップに戻る](#playcover-manager)

</div>
