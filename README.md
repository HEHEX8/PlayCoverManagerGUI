# PlayCover Manager

<div align="center">

![PlayCover Manager Icon](PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png)

**macOS Tahoe 26.0+ 用 PlayCover アプリ統合管理ツール**

IPA インストール • アプリ起動 • ストレージ管理 • アンインストール

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2026.0%20Tahoe+-lightgrey.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## 📖 概要

**PlayCover Manager** は、PlayCover でインストールした iOS アプリを GUI で統合管理するツールです。

> **🔗 オリジナル版**: [PlayCoverManager (ZSH CLI版)](https://github.com/HEHEX8/PlayCoverManager) の完全リライト版。**互換性は全くありません。**

### 主な機能

- ✅ IPA インストーラー統合
- ✅ クイックランチャー（検索・起動）
- ✅ 一括アンインストーラー
- ✅ ASIF ディスクイメージ管理
- ✅ 外部ドライブ対応

---

## 🆚 オリジナル版との違い

| 項目 | ZSH CLI版 | GUI版（本プロジェクト） |
|------|----------|---------------------|
| **ストレージ** | APFS ボリューム（ディスク上） | ASIF ディスクイメージ（`.asif` ファイル） |
| **macOS要件** | Sequoia 15.1+ | **Tahoe 26.0+** |
| **マウント** | 手動（`mount -t apfs`） | 自動（`diskutil image attach`） |
| **マッピング** | TSV ファイル管理 | 不要（ファイル名=BundleID） |
| **起動管理** | 起動前に手動マウント | 自動マウント + プロセス監視 |

### 🚫 互換性

**オリジナル版と GUI 版に互換性は全くありません。**

- ストレージ技術が根本的に異なる（APFS vs ASIF）
- データ構造が完全に不一致（TSV vs ファイル名ベース）
- 移行ツールは提供しない

**どちらか一方を選択してください。両立不可。**

---

## ⚠️ 必須環境

- **macOS Tahoe 26.0+**（ASIF 形式必須）
- **Apple Silicon Mac 専用**（Intel 非対応）
- PlayCover.app（別途インストール必須）

---

## 📦 インストール

### 方法 1: GitHub Releases（推奨）

1. [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases) から `PlayCoverManager.dmg` をダウンロード
2. DMG をマウントして「アプリケーション」フォルダへドラッグ
3. 初回起動: 右クリック → 「開く」（署名なしアプリのため）

### 方法 2: ソースからビルド

```bash
git clone https://github.com/HEHEX8/PlayCoverManagerGUI.git
cd PlayCoverManagerGUI

# appdmg をインストール（推奨 - 綺麗なDMGを作成）
npm install -g appdmg

# アプリをビルド（DMGも自動作成）
./scripts/build_release_unsigned.sh
```

**要件**: 
- macOS Sequoia 15.6+
- Xcode 26.0+
- Node.js + appdmg（推奨）

---

## 🎮 使い方

### 初回セットアップ

1. アプリ起動（macOS バージョンチェック）
2. PlayCover.app の場所を選択
3. ASIF ディスクイメージ保存先を選択
4. 完了

### IPA インストール

1. 「IPA をインストール」ボタン → IPA 選択
2. 確認画面で内容確認 → 「インストール」
3. 完了後、ランチャーに表示

### アプリ起動

- ダブルクリックで起動
- 検索バーで検索 → ダブルクリック
- 最近起動アプリは Enter で起動

### アンインストール

- **個別**: 右クリック → 「アプリをアンインストール」
- **一括**: 「アンインストーラー」ボタン → チェック → 実行

---

## 🛠️ 技術スタック

- **言語**: Swift 6.0+
- **UI**: SwiftUI
- **ターゲット**: macOS 26.0 Tahoe
- **アーキテクチャ**: MVVM + Service Layer
- **ストレージ**: ASIF (Apple Sparse Image Format)

### プロジェクト構造

```
PlayCoverManager/
├── Views/          # SwiftUI ビュー
├── ViewModels/     # 状態管理
├── Services/       # ビジネスロジック
│   ├── DiskImageService.swift
│   ├── IPAInstallerService.swift
│   ├── LauncherService.swift
│   └── AppUninstallerService.swift
├── Models/         # データモデル
└── Utilities/      # ヘルパー
```

---

## ❓ FAQ

**Q: なぜ macOS 26 Tahoe が必須？**  
A: ASIF ディスクイメージは Tahoe 26.0 で導入された新形式です。

**Q: Sequoia 15.x で動く？**  
A: いいえ。Tahoe 26.0+ 必須です。

**Q: Intel Mac は？**  
A: 非対応。Apple Silicon 専用です（PlayCover の制約）。

**Q: オリジナル版から移行できる？**  
A: いいえ。完全に非互換です。移行ツールも提供しません。

---

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照

---

## 🔗 リンク

- [GitHub](https://github.com/HEHEX8/PlayCoverManagerGUI)
- [Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
- [PlayCover 公式](https://github.com/PlayCover/PlayCover)
- [オリジナル ZSH版](https://github.com/HEHEX8/PlayCoverManager)

---

<div align="center">

Made with ❤️ for PlayCover users on macOS Tahoe

</div>
