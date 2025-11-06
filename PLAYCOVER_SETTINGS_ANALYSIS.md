# PlayCover AppSettings 解析結果

## 概要

PlayCover の `AppSettings.swift` を解析し、アプリ毎に保存される設定を抽出しました。
これらの設定は `~/Library/Containers/io.playcover.PlayCover/App Settings/<bundleID>.plist` に保存されます。

## 設定項目の完全リスト

### 1. Keymapping / Controls
```swift
var keymapping = true                    // キーマッピング有効化
var sensitivity: Float = 50              // マウス感度 (0-100)
var noKMOnInput = true                   // テキスト入力時はキーマップ無効化
var enableScrollWheel = true             // スクロールホイール有効化
var disableBuiltinMouse = false          // 組み込みマウス無効化
```

### 2. Graphics / Display
```swift
var iosDeviceModel = "iPad13,8"          // iOS デバイスモデル (M1 iPad Pro 12.9")
var windowWidth = 1920                   // ウィンドウ幅
var windowHeight = 1080                  // ウィンドウ高さ
var customScaler = 2.0                   // カスタムスケーラー
var resolution = 1                       // 解像度プリセット (0=Auto, 1=1080p, 2=1440p, 3=4K, 4=Custom)
var aspectRatio = 1                      // アスペクト比 (0=4:3, 1=16:9, 2=16:10, 3=Custom)
var notch: Bool = NSScreen.hasNotch()   // ノッチ対応
var hideTitleBar = false                 // タイトルバー非表示
var floatingWindow = false               // フローティングウィンドウ
var metalHUD = false                     // Metal HUD 表示
var resizableAspectRatioType = 0         // リサイズ可能なアスペクト比タイプ
var resizableAspectRatioWidth = 0        // カスタムアスペクト比幅
var resizableAspectRatioHeight = 0       // カスタムアスペクト比高さ
```

### 3. System / Advanced
```swift
var disableTimeout = false               // ディスプレイスリープ無効化
var bypass = false                       // Jailbreak 検出バイパス
var playChain = true                     // PlayChain 有効化 (DRM)
var playChainDebugging = false           // PlayChain デバッグモード
var windowFixMethod = 0                  // ウィンドウ修正方法
var rootWorkDir = true                   // ルート作業ディレクトリ使用
var inverseScreenValues = false          // 画面値反転
var injectIntrospection = false          // Introspection 注入
var checkMicPermissionSync = false       // マイク権限チェック同期
var limitMotionUpdateFrequency = false   // モーション更新頻度制限
```

### 4. Discord Integration
```swift
var discordActivity = DiscordActivity()  // Discord Rich Presence
```

### 5. Metadata
```swift
var bundleIdentifier: String = ""        // バンドル ID
var version = "3.0.0"                    // 設定バージョン
```

## 保存形式

**ファイル形式**: XML Property List (.plist)
**保存場所**: `~/Library/Containers/io.playcover.PlayCover/App Settings/<bundleID>.plist`
**エンコーディング**: PropertyListEncoder (XML format)

## 移植計画

### Phase 1: Core Settings (最優先)
PlayCoverManager で既に実装済みまたは重要度の高い設定：

1. ✅ **nobrowse** (既存実装) - ディスクイメージを Finder に表示しない
2. ✅ **dataHandlingStrategy** (既存実装) - 内部データ処理方法
3. 🔲 **iosDeviceModel** - デバイスモデル選択
4. 🔲 **resolution** - 解像度プリセット
5. 🔲 **aspectRatio** - アスペクト比
6. 🔲 **windowWidth/windowHeight** - カスタム解像度
7. 🔲 **disableTimeout** - ディスプレイスリープ無効化

### Phase 2: Keymapping Settings
キーマッピング関連（PlayTools に依存）：

1. 🔲 **keymapping** - キーマッピング有効化
2. 🔲 **sensitivity** - マウス感度
3. 🔲 **noKMOnInput** - テキスト入力時の自動無効化
4. 🔲 **enableScrollWheel** - スクロールホイール

### Phase 3: Advanced Settings
高度な設定（上級ユーザー向け）：

1. 🔲 **bypass** - Jailbreak 検出バイパス
2. 🔲 **playChain** - PlayChain (DRM 保護)
3. 🔲 **hideTitleBar** - タイトルバー非表示
4. 🔲 **floatingWindow** - フローティングウィンドウ
5. 🔲 **metalHUD** - Metal パフォーマンス HUD

### Phase 4: UI Enhancements
ウィンドウ表示の最適化：

1. 🔲 **resizableAspectRatio** - カスタムアスペクト比
2. 🔲 **windowFixMethod** - ウィンドウ修正方法
3. 🔲 **notch** - ノッチ対応

## 互換性戦略

### PlayCover との設定共有

**目標**: PlayCover と PlayCoverManager で同じ plist ファイルを共有

**実装方法**:
1. 同じファイルパス `~/Library/Containers/io.playcover.PlayCover/App Settings/<bundleID>.plist` を使用
2. PlayCover の `AppSettingsData` 構造体と互換性のある Codable 実装
3. PlayCoverManager 独自の設定は別ファイルに保存（`<bundleID>.pcm.plist`）

**メリット**:
- PlayCover で設定した内容が PlayCoverManager で反映される
- PlayCoverManager で設定した内容が PlayCover で反映される
- ユーザーは片方だけで設定すればOK

### 実装アプローチ

```swift
// PlayCover 互換の設定
struct PlayCoverAppSettings: Codable {
    var bundleIdentifier: String = ""
    var keymapping = true
    var sensitivity: Float = 50
    // ... 全ての PlayCover 設定
}

// PlayCoverManager 独自の設定
struct PlayCoverManagerSettings: Codable {
    var nobrowse: Bool? = nil  // nil = use global
    var dataHandlingStrategy: String? = nil  // nil = use global
    // ... 追加の設定
}

// 統合された設定ストア
class AppSettingsStore {
    private var playCoverSettings: PlayCoverAppSettings
    private var managerSettings: PlayCoverManagerSettings
    
    // PlayCover の plist を読み書き
    func loadPlayCoverSettings() { ... }
    func savePlayCoverSettings() { ... }
    
    // PlayCoverManager の plist を読み書き
    func loadManagerSettings() { ... }
    func saveManagerSettings() { ... }
}
```

## UI 設計案

### 設定画面の構成

```
┌─ アプリ設定 ──────────────────────────┐
│ [Graphics] [Controls] [Advanced] [Info]│
├────────────────────────────────────────┤
│                                         │
│ Graphics タブ:                          │
│   iOS Device: [iPad13,8 ▼]            │
│   Resolution: [1080p ▼]                │
│   Aspect Ratio: [16:9 ▼]              │
│   Custom Resolution: [1920] x [1080]   │
│   □ Disable Display Sleep              │
│   □ Hide Title Bar                     │
│                                         │
│ Controls タブ:                          │
│   □ Enable Keymapping                  │
│   Mouse Sensitivity: [━━●━━━━━] 50     │
│   □ Disable KM on Text Input           │
│   □ Enable Scroll Wheel                │
│                                         │
│ Advanced タブ:                          │
│   □ Jailbreak Detection Bypass         │
│   □ PlayChain (DRM Protection)         │
│   □ Metal HUD                          │
│   Window Fix Method: [Default ▼]       │
│                                         │
│ Info タブ:                              │
│   Bundle ID: com.example.app           │
│   Settings Version: 3.0.0              │
│   Saved: 2025-11-05 17:00:00           │
│                                         │
└─────────────────────────────────────────┘
```

## 次のステップ

1. ✅ PlayCover の設定構造を完全に理解
2. 🔲 PlayCover 互換の `AppSettingsData` 構造体を実装
3. 🔲 既存の `PerAppSettingsStore` を拡張して PlayCover 設定をサポート
4. 🔲 設定 UI を実装（タブ分け）
5. 🔲 PlayCover の plist ファイルとの読み書き互換性をテスト

## 参考リンク

- PlayCover GitHub: https://github.com/PlayCover/PlayCover
- PlayCover ドキュメント: https://docs.playcover.io/
- AppSettings.swift: https://github.com/PlayCover/PlayCover/blob/develop/PlayCover/Model/AppSettings.swift
