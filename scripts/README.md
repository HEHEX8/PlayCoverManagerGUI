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
シンプルなDMGを自動作成します。

**使用方法**:
```bash
./scripts/build_release_unsigned.sh
```

**出力**: 
- `build/release-unsigned/Build/Products/Release/PlayCoverManager.app`
- `build/release-unsigned/PlayCoverManager.dmg` (シンプルなDMG)
- SHA256ハッシュ（Homebrew Cask用）

---

### `create_dmg.sh` - カスタムDMG作成（オプション）
appdmgを使用して見た目の良いDMGを作成します。
`build_release_unsigned.sh` 実行後に使用可能。

**前提条件**:
```bash
brew install node
npm install -g appdmg
```

**使用方法**:
```bash
# まず通常ビルド
./scripts/build_release_unsigned.sh

# 次にカスタムDMG作成
./scripts/create_dmg.sh
```

**出力**:
- `build/release-unsigned/PlayCoverManager-{VERSION}-appdmg.dmg`

**特徴**:
- アイコンが綺麗に配置される
- Finderウィンドウのレイアウトが統一
- プロフェッショナルな見た目

---

### `create_dmg_background.sh` - DMG背景画像生成（オプション）
ImageMagickを使用して背景画像を生成します。

**前提条件**:
```bash
brew install imagemagick
```

**使用方法**:
```bash
./scripts/create_dmg_background.sh
```

**出力**: `dmg-background.png` (600x400px)

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
