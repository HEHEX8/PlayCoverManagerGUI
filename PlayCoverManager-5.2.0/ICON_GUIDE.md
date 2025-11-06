# アイコン作成ガイド

PlayCover Manager のカスタムアイコンを作成する方法を説明します。

---

## 📋 前提条件

- **macOS** 環境（`sips` と `iconutil` コマンドが必要）
- ソース画像（PNG または JPEG、推奨サイズ: 1024x1024px 以上）

---

## 🎨 アイコン作成手順

### 1. ソース画像を配置

プロジェクトルートに `app-icon.png` を配置してください：

```bash
# ファイルが存在することを確認
ls -lh app-icon.png
```

**推奨仕様:**
- **形式**: PNG（透過背景対応）
- **サイズ**: 1024x1024px 以上
- **アスペクト比**: 1:1（正方形）

---

### 2. アイコン生成スクリプトを実行

macOS 上で以下のコマンドを実行：

```bash
./create-icon.sh
```

**スクリプトが実行する処理:**
1. `AppIcon.iconset` ディレクトリを作成
2. `sips` コマンドで10種類のサイズを生成:
   - 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, 1024x1024
   - Retina ディスプレイ用の @2x バージョン
3. `iconutil` で `.icns` ファイルに変換
4. `AppIcon.icns` をプロジェクトルートに出力

**成功時の出力例:**
```
🎨 app-icon.png からmacOSアイコンを作成中...

📋 検出されたフォーマット: PNG

📁 AppIcon.iconset ディレクトリを作成中...
🔧 アイコンサイズを生成中...
✅ 10個のアイコンサイズを生成しました
🔍 生成されたアイコンを検証中...
✅ 全てのアイコンを検証しました
🎨 .icnsフォーマットに変換中...
✅ AppIcon.icnsの作成に成功しました！

📦 次のステップ:
   1. ./build-app-standalone.sh を実行して新しいアイコンでアプリを再ビルド
   2. アイコンは自動的にアプリバンドルに含まれます

-rw-r--r--  1 user  staff   91K Oct 31 12:00 AppIcon.icns
AppIcon.icns: Mac OS X icon, 512x512, 256x256, 128x128, 64x64, 32x32, 16x16
```

---

### 3. アプリをビルド

アイコンが生成されたら、アプリを（再）ビルドします：

```bash
# Standalone版（推奨）
./build-app-standalone.sh

# または Terminal版
./build-app.sh
```

**ビルドスクリプトは自動的に:**
- `AppIcon.icns` が存在する場合 → `.icns` をコピー
- `AppIcon.icns` が存在しない場合 → 警告を表示

---

### 4. 確認

ビルドされたアプリにアイコンが含まれているか確認：

```bash
# Standalone版の場合
ls -lh "build-standalone/PlayCover Manager.app/Contents/Resources/AppIcon.icns"

# Terminal版の場合
ls -lh "build/PlayCover Manager.app/Contents/Resources/AppIcon.icns"
```

Finder でアプリを開いて、アイコンが表示されることを確認：

```bash
# Standalone版
open build-standalone/

# Terminal版
open build/
```

---

## 🔧 トラブルシューティング

### アイコンが生成されない

**エラー: `sips` や `iconutil` コマンドが見つからない**

→ macOS 上で実行してください。これらはmacOS専用コマンドです。

**エラー: PNG ファイルが破損している**

```bash
# ファイル形式を確認
file app-icon.png

# ImageMagick で PNG を再変換（インストール済みの場合）
convert app-icon.png -resize 1024x1024 app-icon-fixed.png
mv app-icon-fixed.png app-icon.png
```

---

### アイコンがアプリに表示されない

**1. AppIcon.icns が存在するか確認**

```bash
ls -lh AppIcon.icns
```

存在しない場合 → `./create-icon.sh` を実行

**2. ビルドされたアプリに含まれているか確認**

```bash
ls -lh "build-standalone/PlayCover Manager.app/Contents/Resources/"
```

`AppIcon.icns` が存在しない場合 → アプリを再ビルド

**3. Info.plist に CFBundleIconFile が設定されているか確認**

```bash
grep -A1 "CFBundleIconFile" "build-standalone/PlayCover Manager.app/Contents/Info.plist"
```

出力例:
```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

なければ最新版をプル: `git pull origin main`

**4. Finder のキャッシュをクリア**

```bash
# Finder のアイコンキャッシュをリセット
sudo rm -rf /Library/Caches/com.apple.iconservices.store
killall Finder
```

---

## 🎨 カスタムデザインのヒント

### 推奨デザイン

- **明確なシルエット**: 小さいサイズ（16x16）でも認識可能
- **適度なパディング**: 端まで描画せず、余白を確保
- **シンプルな配色**: 複雑すぎない色使い
- **透過背景**: PNG の透過機能を活用

### デザインツール

- **Figma** / **Sketch**: プロフェッショナルなデザイン
- **GIMP** / **Inkscape**: 無料のオープンソースツール
- **macOS プレビュー.app**: 簡単な編集とリサイズ

---

## 📦 DMG インストーラーへの統合

アイコンは DMG インストーラーにも使用されます：

```bash
# DMG 背景画像を生成
./create-dmg-background-simple.sh

# DMG インストーラーを作成（Standalone版）
./create-dmg-standalone.sh

# または Terminal版
./create-dmg-appdmg.sh
```

DMG インストーラーでは、以下にアイコンが使用されます：
- アプリのアイコン表示
- DMG ボリュームのアイコン

---

## 🔗 関連ドキュメント

- [README.md](README.md) - プロジェクト概要とビルド手順
- [STANDALONE_BUILD.md](STANDALONE_BUILD.md) - Standalone版の詳細
- [DMG-APPDMG-GUIDE.md](DMG-APPDMG-GUIDE.md) - DMG作成ガイド
- [RELEASE-DMG-GUIDE.md](RELEASE-DMG-GUIDE.md) - リリース手順

---

## 📝 まとめ

1. **ソース画像を配置**: `app-icon.png` (1024x1024px 推奨)
2. **アイコン生成**: `./create-icon.sh` → `AppIcon.icns` 作成
3. **アプリビルド**: `./build-app-standalone.sh`
4. **確認**: Finder でアイコン表示を確認

これで PlayCover Manager に独自のアイコンが設定されます！
