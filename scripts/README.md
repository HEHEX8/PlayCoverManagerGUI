# PlayCoverManager ビルドスクリプト

## 📁 ファイル一覧

### `build_and_notarize.sh`
完全な配布用ビルドスクリプト（署名・公証込み）

**用途**: 
- GitHub Releasesでの配布
- 一般ユーザー向けリリース

**前提条件**:
- Apple Developer Program加入
- Developer ID Application証明書
- App-specific password

**使用方法**:
```bash
# 環境変数設定
export NOTARIZATION_APPLE_ID="your-email@example.com"
export NOTARIZATION_TEAM_ID="YOUR_TEAM_ID"
export NOTARIZATION_PASSWORD="your-app-specific-password"

# 実行
./scripts/build_and_notarize.sh
```

または、Keychainプロファイルを使用:
```bash
# 初回のみ: Keychainに保存
xcrun notarytool store-credentials "playcover-notarization" \
    --apple-id "your-email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "your-app-specific-password"

# 以降はプロファイル名を指定
export NOTARIZATION_KEYCHAIN_PROFILE="playcover-notarization"
./scripts/build_and_notarize.sh
```

**出力**:
- `build/PlayCoverManager.dmg` - 署名・公証済みDMG

---

### `build_dev.sh`
開発用の簡易ビルドスクリプト（署名なし）

**用途**:
- ローカルテスト
- 開発中の動作確認

**使用方法**:
```bash
./scripts/build_dev.sh
```

**出力**:
- `build/dev/Build/Products/Debug/PlayCoverManager.app`

---

## 🔐 認証情報の管理

### 方法1: 環境変数（一時的）
```bash
export NOTARIZATION_APPLE_ID="your-email@example.com"
export NOTARIZATION_TEAM_ID="YOUR_TEAM_ID"
export NOTARIZATION_PASSWORD="your-app-specific-password"
```

### 方法2: シェル設定ファイル（永続的）
`~/.zshrc` または `~/.bashrc` に追加:
```bash
# PlayCoverManager Notarization
export NOTARIZATION_APPLE_ID="your-email@example.com"
export NOTARIZATION_TEAM_ID="YOUR_TEAM_ID"
export NOTARIZATION_PASSWORD="your-app-specific-password"
```

反映:
```bash
source ~/.zshrc  # または source ~/.bashrc
```

### 方法3: Keychainプロファイル（推奨）
```bash
# 保存
xcrun notarytool store-credentials "playcover-notarization" \
    --apple-id "your-email@example.com" \
    --team-id "YOUR_TEAM_ID" \
    --password "your-app-specific-password"

# 使用
export NOTARIZATION_KEYCHAIN_PROFILE="playcover-notarization"
```

---

## 📋 チーム情報の確認

### Apple IDとTeam ID
1. https://developer.apple.com/account にアクセス
2. "Membership" セクションでTeam IDを確認

または、コマンドラインで:
```bash
# 証明書一覧
security find-identity -v -p codesigning

# Team ID確認
xcrun notarytool history --apple-id "your-email@example.com" \
    --password "your-app-specific-password"
```

---

## 🧪 テスト手順

### 1. ローカルテスト
```bash
# DMGをマウント
open build/PlayCoverManager.dmg

# アプリを別の場所にコピー
cp -R "/Volumes/PlayCoverManager/PlayCoverManager.app" ~/Desktop/

# 起動テスト
open ~/Desktop/PlayCoverManager.app
```

### 2. Gatekeeper検証
```bash
# 署名確認
codesign -dv --verbose=4 build/export/PlayCoverManager.app

# Gatekeeper確認
spctl --assess --verbose=4 --type execute build/export/PlayCoverManager.app

# DMG確認
spctl --assess --verbose=4 --type open --context context:primary-signature build/PlayCoverManager.dmg
```

成功時の出力例:
```
build/PlayCoverManager.dmg: accepted
source=Notarized Developer ID
origin=Developer ID Application: Your Name (TEAM_ID)
```

---

## ❌ トラブルシューティング

### エラー: "No signing certificate found"
```bash
# 証明書を確認
security find-identity -v -p codesigning

# Xcodeで証明書を再作成
# Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application
```

### エラー: "Notarization failed"
```bash
# ログを確認
xcrun notarytool log SUBMISSION_ID \
    --apple-id "your-email@example.com" \
    --password "your-app-specific-password"
```

一般的な原因:
- Hardened Runtimeが無効
- 必須Entitlementsが不足
- 署名されていないバイナリが含まれている

### エラー: "App is damaged and can't be opened"
ユーザー側での回避方法:
```bash
# quarantine属性を削除
xattr -cr /path/to/PlayCoverManager.app

# または
sudo spctl --master-disable  # 一時的にGatekeeperを無効化（非推奨）
```

---

## 📚 参考資料

- [DISTRIBUTION_GUIDE.md](../DISTRIBUTION_GUIDE.md) - 詳細な配布ガイド
- [Apple: Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [Apple: Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)
