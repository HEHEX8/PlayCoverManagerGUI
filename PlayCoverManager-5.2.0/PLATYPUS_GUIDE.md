# Platypusを使った独立アプリ化ガイド

## 📋 概要

PlayCover Managerを**Terminal.appを使わない独立したアプリプロセス**として実行する方法です。

### 現在の問題点
- ❌ Terminal.app名義でプロセスが実行される
- ❌ Activity Monitorで"Terminal"として表示される
- ❌ macOSのセッション復元機能の影響を受ける

### Platypus版の利点
- ✅ PlayCover Manager名義の独立プロセス
- ✅ Terminal.appを全く使用しない
- ✅ Activity MonitorやDockで"PlayCover Manager"として表示
- ✅ 既存のzshスクリプトをそのまま使える
- ✅ Text Window UIでリアルタイム出力表示

---

## 🔧 Platypusのインストール

### 方法1: Homebrew（推奨）
```bash
brew install --cask platypus
```

### 方法2: 公式サイトからダウンロード
1. https://sveinbjorn.org/platypus にアクセス
2. 最新版をダウンロード
3. アプリケーションフォルダにドラッグ

### インストール確認
```bash
platypus -v
# Platypus 5.4 などと表示されればOK
```

---

## 🚀 ビルド方法

### ステップ1: Platypusをインストール
上記の方法でインストール

### ステップ2: アプリをビルド
```bash
cd /path/to/PlayCoverManager
./build-app-platypus.sh
```

### ステップ3: インストール
```bash
cp -r "build-platypus/PlayCover Manager.app" /Applications/
```

### ステップ4: 起動
```bash
open "/Applications/PlayCover Manager.app"
```

または、Finderから「PlayCover Manager.app」をダブルクリック

---

## 📊 動作の違い

### 従来版（Terminal.app使用）
```
ユーザーがアイコンをクリック
  ↓
Terminal.appが起動
  ↓
Terminal.app内でzsh main.shが実行
  ↓
プロセス名: Terminal
Activity Monitor表示: Terminal
```

### Platypus版（独立プロセス）
```
ユーザーがアイコンをクリック
  ↓
PlayCover Manager.appが起動
  ↓
内部でzsh main.shが実行（Terminal.appなし）
  ↓
プロセス名: PlayCover Manager
Activity Monitor表示: PlayCover Manager
```

---

## 🎨 UI設定

### Text Window（現在の設定）
- スクリプトの出力をリアルタイムで表示
- 背景色: #1C1C1C (ダークグレー)
- 文字色: #FFFFFF (白)
- フォント: Monaco 12pt

### カスタマイズ可能な項目
`build-app-platypus.sh`内で以下を変更可能：
- `InterfaceType`: Text Window / Progress Bar / Web View / Status Menu
- `TextBackground`: 背景色
- `TextForeground`: 文字色
- `TextFont`: フォントとサイズ
- `ShowInDock`: Dockに表示するか
- `RemainRunningAfterCompletion`: 終了後もウィンドウを開いたままにするか

---

## 🔍 トラブルシューティング

### Q: Platypusがインストールできない
**A:** Homebrewがない場合:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Q: ビルドエラーが出る
**A:** Platypusのバージョンを確認:
```bash
platypus -v
# 5.3以降が必要
```

古い場合は更新:
```bash
brew upgrade platypus
```

### Q: アプリが起動しない
**A:** macOSのセキュリティ設定を確認:
```bash
# Quarantine属性を削除
xattr -dr com.apple.quarantine "/Applications/PlayCover Manager.app"

# または、右クリック → 開く で初回起動
```

### Q: シングルインスタンス機能は動作する？
**A:** はい、main.sh内のロック機構がそのまま機能します。
```bash
# ロックファイルは同じ場所を使用
/tmp/playcover-manager-running.lock
```

---

## 📦 配布方法

### 方法1: .appファイルをZIP圧縮
```bash
cd build-platypus
zip -r "PlayCover Manager-5.2.0.zip" "PlayCover Manager.app"
```

### 方法2: DMG作成（推奨）
```bash
# create-dmg を使用
brew install create-dmg

create-dmg \
  --volname "PlayCover Manager" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --app-drop-link 600 185 \
  "PlayCover Manager-5.2.0.dmg" \
  "build-platypus/PlayCover Manager.app"
```

---

## 🆚 比較表

| 項目 | 従来版 (Terminal.app) | Platypus版 |
|------|---------------------|-----------|
| プロセス名 | Terminal | PlayCover Manager |
| Terminal.app使用 | ✅ 使用 | ❌ 不要 |
| セッション復元問題 | ⚠️ あり | ✅ なし |
| 独立したアプリ | ❌ | ✅ |
| Activity Monitor表示 | Terminal | PlayCover Manager |
| Dock表示 | Terminal | PlayCover Manager |
| ビルドの容易さ | 簡単 | Platypus必要 |
| 配布の容易さ | 簡単 | 要Platypusランタイム |

---

## 🎯 推奨事項

### 開発中
従来版（Terminal.app版）を使用
- デバッグが簡単
- ビルドが高速

### 配布用
Platypus版を使用
- ユーザー体験が向上
- プロフェッショナルな外観
- Terminal.appの設定に依存しない

---

## 📚 参考資料

- **Platypus公式サイト**: https://sveinbjorn.org/platypus
- **GitHubリポジトリ**: https://github.com/sveinbjornt/Platypus
- **ドキュメント**: https://sveinbjorn.org/platypus_documentation
- **CLI使用法**: `man platypus`

---

## ✅ チェックリスト

配布前に確認:
- [ ] Platypusでビルド成功
- [ ] アプリが起動する
- [ ] シングルインスタンス機能動作確認
- [ ] macOSセキュリティ設定で開ける
- [ ] Activity Monitorで"PlayCover Manager"と表示
- [ ] アプリを閉じて再起動できる
- [ ] 複数回クリックで既存ウィンドウがアクティブ化
