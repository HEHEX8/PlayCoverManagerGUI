# PlayCover Manager - Standalone Build Guide

## 概要

`build-app-standalone.sh` は、Terminal.app に依存しない **独立したmacOSアプリケーション** を作成します。

### 特徴

✅ **独立プロセス**: Terminal.app を介さずに実行  
✅ **Activity Monitor**: "PlayCover Manager" として表示  
✅ **Dock**: PlayCover Manager アイコンとして表示  
✅ **外部ツール不要**: Platypus などのツールが不要  
✅ **配布可能**: そのまま配布可能な .app バンドル  
✅ **シングルインスタンス**: 複数起動を防止  

---

## ビルド方法

### 1. ビルドスクリプトの実行

```bash
cd /path/to/playcover-manager
./build-app-standalone.sh
```

### 2. 出力先

```
build-standalone/
└── PlayCover Manager.app/
    ├── Contents/
    │   ├── Info.plist          # アプリメタデータ
    │   ├── PkgInfo             # バンドル識別子
    │   ├── MacOS/
    │   │   └── PlayCoverManager    # 実行可能ファイル（zshスクリプト）
    │   └── Resources/
    │       ├── main.sh             # メインスクリプト
    │       ├── lib/                # 機能モジュール
    │       └── AppIcon.png         # アプリアイコン
```

---

## テスト方法

### 1. ターミナルから起動

```bash
open 'build-standalone/PlayCover Manager.app'
```

### 2. Finderからダブルクリック

```bash
open build-standalone
```

Finder で `PlayCover Manager.app` をダブルクリック

### 3. プロセス確認

```bash
# 実行中のプロセスを確認
ps aux | grep 'PlayCover Manager'

# Activity Monitor で確認
open -a "Activity Monitor"
```

**期待される表示**: `PlayCover Manager` （Terminal ではない）

### 4. ログ確認

```bash
# ランチャーログ
cat /tmp/playcover-manager-standalone.log

# ログをリアルタイム監視
tail -f /tmp/playcover-manager-standalone.log
```

---

## 動作原理

### アーキテクチャ

```
ユーザーのダブルクリック
    ↓
macOS (LaunchServices)
    ↓
Info.plist を読み取り → CFBundleExecutable: PlayCoverManager
    ↓
Contents/MacOS/PlayCoverManager を実行（zshスクリプト）
    ↓
1. シングルインスタンスチェック
2. ロックファイル作成
3. プロセス名を "PlayCover Manager" に設定（exec -a）
4. main.sh を実行（インタラクティブモード）
```

### プロセス名の設定

```zsh
# exec -a でプロセス名を明示的に指定
exec -a "PlayCover Manager" /bin/zsh <<'MAIN_SCRIPT'
    # メインスクリプトの実行
    source "${RESOURCES_DIR}/main.sh"
MAIN_SCRIPT
```

これにより、Activity Monitor で "PlayCover Manager" と表示されます。

### シングルインスタンス機能

```zsh
LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager-running.lock"

# 1. ロックファイルの存在確認
# 2. stale ロックの検出（プロセスが存在しない場合）
# 3. 既存インスタンスをアクティベート
# 4. 新規インスタンスの起動を中止
```

---

## トラブルシューティング

### 問題 1: アプリが起動しない

**症状**: ダブルクリックしても何も起こらない

**解決策**:

```bash
# 1. ログを確認
cat /tmp/playcover-manager-standalone.log

# 2. ターミナルから直接実行してエラーを確認
/path/to/build-standalone/PlayCover\ Manager.app/Contents/MacOS/PlayCoverManager

# 3. 実行権限を確認
ls -la build-standalone/PlayCover\ Manager.app/Contents/MacOS/PlayCoverManager

# 4. 実行権限を付与（必要な場合）
chmod +x build-standalone/PlayCover\ Manager.app/Contents/MacOS/PlayCoverManager
```

### 問題 2: "アプリが壊れている" と表示される

**症状**: macOS が「開発元を検証できません」と警告

**原因**: Quarantine 属性

**解決策**:

```bash
# Quarantine 属性を削除
xattr -cr 'build-standalone/PlayCover Manager.app'

# または、システム環境設定から許可
# システム環境設定 > セキュリティとプライバシー > 一般 > "このまま開く"
```

### 問題 3: Activity Monitor で "zsh" と表示される

**症状**: プロセス名が "PlayCover Manager" でなく "zsh"

**原因**: `exec -a` が正常に動作していない

**解決策**:

このバージョンでは `exec -a` でプロセス名を設定していますが、macOS の一部バージョンでは期待通りに動作しない場合があります。

**代替案**: Swift/Objective-C ラッパーを使用（将来のバージョンで実装予定）

### 問題 4: 複数のインスタンスが起動してしまう

**症状**: ダブルクリックするたびに新しいウィンドウが開く

**原因**: ロックファイルの動作不良

**解決策**:

```bash
# 1. 既存のロックファイルを削除
rm -f /tmp/playcover-manager-running.lock

# 2. すべてのインスタンスを終了
pkill -f "PlayCover Manager"

# 3. 再度起動
open 'build-standalone/PlayCover Manager.app'
```

---

## 配布方法

### 1. ZIP ファイルの作成

```bash
cd build-standalone
zip -r "PlayCover-Manager-5.2.0.zip" "PlayCover Manager.app"
```

### 2. DMG ファイルの作成（推奨）

```bash
# create-dmg を使用（要インストール）
brew install create-dmg

create-dmg \
  --volname "PlayCover Manager 5.2.0" \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "PlayCover Manager.app" 150 180 \
  --hide-extension "PlayCover Manager.app" \
  --app-drop-link 450 180 \
  "PlayCover-Manager-5.2.0.dmg" \
  "build-standalone/"
```

### 3. GitHub Releases にアップロード

```bash
# GitHub CLI を使用
gh release create v5.2.0 \
  "build-standalone/PlayCover-Manager-5.2.0.zip" \
  --title "PlayCover Manager v5.2.0" \
  --notes "Standalone app release"
```

---

## エンドユーザーへの案内

### インストール手順

1. **ダウンロード**: `PlayCover-Manager-5.2.0.zip` をダウンロード
2. **展開**: ZIP ファイルをダブルクリックして展開
3. **移動**: `PlayCover Manager.app` を「アプリケーション」フォルダにドラッグ
4. **初回起動**:
   - アプリをダブルクリック
   - 「開発元を検証できません」と表示された場合:
     - **Control + クリック** → 「開く」を選択
     - または、システム環境設定 > セキュリティとプライバシー > 「このまま開く」

### 使用方法

- **起動**: `PlayCover Manager.app` をダブルクリック
- **終了**: メニューから終了、または Command+Q
- **再起動**: もう一度ダブルクリック（既存のインスタンスがアクティブになります）

---

## 技術的な制限事項

### ✅ 実装済み機能

- ✅ 独立プロセスとしての実行
- ✅ シングルインスタンス機能
- ✅ 既存インスタンスのアクティベーション
- ✅ ログ記録機能
- ✅ エラーハンドリング

### ⚠️ 既知の制限

1. **プロセス名の表示**:
   - `exec -a` によるプロセス名設定は環境依存
   - 一部のmacOSバージョンでは "zsh" と表示される可能性

2. **Dockアイコン**:
   - デフォルトのスクリプトアイコンが表示される
   - カスタムアイコンは icns 形式が必要（PNG未対応）

3. **署名とPublic Notarization**:
   - 未署名アプリのため、初回起動時に警告が表示される
   - Developer ID 署名が必要（Apple Developer Program 加入必須）

---

## 将来の改善案

### 短期（次のリリース）

- [ ] icns 形式のアプリアイコン作成
- [ ] 自動アップデート機能
- [ ] より詳細なエラーメッセージ

### 長期

- [ ] Swift/Objective-C ラッパーの実装（確実なプロセス名表示）
- [ ] Developer ID 署名の自動化
- [ ] Notarization 対応
- [ ] メニューバーアイコン対応

---

## 比較: Terminal版 vs Standalone版

| 項目 | Terminal版 (build-app.sh) | Standalone版 (build-app-standalone.sh) |
|------|---------------------------|------------------------------------------|
| **プロセス名** | Terminal | PlayCover Manager |
| **Dockアイコン** | Terminal アイコン | PlayCover Manager アイコン |
| **Activity Monitor** | Terminal として表示 | PlayCover Manager として表示 |
| **外部依存** | Terminal.app | なし |
| **配布** | そのまま配布可能 | そのまま配布可能 |
| **シングルインスタンス** | ✅ 実装済み | ✅ 実装済み |
| **ビルド速度** | 高速 | 高速 |
| **メンテナンス性** | 高い | 高い |

**推奨**: **Standalone版** を使用してください（独立アプリとして動作）

---

## 参考資料

- [Apple - Bundle Programming Guide](https://developer.apple.com/library/archive/documentation/CoreFoundation/Conceptual/CFBundles/Introduction/Introduction.html)
- [Apple - Information Property List Key Reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Introduction/Introduction.html)
- [zsh Documentation](https://zsh.sourceforge.io/Doc/Release/)

---

## サポート

問題が発生した場合:

1. **ログを確認**: `/tmp/playcover-manager-standalone.log`
2. **GitHub Issues**: [プロジェクトのIssuesページ](https://github.com/your-username/playcover-manager/issues)
3. **デバッグモード**: ランチャースクリプトを直接実行してエラーを確認

---

**最終更新**: 2025-10-31  
**バージョン**: 5.2.0
