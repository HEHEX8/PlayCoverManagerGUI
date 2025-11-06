# テスト手順書 - v5.2.0 シングルインスタンス機能

このドキュメントは、v5.2.0で実装されたシングルインスタンス機能のテスト手順を説明します。

## 📋 目次

1. [Sandbox環境でのテスト](#sandbox環境でのテスト)
2. [macOS実機でのテスト](#macos実機でのテスト)
3. [期待される動作](#期待される動作)
4. [トラブルシューティング](#トラブルシューティング)

---

## Sandbox環境でのテスト

sandbox環境（bash only）でシングルインスタンス機能をテストする方法。

### 前提条件

- bash 4.0以降
- 標準的なUnix/Linuxコマンド（grep, sed, ps, etc.）

### テスト1: シングルインスタンス機能の基本動作

```bash
cd /home/user/webapp
./test-single-instance.sh
```

**期待される出力:**
- ✅ Test 1 PASS: ロックファイルの作成と削除
- ✅ Test 2: 重複起動の検出と拒否
- ✅ Test 3 PASS: ロック解放後の再起動

### テスト2: main.shのbash互換性確認

```bash
cd /home/user/webapp
./test-main-compat.sh
```

**期待される出力:**
- ✅ Compatibility layer functional
- ✅ SCRIPT_DIR detection working
- ✅ All required files present
- ✅ Syntax conversion successful
- ✅ No bash syntax errors
- ✅ Lock mechanism operational

---

## macOS実機でのテスト

実際のmacOS環境（zsh）でアプリをテストする方法。

### 前提条件

- macOS Sequoia 15.1以降
- zsh（macOS標準）
- Terminal.app
- プロジェクトをローカルにclone済み

### テスト1: コマンドラインからの直接起動

#### Step 1: 初回起動

```bash
cd ~/path/to/PlayCoverManager
zsh main.sh
```

**期待される動作:**
- PlayCover Managerのメインメニューが表示される
- `/tmp/playcover-manager-running.lock` が作成される
- ロックファイルに現在のプロセスIDが記録される

#### Step 2: 重複起動テスト

**別のTerminalウィンドウを開いて**、以下を実行：

```bash
cd ~/path/to/PlayCoverManager
zsh main.sh
```

**期待される動作:**
- ✅ "PlayCover Manager は既に実行中です" と表示される
- ✅ 既存のTerminalウィンドウが前面にアクティブ化される
- ✅ 新しいメニューは表示されず、スクリプトが終了する

#### Step 3: 終了後の再起動テスト

1. 最初のウィンドウで `q` を押して終了
2. 再度起動を試みる：

```bash
zsh main.sh
```

**期待される動作:**
- ✅ 正常に起動してメニューが表示される
- ✅ 新しいロックファイルが作成される

### テスト2: アプリバンドル(.app)からの起動

#### Step 1: アプリをビルド

```bash
cd ~/path/to/PlayCoverManager
./build-app.sh
```

**期待される出力:**
```
✅ Build complete!
📦 App bundle: build/PlayCover Manager.app
```

#### Step 2: アプリをApplicationsにインストール

```bash
# 古いバージョンを削除（存在する場合）
rm -rf "/Applications/PlayCover Manager.app"

# 新しいバージョンをコピー
cp -r "build/PlayCover Manager.app" /Applications/

# 実行権限を確認
chmod +x "/Applications/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"
```

#### Step 3: 初回起動テスト

Finderから「PlayCover Manager.app」をダブルクリック

**期待される動作:**
- ✅ Terminalウィンドウが開く
- ✅ タイトルバーに "PlayCover Manager" と表示
- ✅ メインメニューが表示される

#### Step 4: 重複起動テスト（重要！）

**アプリアイコンを再度クリック**（またはダブルクリック）

**期待される動作:**
- ✅ 既存のTerminalウィンドウが前面にアクティブ化される
- ✅ 新しいTerminalウィンドウは開かない
- ✅ 短時間メッセージが表示され、すぐに閉じる

#### Step 5: 連打テスト

**アプリアイコンを素早く3〜5回クリック**

**期待される動作:**
- ✅ 既存のTerminalウィンドウが前面にアクティブ化される
- ✅ 複数のTerminalウィンドウは開かない
- ✅ 一瞬メッセージが表示されるウィンドウが複数開くが、すぐに自動的に閉じる

#### Step 6: 終了後の再起動

1. Terminalウィンドウで `q` を押して終了
2. アプリアイコンを再度クリック

**期待される動作:**
- ✅ 新しいTerminalウィンドウが開く
- ✅ メニューが正常に表示される

### テスト3: 異常系のテスト

#### ケース1: ゾンビロックファイルの検出

1. アプリを起動
2. **Terminalを強制終了**（Command+Q または kill）
3. アプリを再度起動

**期待される動作:**
- ✅ 古いロックファイルを検出して自動削除
- ✅ 正常に起動

#### ケース2: 手動でのロックファイル削除

```bash
# ロックファイルを手動削除
rm -f /tmp/playcover-manager-running.lock

# アプリを起動
open "/Applications/PlayCover Manager.app"
```

**期待される動作:**
- ✅ 正常に起動
- ✅ 新しいロックファイルが作成される

---

## 期待される動作

### ✅ 正常ケース

| シナリオ | 期待される動作 |
|---------|---------------|
| 初回起動 | 新しいTerminalウィンドウが開き、メニューが表示される |
| 実行中に再度クリック | 既存のウィンドウが前面に表示され、新しいウィンドウは開かない |
| 終了後に再度起動 | 新しいTerminalウィンドウが開き、メニューが表示される |
| 連続クリック（連打） | 1つのウィンドウのみが残り、他は自動的に閉じる |

### ⚠️ 異常ケース（自動復旧）

| シナリオ | 期待される動作 |
|---------|---------------|
| ゾンビロック | 古いロックを自動検出して削除し、正常に起動 |
| プロセス強制終了 | 次回起動時にロックを自動削除し、正常に起動 |
| ロックファイル削除 | 正常に起動し、新しいロックを作成 |

---

## トラブルシューティング

### 問題1: "既に実行中です" と表示されるが、ウィンドウが見えない

**原因:** プロセスは実行中だが、ウィンドウが最小化またはデスクトップ外にある

**解決方法:**
```bash
# Terminalをアクティブ化
osascript -e 'tell application "Terminal" to activate'
```

### 問題2: ロックファイルエラー

**原因:** ロックファイルが破損または残っている

**解決方法:**
```bash
# ロックファイルを削除
rm -f /tmp/playcover-manager-running.lock

# プロセスを確認
ps aux | grep "main.sh"

# 必要に応じてプロセスを終了
kill <PID>
```

### 問題3: 複数のTerminalウィンドウが開く

**原因（v5.2.0以前）:** シングルインスタンス機能が実装されていない

**解決方法:**
```bash
# バージョンを確認
./main.sh
# → "Version 5.2.0" と表示されることを確認

# 必要に応じて再ビルド
./build-app.sh
cp -r "build/PlayCover Manager.app" /Applications/
```

### 問題4: AppleScriptのアクセス許可エラー

**原因:** Terminalにオートメーション権限がない

**解決方法:**
1. システム設定 → プライバシーとセキュリティ → オートメーション
2. Terminal.app にチェックが入っているか確認
3. 必要に応じてチェックを入れる

---

## チェックリスト

テストが完了したら、以下をチェック：

### Sandbox環境（bash）
- [ ] test-single-instance.sh が全てPASS
- [ ] test-main-compat.sh が全てPASS

### macOS実機（zsh）
- [ ] コマンドラインから起動できる
- [ ] 重複起動が防止される
- [ ] 既存ウィンドウがアクティブ化される
- [ ] 終了後に再起動できる
- [ ] アプリバンドルから起動できる
- [ ] アイコン連打しても1つのウィンドウのみ
- [ ] ゾンビロックが自動復旧される

---

## テスト結果の報告

テスト結果をGitHub Issueで報告する場合、以下の情報を含めてください：

```markdown
## テスト環境
- macOSバージョン: 
- zshバージョン: `zsh --version`
- アプリバージョン: 5.2.0

## テスト結果
- [ ] コマンドライン起動: 成功/失敗
- [ ] 重複起動防止: 成功/失敗
- [ ] アプリバンドル起動: 成功/失敗
- [ ] 連打テスト: 成功/失敗
- [ ] ゾンビロック復旧: 成功/失敗

## 詳細
（エラーメッセージやスクリーンショットなど）
```

---

## 参考資料

- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - 一般的なトラブルシューティング
- [README.md](README.md) - プロジェクト概要
- [CHANGELOG.md](CHANGELOG.md) - バージョン履歴
