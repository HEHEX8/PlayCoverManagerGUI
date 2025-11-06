# デバッグ手順書 / Debug Instructions

## 概要 / Overview

2つの重要な問題を調査するため、詳細なログを追加しました:

1. **PlayCoverコンテナのアンマウント失敗** - 「すべてアンマウント」機能でPlayCoverコンテナがアンマウントされず、エラーも表示されない
2. **自動アンマウントが動作しない** - iOSアプリ終了時に自動でアンマウントする機能が効いていない

Added detailed logging to investigate two critical issues:

1. **PlayCover container unmount failure** - "Unmount All" doesn't unmount PlayCover container and shows no error
2. **Auto-unmount not working** - Automatic unmount on iOS app termination doesn't trigger

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

### 問題2のテスト: 自動アンマウント / Test Issue 2: Auto-Unmount

1. **アプリをビルドして起動** / Build and launch the app
2. **コンソールを開く** / Open Console.app
3. **フィルタを設定**: `process:PlayCover Manager`
4. **起動時のログを確認** / Check startup logs:
   ```
   [LauncherVM] Setting up app termination observer
   ```
   これが表示されない場合、`startMonitoringAppTerminations()` が呼ばれていない

5. **iOSアプリを起動** / Launch an iOS app
6. **iOSアプリを終了** (⌘Q または Command+Q) / Quit the iOS app
7. **コンソール出力を確認** / Check console output

#### 期待されるログ出力 / Expected Log Output

アプリ起動時:
```
[LauncherVM] 🔒 Lock acquired for com.example.iosapp: true
[LauncherVM] 🚀 Launching app: com.example.iosapp (App Name)
[LauncherVM] ✅ App launched successfully: com.example.iosapp
```

アプリ終了時:
```
[LauncherVM] ===== App Termination Notification Received =====
[LauncherVM] Terminated app info:
[LauncherVM]   Bundle ID: com.example.iosapp
[LauncherVM]   App Name: App Name
[LauncherVM]   Process ID: 12345
[LauncherVM] Checking against managed apps:
[LauncherVM]   - com.example.iosapp (App Name)
[LauncherVM] Is managed app: true
[LauncherVM] ✅ Starting auto-unmount for com.example.iosapp
[LauncherVM] unmountContainer called for com.example.iosapp
[LauncherVM] Container URL: /path/to/container
[LauncherVM] Releasing lock for com.example.iosapp
[LauncherVM] Container is mounted, checking for locks
[LauncherVM] No locks detected, attempting unmount
[LauncherVM] Successfully unmounted container for com.example.iosapp
```

#### 確認すべきポイント / Key Points to Check

**A. 通知は受信しているか?** / Is notification received?
- `===== App Termination Notification Received =====` が表示されない
  → 通知が発火していない (NSWorkspaceの問題、またはPlayCoverの起動方法が特殊)
- Not shown → Notification not firing (NSWorkspace issue, or PlayCover launches apps in a special way)
- **重要**: iOSアプリを終了したときに、**何かしらの**アプリ終了通知が出るはず
  → 全く出ない場合は、NSWorkspaceが全く機能していない
- **Important**: When iOS app quits, **some** termination notification should appear
  → If nothing shows, NSWorkspace monitoring is completely broken

**B. bundleIDは正しいか?** / Is bundle ID correct?
- `Bundle ID: <no bundle ID>` → アプリにbundleIDがない（問題）
- Shows `<no bundle ID>` → App has no bundle ID (problem)
- 起動時のbundleIDと終了時のbundleIDを比較
- Compare bundle ID between launch and termination

**C. 管理対象アプリとして認識されているか?** / Is it recognized as managed app?
- `Is managed app: false` → アプリリストに含まれていない、bundleIDが一致していない
- Shows false → Not in app list, bundleID mismatch
- `Checking against managed apps:` のリストを確認
- Check the list shown in `Checking against managed apps:`

**D. アンマウント処理は実行されているか?** / Is unmount process executed?
- `✅ Starting auto-unmount for ...` が表示されない → Task内のコードが実行されていない
- Not shown → Task code not executing
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

### 問題2: 自動アンマウントが動作しない

#### 原因候補1: 通知監視が設定されていない
**ログで確認**: `Setting up app termination observer` が表示されない
**対策**: `init()` で `startMonitoringAppTerminations()` が呼ばれているか確認

#### 原因候補2: NSWorkspaceの通知が発火していない
**ログで確認**: `===== App Termination Notification Received =====` が表示されない
**対策**: 
- PlayCoverから起動したiOSアプリの終了が、macOSのアプリ終了として認識されていない可能性
- PlayToolsを使った特殊な起動方法が原因の可能性
- 他のmacOSアプリを終了したときに通知が来るか確認（例: Safariを終了）
- 通知が全く来ない場合は、observer登録に問題がある

#### 原因候補3: bundleIDが一致していない
**ログで確認**: 
- `Bundle ID: ...` と `Checking against managed apps:` のリストを比較
- `Is managed app: false` と表示される
**対策**: 
- 起動時と終了時のbundleIDが完全一致しているか確認
- PlayCoverがアプリを起動するときに、bundleIDを変更している可能性
- 大文字小文字の違い、プレフィックス/サフィックスの追加など

#### 原因候補4: コンテナが既にアンマウントされている
**ログで確認**: `Container not mounted or descriptor failed`
**対策**: PlayCoverが終了時に自動でアンマウントしている可能性

#### 原因候補5: ロックが解放されていない
**ログで確認**: `Container is locked by another process`
**対策**: 
- アプリ起動時に取得したロックが正しく解放されているか確認
- PlayCoverプロセスがまだロックを保持しているか確認

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
