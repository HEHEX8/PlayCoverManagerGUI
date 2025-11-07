# PlayCoverManager ビルドスクリプト

## 📁 スクリプト一覧

### `build_dev.sh` - 開発用ビルド
開発中のテスト用。署名なし。

**使用方法**:
```bash
./scripts/build_dev.sh
```

**出力**: `build/dev/Build/Products/Debug/PlayCoverManager.app`

---

### `build_release_unsigned.sh` - リリース用ビルド（無料配布）
GitHub Releases / Homebrew Cask配布用。署名なし。
appdmgが利用可能な場合は自動的に綺麗なDMGを作成します。

**使用方法**:
```bash
# appdmgをインストール（推奨）
npm install -g appdmg

# ビルド実行
./scripts/build_release_unsigned.sh
```

**出力**: 
- `build/release-unsigned/Build/Products/Release/PlayCoverManager.app`
- `build/release-unsigned/PlayCoverManager.dmg`
  - appdmgあり: プロフェッショナルな見た目
  - appdmgなし: シンプルなDMG（フォールバック）
- SHA256ハッシュ（Homebrew Cask用）
- 背景画像（自動生成）

---

### `create_dmg.sh` - スタンドアロンDMG作成（オプション）
`build_release_unsigned.sh` とは独立して、appdmgでDMGを作成します。

**前提条件**:
```bash
brew install node
npm install -g appdmg
```

**使用方法**:
```bash
# まず通常ビルド（またはXcodeでビルド）
./scripts/build_release_unsigned.sh

# スタンドアロンDMG作成
./scripts/create_dmg.sh
```

**出力**:
- `build/release-unsigned/PlayCoverManager-{VERSION}.dmg`

**特徴**:
- バージョン番号を自動取得
- 背景画像を自動生成（なければ）
- SHA256ハッシュを自動計算
- 完全な配布準備完了

---

### `create_dmg_background.sh` - DMG背景画像生成
Python + Pillow を使用して背景画像を自動生成します。
矢印付きで「ドラッグ&ドロップでインストール」を表示。

**前提条件**:
```bash
# Python 3（macOSに標準搭載）
# Pillow（自動インストール）
```

**使用方法**:
```bash
./scripts/create_dmg_background.sh
```

**出力**: `dmg-background.png` (600x400px)

**特徴**:
- appdmg推奨サイズ（600x400）
- 矢印とテキストで分かりやすい
- ヒラギノフォント使用（日本語）
- Pillow自動インストール

---

## 🚀 リリースフロー

### 1. ビルド
```bash
./scripts/build_release_unsigned.sh
```

表示されるSHA256ハッシュをメモ！

### 2. GitHub Release作成
```bash
# タグ作成
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

GitHub Releasesページで：
- https://github.com/HEHEX8/PlayCoverManagerGUI/releases/new
- DMGファイルをアップロード

### 3. Homebrew Cask更新（オプション）
`homebrew/playcovermanager.rb` を編集：
```ruby
version "1.0.0"        # 新しいバージョン
sha256 "abc123..."     # ステップ1のSHA256
```

コミット＆プッシュ：
```bash
git add homebrew/playcovermanager.rb
git commit -m "chore: Update Homebrew cask to v1.0.0"
git push origin main
```

---

## 📦 配布方法

### 方法1: GitHub Releases（基本）
ユーザー：
1. DMGをダウンロード
2. 右クリック → 「開く」で初回起動

### 方法2: Homebrew Cask（推奨）
ユーザー：
```bash
brew tap HEHEX8/playcovermanager
brew install --cask playcovermanager
```
自動でGatekeeper警告を回避！

---

## 💰 費用

**全て無料！** 🎉
- ❌ Apple Developer Program不要（$99/年）
- ❌ 署名不要
- ❌ 公証不要

---

## 📚 詳細ドキュメント

- [DISTRIBUTION_FREE.md](../DISTRIBUTION_FREE.md) - 無料配布ガイド
- [homebrew/README.md](../homebrew/README.md) - Homebrew Cask詳細
