# PlayCover Manager

<div align="center">

![PlayCover Manager Icon](PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png)

**GUI tool for managing PlayCover iOS apps on macOS**

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2026.0+-lightgrey.svg)](https://www.apple.com/macos/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[English](#english) | [日本語](#日本語)

</div>

---

## English

## Overview

PlayCover Manager is a GUI application for managing iOS apps installed via PlayCover on macOS. It provides an integrated interface for installing IPAs, launching apps, and managing storage.

### Features

- 🎯 IPA installer integration
- 🚀 Quick launcher with search
- 🗑️ Batch uninstaller
- 💾 ASIF disk image management
- 📦 External drive support
- ⌨️ Keyboard navigation

---

## Requirements

- **macOS 26.0 Tahoe or later** (ASIF format required)
- **Apple Silicon Mac** (Intel not supported)
- **PlayCover.app** (must be installed separately)

---

## Installation

### Download from Releases

1. Download `PlayCoverManager.dmg` from [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
2. Open DMG and drag to Applications folder
3. First launch: Right-click → "Open" (unsigned app)

### Build from Source

```bash
git clone https://github.com/HEHEX8/PlayCoverManagerGUI.git
cd PlayCoverManagerGUI
./scripts/build_release_unsigned.sh
```

**Requirements**: macOS 15.6+, Xcode 26.0+, Node.js (optional, for better DMG)

---

## Usage

### Initial Setup

1. Launch app (macOS version check)
2. Select PlayCover.app location
3. Select ASIF disk image storage location

### Install IPA

Click "Install IPA" → Select IPA file → Confirm → Install

### Launch Apps

- Double-click app icon
- Search and double-click
- Press Enter for recent app

### Uninstall

- **Single**: Right-click → "Uninstall"
- **Batch**: Click "Uninstaller" → Select apps → Execute

---

## Technical Details

- **Language**: Swift 6.0+
- **UI**: SwiftUI
- **Architecture**: MVVM + Service Layer
- **Storage**: ASIF (Apple Sparse Image Format)

### Project Structure

```
PlayCoverManager/
├── Views/          # SwiftUI views
├── ViewModels/     # State management
├── Services/       # Business logic
├── Models/         # Data models
└── Utilities/      # Helpers
```

---

## Compatibility Note

This is a complete rewrite of the [original CLI version](https://github.com/HEHEX8/PlayCoverManager). **No compatibility between versions** due to fundamentally different storage technologies (APFS volumes vs ASIF disk images).

---

## License

MIT License - See [LICENSE](LICENSE) for details

---

## Links

- [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
- [Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [PlayCover Official](https://github.com/PlayCover/PlayCover)

---

## 日本語

## 概要

PlayCover ManagerはmacOS上でPlayCover経由でインストールしたiOSアプリを管理するGUIアプリケーションです。IPAインストール、アプリ起動、ストレージ管理を統合インターフェースで提供します。

### 機能

- 🎯 IPAインストーラー統合
- 🚀 検索機能付きクイックランチャー
- 🗑️ 一括アンインストーラー
- 💾 ASIFディスクイメージ管理
- 📦 外部ドライブ対応
- ⌨️ キーボードナビゲーション

---

## 必須環境

- **macOS 26.0 Tahoe以降**（ASIF形式必須）
- **Apple Silicon Mac**（Intel非対応）
- **PlayCover.app**（別途インストール必須）

---

## インストール

### Releasesからダウンロード

1. [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)から`PlayCoverManager.dmg`をダウンロード
2. DMGを開いてアプリケーションフォルダへドラッグ
3. 初回起動：右クリック→「開く」（署名なしアプリのため）

### ソースからビルド

```bash
git clone https://github.com/HEHEX8/PlayCoverManagerGUI.git
cd PlayCoverManagerGUI
./scripts/build_release_unsigned.sh
```

**要件**：macOS 15.6+、Xcode 26.0+、Node.js（オプション、より良いDMG作成用）

---

## 使い方

### 初回セットアップ

1. アプリ起動（macOSバージョンチェック）
2. PlayCover.appの場所を選択
3. ASIFディスクイメージ保存先を選択

### IPAインストール

「IPAをインストール」をクリック → IPAファイルを選択 → 確認 → インストール

### アプリ起動

- アイコンをダブルクリック
- 検索してダブルクリック
- 最近使用したアプリはEnterキーで起動

### アンインストール

- **個別**：右クリック→「アンインストール」
- **一括**：「アンインストーラー」をクリック→アプリを選択→実行

---

## 技術詳細

- **言語**：Swift 6.0+
- **UI**：SwiftUI
- **アーキテクチャ**：MVVM + Service Layer
- **ストレージ**：ASIF (Apple Sparse Image Format)

### プロジェクト構造

```
PlayCoverManager/
├── Views/          # SwiftUIビュー
├── ViewModels/     # 状態管理
├── Services/       # ビジネスロジック
├── Models/         # データモデル
└── Utilities/      # ヘルパー
```

---

## 互換性について

本プロジェクトは[オリジナルCLI版](https://github.com/HEHEX8/PlayCoverManager)の完全リライトです。ストレージ技術が根本的に異なるため（APFSボリューム vs ASIFディスクイメージ）、**バージョン間の互換性はありません**。

---

## ライセンス

MIT License - 詳細は[LICENSE](LICENSE)を参照

---

## リンク

- [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases)
- [Issues](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [PlayCover公式](https://github.com/PlayCover/PlayCover)
