# トラブルシューティングガイド

## アプリが起動しない問題

### 症状
アプリアイコンをクリックしても何も起動しない

### 原因と解決方法

#### 1. ロックファイルの確認

ロックファイルが残っている可能性があります：

```bash
# ロックファイルを確認
ls -la /tmp/playcover-manager-running.lock

# ロックファイルを削除
rm -f /tmp/playcover-manager-running.lock
```

#### 2. プロセスの確認

既にプロセスが実行中の可能性：

```bash
# PlayCover Managerプロセスを確認
ps aux | grep -i playcover

# プロセスを強制終了
pkill -f "playcover-manager"
pkill -f "main.sh"
```

#### 3. アプリバンドルの再ビルド

アプリバンドルが壊れている可能性：

```bash
cd /path/to/PlayCoverManager

# 既存ビルドを削除
rm -rf build/

# 再ビルド
./build-app.sh

# アプリを再インストール
rm -rf "/Applications/PlayCover Manager.app"
cp -r "build/PlayCover Manager.app" /Applications/
```

#### 4. 実行権限の確認

スクリプトに実行権限がない可能性：

```bash
# アプリ内のスクリプトに実行権限を付与
chmod +x "/Applications/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"
chmod +x "/Applications/PlayCover Manager.app/Contents/Resources/main-script.sh"
```

#### 5. ログの確認

**ランチャーログを確認:**

```bash
# ランチャーのログファイルを確認（v5.2.0+）
cat /tmp/playcover-manager-launcher.log

# リアルタイムでログを監視
tail -f /tmp/playcover-manager-launcher.log
```

**Terminalから直接実行してエラーを確認：**

```bash
# 直接実行してエラーメッセージを確認
cd /path/to/PlayCoverManager
./playcover-manager.command
```

または

```bash
# main.shを直接実行
./main.sh
```

**ランチャースクリプトを直接実行:**

```bash
# アプリバンドル内のランチャーを直接実行
bash "/Applications/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"
```

#### 6. macOSセキュリティ設定

Gatekeeperが実行をブロックしている可能性：

1. システム設定 → プライバシーとセキュリティ
2. 「"PlayCover Manager"は開発元を確認できないため、使用がブロックされました」と表示されている場合
3. 「このまま開く」をクリック

または、ターミナルから：

```bash
# Quarantine属性を削除
xattr -dr com.apple.quarantine "/Applications/PlayCover Manager.app"
```

### デバッグモード

詳細なログを確認するには：

```bash
# デバッグ出力を有効にして実行
cd /path/to/PlayCoverManager
DEBUG=1 ./main.sh
```

### 完全リセット

全てをリセットして再スタート：

```bash
# 1. アプリを削除
rm -rf "/Applications/PlayCover Manager.app"

# 2. ロックファイルを削除
rm -f /tmp/playcover-manager*.lock
rm -f /tmp/playcover-manager*.pid

# 3. プロセスを終了
pkill -9 -f "playcover-manager"
pkill -9 -f "main.sh"

# 4. ソースから再ビルド
cd /path/to/PlayCoverManager
rm -rf build/
./build-app.sh
cp -r "build/PlayCover Manager.app" /Applications/

# 5. 再起動
open "/Applications/PlayCover Manager.app"
```

## よくある問題

### Q: ロックファイルエラーが表示される

**A:** ロックファイルを手動で削除してください：

```bash
rm -f /tmp/playcover-manager-running.lock
```

### Q: 「既に実行中です」と表示されるが、ウィンドウが見つからない

**A:** ゾンビプロセスを終了してください：

```bash
ps aux | grep "main.sh"
kill -9 <PID>
```

### Q: Terminalウィンドウが開かない

**A:** AppleScriptの権限を確認：

1. システム設定 → プライバシーとセキュリティ → オートメーション
2. Terminalにチェックが入っているか確認

### Q: 初回起動時に2つのTerminalウィンドウが開く（v5.2.0で自動修正）

**A:** v5.2.0以降では、この問題は自動的に修正されます。

**自動修正機能:**
1. ランチャーが`defaults write`でTerminal.appのセッション復元を無効化
2. 復元されたウィンドウを自動的に検出して閉じる
3. PlayCoverウィンドウだけが残る

**それでも2つのウィンドウが開く場合:**

**原因:** macOSのシステム設定でセッション復元が有効になっている可能性

**手動対処法:**
```bash
# Terminal.appのセッション復元を無効化
defaults write com.apple.Terminal NSQuitAlwaysKeepsWindows -bool false

# 設定を反映するためTerminal.appを再起動
```

または、システム設定で無効化：
1. システム設定 → 一般 → ログイン時にウィンドウを再度開く：**オフ**
2. Terminal.app → 設定 → 一般 → 起動時：新規ウィンドウを開く

**Note:** v5.2.0では、ほとんどの場合で自動的に修正されるため、手動設定は不要です。

### Q: 複数のTerminalウィンドウが開く（v5.2.0で修正済み）

**A:** v5.2.0以降では、シングルインスタンス機能により自動的に防止されます。

**動作:**
- 1回目のクリック: 新しいTerminalウィンドウが開く
- 2回目以降のクリック: 既存のウィンドウが前面に表示される（新しいウィンドウは開かない）

**それでも問題が発生する場合:**

1. ロックファイルが残っている可能性があります：
```bash
# ロックファイルを削除
rm -f /tmp/playcover-manager-running.lock
```

2. 古いバージョンを使用している可能性があります：
```bash
# バージョンを確認（起動画面に表示）
./main.sh
# "Version 5.2.0" と表示されることを確認
```

3. アプリバンドルを再ビルド：
```bash
./build-app.sh
cp -r "build/PlayCover Manager.app" /Applications/
```

## サポート情報

問題が解決しない場合：

1. GitHubでIssueを作成：https://github.com/HEHEX8/PlayCoverManager/issues
2. 以下の情報を含めてください：
   - macOSバージョン
   - エラーメッセージ
   - 実行したコマンド
   - `ps aux | grep playcover`の出力
   - `/tmp/`のロックファイル状況
