# リリース手順

このドキュメントは PlayCover Manager の新バージョンをリリースする手順を説明します。

## 前提条件

- macOS Sequoia 15.6+ または Tahoe 26.0+
- Xcode 26.0+
- Git
- GitHub アカウントとリポジトリへのアクセス権

## リリースフロー

### 1. バージョン番号の決定

セマンティックバージョニングに従います：

- **メジャー (X.0.0)**: 互換性のない変更
- **マイナー (x.Y.0)**: 後方互換性のある新機能
- **パッチ (x.y.Z)**: 後方互換性のあるバグ修正

### 2. コードの準備

```bash
# 最新のmainブランチに切り替え
git checkout main
git pull origin main

# バージョン番号を更新（Xcodeで）
# PlayCoverManager.xcodeproj > TARGETS > PlayCoverManager > General > Version
# 例: 1.0.0

# デバッグコードのクリーンアップ確認
grep -r "print(" --include="*.swift" PlayCoverManager/ | wc -l
# → 0 であることを確認
```

### 3. リリースビルドの作成

```bash
# リリースビルドを実行
./scripts/build_release_unsigned.sh

# ビルド成功を確認
ls -lh build/Release/PlayCoverManager.app
```

### 4. DMG の作成

#### 前提条件

appdmg ツールが必要です：

```bash
# Node.js をインストール（未インストールの場合）
brew install node

# appdmg をグローバルにインストール
npm install -g appdmg
```

#### DMG 作成

```bash
# DMGを作成（appdmgを使用）
./scripts/create_dmg.sh

# DMG が作成されたことを確認
ls -lh build/PlayCoverManager-*.dmg

# SHA256ハッシュを取得（Homebrew Caskで使用）
shasum -a 256 build/PlayCoverManager-*.dmg
```

**注意**: 
- スクリプトは自動的にバージョン番号を Info.plist から取得します
- 出力ファイル名: `PlayCoverManager-{VERSION}.dmg`
- 背景画像は オプション（なくても動作します）

### 5. GitHub Release の作成

#### 5.1 タグの作成とプッシュ

```bash
# バージョンタグを作成（例: v1.0.0）
VERSION="1.0.0"
git tag -a "v${VERSION}" -m "Release v${VERSION}"
git push origin "v${VERSION}"
```

#### 5.2 GitHub Releases ページで Release を作成

1. GitHub リポジトリの [Releases](https://github.com/HEHEX8/PlayCoverManagerGUI/releases) ページを開く
2. 「Draft a new release」をクリック
3. 以下を入力：

**Tag**: `v1.0.0` (作成したタグを選択)

**Release title**: `PlayCover Manager v1.0.0`

**Description**: 以下のテンプレートを使用

```markdown
## 📦 PlayCover Manager v1.0.0

macOS Tahoe 26.0+ 用 PlayCover アプリ統合管理ツールの最初のリリースです。

### ✨ 主な機能

- ✅ IPA インストーラー統合
- ✅ クイックランチャー（検索・起動）
- ✅ 一括アンインストーラー
- ✅ ASIF ディスクイメージ管理
- ✅ 外部ドライブ対応
- ✅ キーボードナビゲーション

### 🐛 バグ修正

- macOS Sonoma/Sequoia のフォーカス喪失バグの回避策を実装
- シート・オーバーレイを閉じた後の操作不能問題を修正

### 📋 システム要件

- **macOS**: Tahoe 26.0 以降 (ASIF 必須)
- **アーキテクチャ**: Apple Silicon (arm64) 専用
- **依存**: PlayCover.app (別途インストール必須)

### 📥 インストール方法

#### 方法 1: DMG から (推奨)

1. `PlayCoverManager.dmg` をダウンロード
2. DMG をマウントして「アプリケーション」フォルダへドラッグ
3. 初回起動: 右クリック → 「開く」

#### 方法 2: Homebrew

```bash
# Tap を追加（初回のみ）
brew tap HEHEX8/playcover-manager

# インストール
brew install --cask playcover-manager
```

### 🔗 リンク

- [ドキュメント](https://github.com/HEHEX8/PlayCoverManagerGUI/blob/main/README.md)
- [Issue 報告](https://github.com/HEHEX8/PlayCoverManagerGUI/issues)
- [PlayCover 公式](https://github.com/PlayCover/PlayCover)

### 📝 注意事項

- オリジナル [ZSH CLI版](https://github.com/HEHEX8/PlayCoverManager) とは完全に非互換です
- APFS ボリュームではなく ASIF ディスクイメージを使用します
- 移行ツールは提供しません

---

**Full Changelog**: https://github.com/HEHEX8/PlayCoverManagerGUI/commits/v1.0.0
```

4. **Assets** セクションに `PlayCoverManager.dmg` をアップロード
5. 「Publish release」をクリック

### 6. Homebrew Cask の更新

リリース後、Homebrew Cask ファイルを更新します：

```bash
# SHA256ハッシュを取得（前の手順で取得済み）
SHA256=$(shasum -a 256 build/PlayCoverManager.dmg | awk '{print $1}')

# playcover-manager.rb を更新
# version と sha256 を更新
```

**playcover-manager.rb**:
```ruby
cask "playcover-manager" do
  version "1.0.0"  # ← 更新
  sha256 "abc123..." # ← 実際のSHA256に更新
  
  url "https://github.com/HEHEX8/PlayCoverManagerGUI/releases/download/v#{version}/PlayCoverManager.dmg"
  # ... 以下同じ
end
```

### 7. Tap リポジトリの更新（オプション）

個人 Homebrew Tap を作成する場合：

```bash
# 新しいリポジトリを作成
# 名前: homebrew-playcover-manager

# Cask ファイルをプッシュ
mkdir -p Casks
cp playcover-manager.rb Casks/
git add Casks/playcover-manager.rb
git commit -m "Add PlayCover Manager v1.0.0"
git push origin main
```

ユーザーは以下でインストール可能：
```bash
brew tap HEHEX8/playcover-manager
brew install --cask playcover-manager
```

## リリース後の確認事項

- [ ] GitHub Release ページでダウンロード可能か確認
- [ ] DMG をダウンロードしてインストールテスト
- [ ] Homebrew Cask でのインストールテスト（Tap 作成後）
- [ ] README.md のリンクが正しいか確認
- [ ] Issue が報告された場合は対応

## トラブルシューティング

### ビルドが失敗する

```bash
# クリーンビルド
xcodebuild clean -project PlayCoverManager.xcodeproj -scheme PlayCoverManager -configuration Release
./scripts/build_release_unsigned.sh
```

### DMG 作成が失敗する

#### appdmg がインストールされていない

```bash
# Node.js をインストール
brew install node

# appdmg をインストール
npm install -g appdmg

# 再実行
./scripts/create_dmg.sh
```

#### appdmg でエラーが発生する

```bash
# appdmg を再インストール
npm uninstall -g appdmg
npm cache clean --force
npm install -g appdmg

# 一時ファイルを削除
rm -f appdmg-config.json

# 再実行
./scripts/create_dmg.sh
```

#### アイコンが見つからないエラー

```bash
# アイコンファイルの存在を確認
ls -la PlayCoverManager/Assets.xcassets/AppIcon.appiconset/icon_512x512.png

# なければ、Xcodeでアセットカタログを確認
open PlayCoverManager.xcodeproj
```

### GitHub Actions で自動化（将来）

将来的には `.github/workflows/release.yml` を作成して自動化を検討：

```yaml
name: Release
on:
  push:
    tags:
      - 'v*'
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: ./scripts/build_release_unsigned.sh
      - name: Create DMG
        run: ./scripts/create_dmg.sh
      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: build/PlayCoverManager.dmg
```

## 参考リンク

- [セマンティックバージョニング](https://semver.org/lang/ja/)
- [GitHub Releases ドキュメント](https://docs.github.com/ja/repositories/releasing-projects-on-github)
- [Homebrew Cask ドキュメント](https://docs.brew.sh/Cask-Cookbook)
