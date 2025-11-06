# PlayCoverManager 配布ガイド

このガイドでは、macOSのGatekeeperに怒られずにアプリを配布する方法を説明します。

## 📋 前提条件

### 1. Apple Developer Program加入
- Apple Developer Programに登録（年間$99）
- https://developer.apple.com/programs/

### 2. Developer ID証明書の取得

#### Xcode経由で取得（推奨）:
1. Xcode > Settings > Accounts
2. Apple IDでサインイン
3. "Manage Certificates" をクリック
4. "+" ボタン > "Developer ID Application" を選択

#### 手動で取得:
1. https://developer.apple.com/account/resources/certificates/list
2. "+" ボタン
3. "Developer ID Application" を選択
4. 指示に従って証明書を作成・ダウンロード

### 3. App-Specific Passwordの作成
公証（Notarization）に必要です。

1. https://appleid.apple.com/account/manage にアクセス
2. "App-Specific Passwords" セクション
3. "Generate Password" をクリック
4. 名前を入力（例: "PlayCoverManager Notarization"）
5. **生成されたパスワードを保存**（再表示されません）

---

## 🔧 プロジェクト設定

### 現在の設定（すでに完了）:
- ✅ Hardened Runtime有効
- ✅ Entitlements設定済み
- ✅ 開発チームID設定済み

### 追加で必要な設定:

#### 1. プロジェクトのバージョン設定
Xcodeで:
- Target > General
- Version: `1.0.0` (例)
- Build: `1`

#### 2. 署名とケイパビリティ
Xcodeで:
- Target > Signing & Capabilities
- Team: あなたのApple Developer Team
- Signing Certificate: "Developer ID Application"（配布用）
- または "Apple Development"（開発用）

---

## 🚀 ビルドと配布手順

### 方法1: 自動化スクリプト（推奨）

プロジェクトに `scripts/build_and_notarize.sh` スクリプトを作成します。

```bash
#!/bin/bash
# このスクリプトは自動的にビルド、署名、公証を行います
./scripts/build_and_notarize.sh
```

### 方法2: 手動ビルド

#### ステップ1: Archiveビルド
```bash
xcodebuild archive \
    -project PlayCoverManager.xcodeproj \
    -scheme PlayCoverManager \
    -archivePath build/PlayCoverManager.xcarchive \
    -configuration Release \
    CODE_SIGN_IDENTITY="Developer ID Application"
```

#### ステップ2: .appファイルをエクスポート
```bash
xcodebuild -exportArchive \
    -archivePath build/PlayCoverManager.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist scripts/ExportOptions.plist
```

#### ステップ3: コード署名の検証
```bash
codesign --verify --deep --strict --verbose=2 "build/export/PlayCoverManager.app"
spctl --assess --verbose=4 --type execute "build/export/PlayCoverManager.app"
```

#### ステップ4: DMGまたはZIPの作成

##### DMG作成（推奨）:
```bash
hdiutil create -volname "PlayCoverManager" \
    -srcfolder "build/export/PlayCoverManager.app" \
    -ov -format UDZO "build/PlayCoverManager.dmg"
```

##### ZIP作成:
```bash
cd build/export
ditto -c -k --keepParent "PlayCoverManager.app" "../PlayCoverManager.zip"
cd ../..
```

#### ステップ5: 公証（Notarization）

##### 公証リクエスト送信:
```bash
xcrun notarytool submit "build/PlayCoverManager.dmg" \
    --apple-id "your-email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "your-app-specific-password" \
    --wait
```

**注意**: `--wait` オプションで完了まで待機します（5-15分程度）

##### 公証ステータス確認:
```bash
xcrun notarytool info SUBMISSION_ID \
    --apple-id "your-email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "your-app-specific-password"
```

##### ログ確認（失敗時）:
```bash
xcrun notarytool log SUBMISSION_ID \
    --apple-id "your-email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "your-app-specific-password"
```

#### ステップ6: Staplingチケットを添付
公証が成功したら、チケットをDMGに添付:

```bash
xcrun stapler staple "build/PlayCoverManager.dmg"
xcrun stapler validate "build/PlayCoverManager.dmg"
```

---

## 🔐 認証情報の安全な保管

App-specific passwordを環境変数として保存:

```bash
# ~/.zshrc または ~/.bashrc に追加
export NOTARIZATION_APPLE_ID="your-email@example.com"
export NOTARIZATION_PASSWORD="your-app-specific-password"
export NOTARIZATION_TEAM_ID="YOUR_TEAM_ID"
```

または、Keychainに保存:

```bash
xcrun notarytool store-credentials "playcover-notarization" \
    --apple-id "your-email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "your-app-specific-password"
```

その後、以下のように使用:

```bash
xcrun notarytool submit "build/PlayCoverManager.dmg" \
    --keychain-profile "playcover-notarization" \
    --wait
```

---

## 🧪 テスト

### 署名検証:
```bash
codesign -dv --verbose=4 "build/export/PlayCoverManager.app"
```

### Gatekeeper検証:
```bash
spctl --assess --verbose=4 --type execute "build/export/PlayCoverManager.app"
```

成功すると:
```
build/export/PlayCoverManager.app: accepted
source=Notarized Developer ID
```

### 実際のテスト:
1. DMGをダブルクリック
2. アプリを別の場所（例: デスクトップ）にコピー
3. ダブルクリックして起動
4. Gatekeeperの警告が出ないことを確認

---

## ❌ よくある問題と解決方法

### 問題1: "Developer ID Application証明書が見つからない"
**解決方法**: 
- Xcode > Settings > Accounts > Manage Certificates で証明書を作成
- または開発用は "Apple Development" を使用

### 問題2: "Notarization failed with invalid signature"
**解決方法**:
- Hardened Runtimeが有効か確認
- Entitlementsが正しく設定されているか確認
- すべてのバイナリが署名されているか確認

### 問題3: "Notarization timeout"
**解決方法**:
- Appleのサーバーが混雑している場合があります
- 少し待ってから再試行

### 問題4: "アプリが破損しているため開けません"
**解決方法**:
- 公証が完了していない
- Staplingチケットが添付されていない
- ユーザーに以下を実行してもらう（回避策）:
  ```bash
  xattr -cr /path/to/PlayCoverManager.app
  ```

---

## 📦 GitHub Releasesでの配布

### 1. タグを作成:
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### 2. GitHub Releasesページでリリースを作成:
- https://github.com/HEHEX8/PlayCoverManagerGUI/releases/new
- タグを選択
- リリースノートを記入
- 公証済みDMGをアップロード

### 3. リリースノートの例:
```markdown
## PlayCoverManager v1.0.0

### 新機能
- iOSアプリの簡単起動
- 検索機能
- 設定画面

### ダウンロード
- [PlayCoverManager.dmg](リンク) - macOS 11.0以降

### インストール方法
1. DMGをダウンロード
2. DMGを開く
3. PlayCoverManagerをアプリケーションフォルダにドラッグ
4. 起動

署名・公証済みなので、Gatekeeperの警告は出ません。
```

---

## 🤖 CI/CD自動化（GitHub Actions）

将来的にGitHub Actionsで自動ビルド・公証を行うことも可能です。
（詳細は `scripts/` ディレクトリのワークフローファイルを参照）

---

## 📚 参考リンク

- [Apple公式: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Apple公式: Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
- [xcrun notarytool マニュアル](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)
