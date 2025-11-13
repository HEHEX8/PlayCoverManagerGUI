# バージョン管理ガイド

PlayCover Manager のバージョン管理は **AppVersion.swift** で一元管理されています。

## 📍 バージョン定義の場所

**単一の真実の情報源**: `PlayCoverManager/Utils/AppVersion.swift`

```swift
enum AppVersion {
    static let version = "1.2.0"  // ← ここを変更
    static let build = "1"        // ← ここを変更
}
```

## 🔄 バージョン更新手順

### 1. AppVersion.swift を更新

```swift
// PlayCoverManager/Utils/AppVersion.swift
enum AppVersion {
    static let version = "1.3.0"  // 新しいバージョン
    static let build = "1"        // ビルド番号
}
```

### 2. project.pbxproj を更新

```bash
# 両方の MARKETING_VERSION を更新
MARKETING_VERSION = 1.3.0;

# 両方の CURRENT_PROJECT_VERSION を更新  
CURRENT_PROJECT_VERSION = 1;
```

### 3. CHANGELOG.md を更新

```markdown
## [1.3.0] - 2025-XX-XX

### Added
- 新機能...

### Changed
- 変更内容...
```

### 4. リリースノート作成

```bash
cp RELEASE_NOTES_v1.2.0.md RELEASE_NOTES_v1.3.0.md
# 編集して新しいバージョンの内容に更新
```

### 5. コミットとタグ

```bash
git add -A
git commit -m "chore: bump version to 1.3.0"
git tag -a v1.3.0 -m "Release v1.3.0"
git push origin main
git push origin v1.3.0
```

## 🎯 使用箇所

AppVersion は以下の場所で使用されます：

### 1. About ページ（設定画面）

```swift
// PlayCoverManager/Views/SettingsRootView.swift
private var appVersion: String {
    AppVersion.version  // "1.2.0"
}

private var buildNumber: String {
    AppVersion.build    // "1"
}
```

### 2. その他の利用可能なプロパティ

```swift
AppVersion.version         // "1.2.0"
AppVersion.build          // "1"
AppVersion.fullVersion    // "1.2.0 (Build 1)"
AppVersion.shortVersion   // "v1.2.0"
AppVersion.bundleVersion  // Info.plist から取得（フォールバック有）
AppVersion.bundleBuild    // Info.plist から取得（フォールバック有）
AppVersion.isSynced       // バージョンが同期されているか確認
```

## ✅ 利点

### 一元管理
- ✅ バージョン定義が1箇所（AppVersion.swift）
- ✅ Bundle.main へのフォールバック対応
- ✅ 型安全なアクセス

### メンテナンス性
- ✅ バージョン変更時の修正箇所が明確
- ✅ ビルド時にバージョン不一致を検出可能
- ✅ 自動化スクリプトとの統合が容易

### 拡張性
- ✅ 新しいバージョンフォーマットを簡単に追加可能
- ✅ カスタムバージョン文字列の生成が容易

## 🚨 注意事項

### プロジェクト設定との同期

**重要**: AppVersion.swift のバージョンと project.pbxproj の MARKETING_VERSION は **手動で同期** する必要があります。

#### 確認方法

```bash
# AppVersion.swift のバージョン
grep "static let version" PlayCoverManager/Utils/AppVersion.swift

# project.pbxproj のバージョン
grep "MARKETING_VERSION" PlayCoverManager.xcodeproj/project.pbxproj
```

#### 同期確認コード

```swift
// 実行時に同期を確認
if !AppVersion.isSynced {
    print("⚠️ Warning: Version mismatch!")
    print("AppVersion: \(AppVersion.version)")
    print("Bundle: \(AppVersion.bundleVersion)")
}
```

## 📚 参考

- [Semantic Versioning](https://semver.org/)
- [Apple Version Numbers](https://developer.apple.com/documentation/bundleresources/information_property_list/cfbundleshortversionstring)

---

**更新日**: 2025-11-13  
**対象バージョン**: PlayCover Manager 1.2.0+
