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
# appdmgをインストール（推奨 - 綺麗なDMGを自動作成）
npm install -g appdmg

# リリースビルドを実行（DMGも自動作成）
./scripts/build_release_unsigned.sh

# ビルド成功を確認
ls -lh build/release-unsigned/Build/Products/Release/PlayCoverManager.app
ls -lh build/release-unsigned/PlayCoverManager.dmg
```

**注意**: 
- appdmgがインストールされていれば、プロフェッショナルな見た目のDMGを自動作成
- appdmgがなければ、シンプルなDMGを作成（フォールバック）
- 背景画像も自動生成されます

### 4. DMG の確認

`build_release_unsigned.sh` がDMGを自動作成しています。
SHA256ハッシュも表示されているので、それをメモしてください。

#### スタンドアロンでDMG作成する場合（オプション）

別途DMGを作り直したい場合：

```bash
# スタンドアロンDMG作成
./scripts/create_dmg.sh

# DMG が作成されたことを確認
ls -lh build/release-unsigned/PlayCoverManager-*.dmg
```

**メモ**: 
- `build_release_unsigned.sh` のDMGで十分配布可能です
- `create_dmg.sh` は独立して実行でき、SHA256も自動計算します

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

1. `PlayCoverManager.dmg` をダウンロード
2. DMG をマウントして「アプリケーション」フォルダへドラッグ
3. 初回起動: 右クリック → 「開く」

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

## リリース後の確認事項

- [ ] GitHub Release ページでダウンロード可能か確認
- [ ] DMG をダウンロードしてインストールテスト
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
