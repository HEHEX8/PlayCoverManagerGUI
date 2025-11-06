# デバッグ手順書 / Debug Instructions

## 概要 / Overview

~~2つの重要な問題を調査するため、詳細なログを追加しました~~

**✅ 問題1: 解決済み** - マウントされていないコンテナへのアンマウント試行が原因でした
**✅ 問題2: 解決済み** - NSWorkspace通知が動作しないため、ポーリング方式を実装しました

## 解決済み問題 / Resolved Issues

1. **✅ PlayCoverコンテナのアンマウント失敗** 
   - 原因: マウントされていないコンテナにアンマウントを試行
   - 修正: `diskImageDescriptor.isMounted` でチェックしてからアンマウント

2. **✅ 自動アンマウントが動作しない**
   - 原因: NSWorkspace通知がPlayCover起動のiOSアプリで発火しない
   - 修正: 5秒ごとにポーリングしてアプリ終了を検知

---

## テスト手順 / Test Procedure

### 問題1のテスト: すべてアンマウント / Test Issue 1: Unmount All

1. **アプリをビルドして起動** / Build and launch the app
2. **コンソールを開く** / Open Console.app
3. **フィルタを設定**: `process:PlayCover Manager` (すべてのログを表示)
4. **「すべてアンマウント」をクリック** / Click "Unmount All"
5. **コンソール出力を確認** / Check console output

#### 期待されるログ出力 / Expected Log Output

```
[LauncherVM] ===== Starting performUnmountAllAndQuit =====
[LauncherVM] applyToPlayCoverContainer: true
[LauncherVM] Step 1: Unmounting app containers (N apps)
[LauncherVM] Checking app: com.example.app1
[LauncherVM] Container exists, attempting unmount: /path/to/container
[LauncherVM] Successfully unmounted: com.example.app1
...
[LauncherVM] Step 1 complete. Success: X, Failed: 0
[LauncherVM] Step 2: Unmounting PlayCover container
[LauncherVM] PlayCover container path: /Users/.../Containers/io.playcover.PlayCover
[LauncherVM] PlayCover container exists
[LauncherVM] Successfully unmounted PlayCover container  <-- これが出るはず
[LauncherVM] Step 2 complete. Total success: X
[LauncherVM] Step 3: Checking for external drive
...
[LauncherVM] Step 4: Showing results and quitting
```

#### 確認すべきポイント / Key Points to Check

**A. Step 2に到達しているか?** / Does it reach Step 2?
- `Step 2: Unmounting PlayCover container` が表示されない場合、Step 1で早期リターンしている
- If not shown, it's returning early in Step 1

**B. PlayCoverコンテナが存在するか?** / Does PlayCover container exist?
- `PlayCover container exists` が表示されない場合、コンテナのパスが間違っているか、マウントされていない
- If not shown, path is wrong or it's not mounted

**C. アンマウント試行のログは?** / Is unmount attempted?
- `Successfully unmounted PlayCover container` → 成功 / Success
- `Failed to unmount PlayCover container: <error>` → エラー内容を確認 / Check error details
- どちらも表示されない場合 → `fileManager.fileExists` が false を返している
- Neither shown → `fileManager.fileExists` is returning false

**D. エラーダイアログは表示されるか?** / Is error dialog shown?
- Step 2でエラーになった場合、ダイアログが表示されるはず
- If Step 2 fails, a dialog should appear

---

### 問題2のテスト: 自動アンマウント (ポーリング方式) / Test Issue 2: Auto-Unmount (Polling)

1. **アプリをビルドして起動** / Build and launch the app
2. **コンソールを開く** / Open Console.app
3. **フィルタを設定**: `process:PlayCover Manager`
4. **起動時のログを確認** / Check startup logs:
   ```
   [LauncherVM] Starting polling-based termination detection
   ```

5. **iOSアプリを起動** / Launch an iOS app
   ```
   [LauncherVM] 🚀 Launching app: com.example.app (App Name)
   [LauncherVM] 📝 Tracking app for termination: com.example.app
   ```

6. **iOSアプリを終了** (⌘Q または Command+Q) / Quit the iOS app

7. **5秒以内にログを確認** / Check console output within 5 seconds
   ```
   [LauncherVM] 🔍 Detected app termination via polling: com.example.app
   ```

#### 期待されるログ出力 / Expected Log Output

アプリ起動時:
```
[LauncherVM] 🔒 Lock acquired for com.example.iosapp: true
[LauncherVM] 🚀 Launching app: com.example.iosapp (App Name)
[LauncherVM] ✅ App launched successfully: com.example.iosapp
[LauncherVM] 📝 Tracking app for termination: com.example.iosapp
```

アプリ終了時（5秒以内に検知）:
```
[LauncherVM] 🔍 Detected app termination via polling: com.example.iosapp
[LauncherVM] unmountContainer called for com.example.iosapp
[LauncherVM] Container URL: /path/to/container
[LauncherVM] Releasing lock for com.example.iosapp
[LauncherVM] Container is mounted, checking for locks
[LauncherVM] No locks detected, attempting unmount
[LauncherVM] Successfully unmounted container for com.example.iosapp
```

#### 確認すべきポイント / Key Points to Check

**A. ポーリングは開始されているか?** / Is polling started?
- `Starting polling-based termination detection` が表示されない
  → ポーリングタスクが開始されていない
- Not shown → Polling task not started

**B. アプリ起動が追跡されているか?** / Is app launch tracked?
- `📝 Tracking app for termination: ...` が表示されない
  → 追跡セットに追加されていない
- Not shown → Not added to tracking set

**C. 終了検知は動作しているか?** / Is termination detected?
- `🔍 Detected app termination via polling: ...` が表示されない
  → ポーリングが終了を検知できていない（5秒待った？）
- Not shown → Polling didn't detect termination (waited 5 seconds?)

**D. アンマウント処理は実行されているか?** / Is unmount process executed?
- `unmountContainer called` が表示されない → unmountContainer関数が呼ばれていない
- Not shown → unmountContainer function not called

**E. コンテナはマウントされているか?** / Is container mounted?
- `Container not mounted or descriptor failed` → 既にアンマウントされているか、descriptorの取得失敗
- Shown → Already unmounted or descriptor fetch failed

**F. ロックがかかっているか?** / Is container locked?
- `Container is locked by another process` → PlayCoverがまだ実行中
- Shown → PlayCover still running

**G. アンマウント結果は?** / Unmount result?
- `Successfully unmounted container` → 成功 / Success
- `Failed to unmount container: <error>` → エラー詳細を確認 / Check error details

---

## 想定される原因と対策 / Possible Causes and Solutions

### 問題1: PlayCoverコンテナのアンマウント失敗

#### 原因候補1: コンテナが実際にはマウントされていない
**ログで確認**: `PlayCover container doesn't exist or not mounted, skipping`
**対策**: PlayCoverが起動時に自身のコンテナをマウントしているか確認

#### 原因候補2: コンテナのパスが間違っている
**ログで確認**: `PlayCover container path: ...` のパスを確認
**対策**: `PlayCoverPaths.containerRootURL` の実装を確認

#### 原因候補3: diskutil unmount が失敗している
**ログで確認**: `Failed to unmount PlayCover container: <error>`
**対策**: エラーメッセージから原因を特定 (権限、使用中など)

#### 原因候補4: Step 1でエラーが起きて早期リターンしている
**ログで確認**: `Step 2` に到達していない
**対策**: Step 1のエラーを修正

### ~~問題2: 自動アンマウントが動作しない~~ ✅ 解決済み

**解決方法**: ポーリングベースの検知を実装

NSWorkspaceの通知はPlayCover起動のiOSアプリでは発火しないことが判明したため、
5秒ごとにポーリングして実行中アプリをチェックする方式に変更しました。

#### 実装詳細

- **ポーリング間隔**: 5秒
- **追跡対象**: 管理対象アプリのみ（メモリ効率的）
- **検知遅延**: 最大5秒（実用上問題なし）
- **CPU使用**: 軽微（5秒に1回のチェックのみ）

#### トラブルシューティング（もし動作しない場合）

**ポーリングが開始されない**:
- `Starting polling-based termination detection` が表示されるか確認
- `init()` で `startPollingForTerminations()` が呼ばれているか確認

**追跡されていない**:
- アプリ起動時に `📝 Tracking app for termination` が出るか確認
- `previouslyRunningApps` セットに追加されているか確認

**終了が検知されない**:
- アプリ終了後、5秒待つ
- `NSWorkspace.shared.runningApplications` に該当アプリがいないか確認
- bundleIDが正しく一致しているか確認

---

## ログ収集方法 / How to Collect Logs

### Console.app を使う方法

1. Console.app を開く
2. 左サイドバーで Mac を選択
3. 検索フィールドに `process:PlayCover Manager` と入力
4. PlayCover Manager を操作
5. ログをコピー: すべて選択 (⌘A) → コピー (⌘C)

### ターミナルを使う方法

```bash
# リアルタイムでログを表示
log stream --predicate 'process == "PlayCover Manager"' --level debug

# または、既存のログを検索
log show --predicate 'process == "PlayCover Manager"' --last 5m
```

---

## 次のステップ / Next Steps

ログを収集したら、以下の情報をお知らせください:

1. **問題1のログ** - `performUnmountAllAndQuit` の全ログ
2. **問題2のログ** - アプリ終了前後のログ
3. **どのステップで停止したか** - 上記の「確認すべきポイント」のどこで異常が見つかったか

Please provide:

1. **Issue 1 logs** - Complete logs from `performUnmountAllAndQuit`
2. **Issue 2 logs** - Logs before and after app termination
3. **Where it stopped** - Which checkpoint from above found the issue
