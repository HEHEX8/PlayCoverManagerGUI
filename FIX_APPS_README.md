# PlayCover App Fix Scripts

PlayCoverManagerの通知機能実装中に、一部のアプリのInfo.plistに `NSUserNotificationAlertStyle` キーが追加され、アプリがクラッシュする問題が発生しました。

これらのスクリプトは、そのキーを削除してアプリを修復します。

## スクリプト一覧

### 1. fix_broken_apps.sh - 全アプリ自動修復

PlayCoverのアプリディレクトリ (`~/Library/Containers/io.playcover.PlayCover/Applications`) 内の全てのアプリを検索し、問題のあるキーを自動的に削除します。

**使い方:**
```bash
./fix_broken_apps.sh
```

**出力例:**
```
================================================
PlayCover App Info.plist Fix Script
================================================

Searching for PlayCover apps in:
  /Users/username/Library/Containers/io.playcover.PlayCover/Applications

Found NSUserNotificationAlertStyle in: Genshin Impact.app
  ✓ Successfully removed NSUserNotificationAlertStyle

Found NSUserNotificationAlertStyle in: Honkai Star Rail.app
  ✓ Successfully removed NSUserNotificationAlertStyle

================================================
Summary:
  Checked apps: 15
  Fixed apps: 2
================================================

Apps have been fixed! You can now launch them normally.
```

### 2. fix_app.sh - 個別アプリ修復

特定のアプリだけを修復したい場合に使用します。自動的にバックアップも作成します。

**使い方（簡単）:**
```bash
./fix_app.sh "アプリ名.app"
```

**使い方（フルパス指定）:**
```bash
./fix_app.sh "~/Library/Containers/io.playcover.PlayCover/Applications/アプリ名.app"
```

**例:**
```bash
./fix_app.sh "Genshin Impact.app"
```
または
```bash
./fix_app.sh "~/Library/Containers/io.playcover.PlayCover/Applications/Genshin Impact.app"
```

**出力例:**
```
================================================
PlayCover App Info.plist Fix Script
================================================

Target app: Genshin Impact.app
Info.plist: ~/Library/Containers/io.playcover.PlayCover/Applications/Genshin Impact.app/Info.plist

Found NSUserNotificationAlertStyle key
Created backup: ~/Library/Containers/io.playcover.PlayCover/Applications/Genshin Impact.app/Info.plist.backup.20250101_120000

✓ Successfully removed NSUserNotificationAlertStyle

The app has been fixed! You can now launch it normally.

================================================
```

## トラブルシューティング

### 権限エラーが出る場合

一部のアプリは管理者権限が必要な場合があります：

```bash
sudo ./fix_broken_apps.sh
```

または

```bash
sudo ./fix_app.sh "/Applications/アプリ名.app"
```

### アプリが見つからない場合

- **簡単な方法**: アプリ名だけを指定（例: `"Genshin Impact.app"`）
- **フルパス指定**: `~/Library/Containers/io.playcover.PlayCover/Applications/アプリ名.app`
- アプリ名に空白が含まれる場合は、ダブルクォートで囲んでください
- `fix_app.sh` でアプリが見つからない場合、利用可能なアプリ一覧が表示されます

## 修復内容

これらのスクリプトは以下の処理を行います：

1. PlayCoverのアプリディレクトリからアプリのInfo.plistを探す
2. `NSUserNotificationAlertStyle` キーの存在を確認
3. キーが存在する場合、削除する（fix_app.shは事前にバックアップを作成）
4. 結果を表示

## 注意事項

- スクリプトは `~/Library/Containers/io.playcover.PlayCover/Applications` フォルダ内のアプリのみをチェックします
- バックアップは `fix_app.sh` のみが作成します（`fix_broken_apps.sh` は作成しません）
- 問題が解決しない場合は、アプリを再インストールしてください

## 技術詳細

**問題の原因:**
PlayCoverManagerの通知抑制機能の実装中に、Info.plistに以下のキーが追加されました：
```xml
<key>NSUserNotificationAlertStyle</key>
<string>none</string>
```

このキーはmacOSネイティブアプリ用のもので、iOSアプリ（PlayCoverアプリ）では認識されず、クラッシュの原因となっていました。

**修復方法:**
PlistBuddyツールを使用してキーを削除：
```bash
/usr/libexec/PlistBuddy -c "Delete :NSUserNotificationAlertStyle" Info.plist
```
