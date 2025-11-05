# Standalone版 テストガイド

## 📋 テスト環境

- **必須**: macOS 10.15 (Catalina) 以降
- **推奨**: macOS 15.1 (Sequoia) 以降
- **アーキテクチャ**: Intel または Apple Silicon

---

## 🧪 テスト手順

### Phase 1: ビルドの検証

#### 1.1 ビルドスクリプトの実行

```bash
cd /path/to/PlayCoverManager
./build-app-standalone.sh
```

**期待される出力**:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PlayCover Manager - Standalone App Builder v5.2.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ️  .app バンドル構造を作成中...
✅ ディレクトリ構造作成完了
ℹ️  Info.plist を生成中...
✅ Info.plist 生成完了
...
✅ アプリケーションが正常に作成されました

📦 出力先: build-standalone/PlayCover Manager.app
```

**チェックポイント**:
- [ ] ビルドがエラーなく完了する
- [ ] `build-standalone/PlayCover Manager.app` が存在する
- [ ] 出力に全ての ✅ が表示される

#### 1.2 .appバンドル構造の確認

```bash
ls -la "build-standalone/PlayCover Manager.app/Contents/"
```

**期待される構造**:
```
Contents/
├── Info.plist
├── PkgInfo
├── MacOS/
│   └── PlayCoverManager    (実行可能、権限: -rwxr-xr-x)
└── Resources/
    ├── main.sh
    ├── lib/
    └── AppIcon.png
```

**チェックポイント**:
- [ ] `MacOS/PlayCoverManager` が実行可能（`-rwxr-xr-x`）
- [ ] `Info.plist` が存在し、正しい形式
- [ ] `Resources/` にすべてのファイルが存在

---

### Phase 2: 起動テスト

#### 2.1 ターミナルからの起動

```bash
open 'build-standalone/PlayCover Manager.app'
```

**期待される動作**:
1. アプリが起動する
2. ウィンドウが表示される（または Terminal ウィンドウが開く）
3. PlayCover Manager のメニューが表示される

**チェックポイント**:
- [ ] アプリが起動する
- [ ] エラーメッセージが表示されない
- [ ] メニューが正しく表示される

#### 2.2 ログの確認

```bash
cat /tmp/playcover-manager-standalone.log
```

**期待されるログ**:
```
===== PlayCover Manager Standalone Launch =====
Launch Time: Fri Oct 31 02:48:32 UTC 2025
Bundle Path: /path/to/build-standalone/PlayCover Manager.app/Contents
Created lock file with PID: 12345
Resources Directory: /path/to/build-standalone/PlayCover Manager.app/Contents/Resources
Main Script: /path/to/build-standalone/PlayCover Manager.app/Contents/Resources/main.sh
```

**チェックポイント**:
- [ ] ログファイルが作成される
- [ ] エラーメッセージがない
- [ ] PIDが正しく記録される

---

### Phase 3: プロセス確認（最重要）

#### 3.1 Activity Monitor での確認

```bash
# Activity Monitor を開く
open -a "Activity Monitor"

# または、psコマンドで確認
ps aux | grep -i "playcover"
```

**期待される表示**:
- **プロセス名**: `PlayCover Manager` （❌ `zsh` や `Terminal` ではない）
- **PID**: 数値が表示される
- **CPU**: 実行中の値
- **メモリ**: 使用量が表示される

**チェックポイント**:
- [ ] Activity Monitor で "PlayCover Manager" が表示される
- [ ] "Terminal" や "zsh" として表示されない
- [ ] プロセスが正常に実行されている

#### 3.2 Dockの確認

**期待される動作**:
- Dockに **PlayCover Manager** のアイコンが表示される
- Terminal のアイコンは表示されない（Terminal版と異なる）

**チェックポイント**:
- [ ] Dockに PlayCover Manager アイコンが表示される
- [ ] Terminal アイコンは表示されない

---

### Phase 4: シングルインスタンステスト（重要）

#### 4.1 複数起動の試行

1. **最初のインスタンスを起動**:
   ```bash
   open 'build-standalone/PlayCover Manager.app'
   ```

2. **2回目のダブルクリック**:
   ```bash
   open 'build-standalone/PlayCover Manager.app'
   ```

**期待される動作**:
- 2回目のクリック時に新しいウィンドウが開かない
- 既存のウィンドウが前面に表示される
- 通知: "PlayCover Manager は既に実行中です" が表示される（macOS 通知）

**チェックポイント**:
- [ ] 2回目の起動で新しいウィンドウが開かない
- [ ] 既存のウィンドウがアクティブになる
- [ ] 通知が表示される（環境により表示されない場合もある）

#### 4.2 ロックファイルの確認

```bash
# ロックファイルの内容を確認
cat /tmp/playcover-manager-running.lock

# プロセスIDの存在確認
ps -p $(cat /tmp/playcover-manager-running.lock)
```

**期待される動作**:
- ロックファイルに有効なPIDが記録されている
- `ps -p` でプロセスが確認できる

**チェックポイント**:
- [ ] ロックファイルが存在する
- [ ] PIDが正しく記録されている
- [ ] プロセスが実行中である

#### 4.3 終了後のクリーンアップ

1. アプリを終了（Command+Q または メニューから終了）
2. ロックファイルを確認:
   ```bash
   ls -la /tmp/playcover-manager-running.lock
   ```

**期待される動作**:
- ロックファイルが自動的に削除される

**チェックポイント**:
- [ ] 終了後にロックファイルが削除される
- [ ] 再起動時に正常に起動する

---

### Phase 5: 配布テスト

#### 5.1 ZIP ファイルの作成

```bash
cd build-standalone
zip -r "PlayCover-Manager-5.2.0-Standalone.zip" "PlayCover Manager.app"
```

**チェックポイント**:
- [ ] ZIP ファイルが作成される
- [ ] ファイルサイズが適切（約150-200KB）

#### 5.2 展開テスト

```bash
# 別のディレクトリで展開
mkdir -p ~/Desktop/test-distribution
cp PlayCover-Manager-5.2.0-Standalone.zip ~/Desktop/test-distribution/
cd ~/Desktop/test-distribution/
unzip PlayCover-Manager-5.2.0-Standalone.zip
```

**チェックポイント**:
- [ ] ZIP が正常に展開される
- [ ] .app バンドルの構造が保持される
- [ ] 実行権限が保持される

#### 5.3 Quarantine 属性のテスト

```bash
# Quarantine 属性を確認
xattr -l "PlayCover Manager.app"
```

**期待される動作**:
- `com.apple.quarantine` 属性が存在しない（ビルド時に削除済み）
- または、初回起動時に警告が表示される

**チェックポイント**:
- [ ] Quarantine 属性が除去されている
- [ ] または、警告を受け入れて起動できる

---

## ❌ トラブルシューティング

### 問題 1: プロセス名が "zsh" と表示される

**原因**: `exec -a` が正常に動作していない

**診断**:
```bash
# ランチャースクリプトを確認
head -100 "build-standalone/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"

# exec -a の行が存在するか確認
grep "exec -a" "build-standalone/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"
```

**解決策**:
- macOS のバージョンによっては `exec -a` が期待通りに動作しない
- 将来のバージョンで Swift/Objective-C ラッパーを実装予定

### 問題 2: アプリが起動しない

**診断**:
```bash
# ログを確認
cat /tmp/playcover-manager-standalone.log

# ランチャーを直接実行
bash "build-standalone/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"

# 実行権限を確認
ls -la "build-standalone/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"
```

**解決策**:
```bash
# 実行権限を付与
chmod +x "build-standalone/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"

# Quarantine 属性を削除
xattr -cr "build-standalone/PlayCover Manager.app"
```

### 問題 3: 複数インスタンスが起動してしまう

**診断**:
```bash
# ロックファイルの状態を確認
ls -la /tmp/playcover-manager-running.lock
cat /tmp/playcover-manager-running.lock

# プロセスを確認
ps aux | grep -i playcover
```

**解決策**:
```bash
# すべてのインスタンスを終了
pkill -f "PlayCover Manager"

# ロックファイルを削除
rm -f /tmp/playcover-manager-running.lock

# 再度起動
open "build-standalone/PlayCover Manager.app"
```

---

## ✅ テスト完了チェックリスト

### 必須テスト

- [ ] ビルドが正常に完了する
- [ ] .app バンドル構造が正しい
- [ ] ターミナルから起動できる
- [ ] Finder から起動できる
- [ ] **Activity Monitor で "PlayCover Manager" として表示される**（最重要）
- [ ] シングルインスタンス機能が動作する
- [ ] ロックファイルが正しく管理される
- [ ] 終了時にロックファイルが削除される

### 推奨テスト

- [ ] Dock アイコンが正しく表示される
- [ ] 配布用 ZIP ファイルが作成できる
- [ ] ZIP を展開して起動できる
- [ ] ログファイルにエラーがない

### 環境依存テスト（参考）

- [ ] macOS 通知が表示される（環境により異なる）
- [ ] カスタムアイコンが表示される（icns 形式が必要）
- [ ] Gatekeeper 警告が表示されない（署名が必要）

---

## 📊 テスト結果の報告

テスト完了後、以下の情報を記録してください：

```
テスト環境:
- macOS バージョン: 
- アーキテクチャ: Intel / Apple Silicon
- zsh バージョン: zsh --version

テスト結果:
- ビルド: ✅/❌
- 起動: ✅/❌
- プロセス名表示: ✅/❌ (表示された名前: _________)
- シングルインスタンス: ✅/❌
- 配布テスト: ✅/❌

問題が発生した場合:
- エラーメッセージ: 
- ログ内容: (cat /tmp/playcover-manager-standalone.log)
- スクリーンショット: (Activity Monitor の表示)
```

---

## 🎯 成功基準

**最低限の成功基準（必須）**:
1. ✅ アプリが正常に起動する
2. ✅ シングルインスタンス機能が動作する
3. ✅ エラーなく終了できる

**理想的な成功基準**:
1. ✅ Activity Monitor で "PlayCover Manager" として表示される
2. ✅ Dock に PlayCover Manager アイコンが表示される
3. ✅ 配布用 ZIP から正常に起動できる

**既知の制限**:
- `exec -a` による プロセス名設定は環境依存（一部のmacOSで "zsh" と表示される可能性）
- カスタムアイコンは icns 形式が必要（PNG未対応）
- 未署名のため初回起動時に警告が出る

---

**最終更新**: 2025-10-31  
**バージョン**: 5.2.0
