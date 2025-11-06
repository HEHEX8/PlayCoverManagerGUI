# プロジェクト全体の重複処理分析レポート

## 概要

PlayCoverManagerプロジェクト内で重複している処理を調査し、共通化の提案を行います。

---

## 🔴 1. アプリ実行状態チェック (**最重要**)

### 重複箇所

| ファイル | 関数名 | アクセス修飾子 | 実装 |
|---------|--------|--------------|------|
| `LauncherService.swift:144` | `checkIfAppRunning` | `private` | 同一実装 |
| `InstallerService.swift:72` | `isAppRunning` | `public` | 同一実装 |
| `AppUninstallerService.swift:198` | `isAppRunning` | `nonisolated` | 同一実装 |
| `IPAInstallerService.swift:493` | `isAppRunning` | `nonisolated` | 同一実装 |

### 実装内容（すべて同一）

```swift
func [check|is]AppRunning(bundleID: String) -> Bool {
    let runningApps = NSWorkspace.shared.runningApplications
    return runningApps.contains { app in
        app.bundleIdentifier == bundleID && !app.isTerminated
    }
}
```

### 推奨される共通化方法

**Option A: LauncherServiceを共通サービスとして使用**
- 既に`LauncherService`が`fetchInstalledApps()`で使用している
- `checkIfAppRunning`を`public`にして他のサービスから参照

**Option B: 新しい共通ユーティリティクラス作成**
- `AppRuntimeService`や`AppStateService`などの専用クラス
- すべてのサービスがDIで受け取る

**推奨: Option A** - 既存の`LauncherService`は既にアプリ状態管理の責務を持っているため

---

## 🟡 2. Container URL 生成

### 重複箇所

| ファイル | 行番号 | 実装パターン |
|---------|--------|------------|
| `LauncherViewModel.swift:393` | 関数 | `containerURL(for:)` メソッド |
| `AppUninstallerService.swift:128,292` | インライン | `.appendingPathComponent("Library/Containers/\(bundleID)")` |
| `AppUninstallerService.swift:244,250,256` | インライン | PlayCover設定ファイル用パス生成 |

### 実装内容

**LauncherViewModel:**
```swift
private func containerURL(for bundleIdentifier: String) -> URL {
    let containersRoot = PlayCoverPaths.defaultContainerRoot()
    return containersRoot.appendingPathComponent(bundleIdentifier, isDirectory: true)
}
```

**AppUninstallerService (直接記述):**
```swift
FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Containers/\(bundleID)", isDirectory: true)
```

### 推奨される共通化方法

**Option A: PlayCoverPathsに静的メソッド追加**
```swift
extension PlayCoverPaths {
    static func containerURL(for bundleID: String) -> URL {
        return defaultContainerRoot().appendingPathComponent(bundleID, isDirectory: true)
    }
    
    static func appSettingsURL(for bundleID: String) -> URL {
        // PlayCover設定ファイル用
    }
}
```

**推奨: Option A** - `PlayCoverPaths`は既にパス管理の責務を持っている

---

## 🟡 3. diskutil コマンド実行

### 使用箇所

| ファイル | 使用回数 | 用途 |
|---------|---------|------|
| `DiskImageService.swift` | 7回 | ディスクイメージ作成・マウント・アンマウント |
| `PlayCoverEnvironmentService.swift` | 2回 | 初期セットアップ時のマウント |
| `AppUninstallerService.swift` | 1回 | アンインストール時の情報取得 |
| `LauncherViewModel.swift` | 4回 | 外部ドライブ検知・取り出し |

### 実装パターン

**ProcessRunner経由（DiskImageService, PlayCoverEnvironmentService）:**
```swift
try await processRunner.run("/usr/sbin/diskutil", args)
```

**直接Process使用（LauncherViewModel）:**
```swift
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
process.arguments = args
try process.run()
```

### 推奨される共通化方法

**統一方針: すべてProcessRunner経由に統一**
- LauncherViewModelの直接Process使用を`processRunner`経由に変更
- 理由: エラーハンドリング、テスト容易性、一貫性

**追加の提案: DiskImageServiceにdiskutil専用メソッド追加**
```swift
extension DiskImageService {
    func getDiskInfo(for path: URL) async throws -> [String: Any] {
        // diskutil info -plist の共通化
    }
    
    func isExternalDrive(_ url: URL) async throws -> Bool {
        // 外部ドライブ判定の共通化
    }
}
```

---

## 🟡 4. マウント状態チェック

### 重複箇所

| ファイル | 実装 |
|---------|------|
| `DiskImageService.swift:38-68` | `diskImageDescriptor()` - 標準的な実装 |
| `LauncherViewModel.swift:486-501` | インライン - PlayCoverコンテナ専用 |

### 実装内容

**DiskImageService（標準）:**
```swift
func diskImageDescriptor(for bundleIdentifier: String, containerURL: URL) throws -> DiskImageDescriptor {
    let output = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", mountPoint.path])
    // plist解析してisMountedを判定
}
```

**LauncherViewModel（重複）:**
```swift
// PlayCoverコンテナのマウント確認のため独自実装
var isMounted = false
do {
    let output = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", playCoverContainer.path])
    // ほぼ同じ処理
}
```

### 推奨される共通化方法

**LauncherViewModelのインライン実装を削除し、DiskImageServiceを使用**
```swift
// Before (LauncherViewModel)
var isMounted = false
do {
    let output = try processRunner.runSync(...)
    // 独自実装
}

// After (LauncherViewModel)
// DiskImageServiceのメソッドを追加
func isMounted(at url: URL) throws -> Bool {
    // diskImageDescriptorから抽出
}
```

---

## 🟢 5. ProcessRunner インスタンス化

### 使用箇所

すべてのサービスクラスが`ProcessRunner`を保持:
- `DiskImageService`
- `InstallerService`
- `PlayCoverEnvironmentService`
- `AppUninstallerService`
- `IPAInstallerService`
- `LauncherViewModel`

### 現状

各サービスが個別に`ProcessRunner()`をインスタンス化している。

### 推奨される共通化方法

**現状維持を推奨**

理由:
- ProcessRunnerはステートレスなユーティリティクラス
- DIパターンとして適切（テストで注入可能）
- メモリオーバーヘッドは無視できるレベル
- 各サービスが独立している方が管理しやすい

---

## 🟢 6. ファイルロック処理

### 実装箇所

`ContainerLockService.swift` のみ

### 評価

✅ **重複なし** - 既に専用サービスクラスとして適切に分離されている

---

## 📊 優先度付き共通化推奨リスト

### 🔴 高優先度（即座に対応すべき）

1. **アプリ実行状態チェック**
   - 影響範囲: 4ファイル
   - 重複度: 100%同一コード
   - 推奨: `LauncherService.checkIfAppRunning()`を`public`化して共通利用

### 🟡 中優先度（時間があれば対応）

2. **Container URL生成**
   - 影響範囲: 2-3ファイル
   - 推奨: `PlayCoverPaths`に静的メソッド追加

3. **diskutil実行の統一**
   - 影響範囲: LauncherViewModel
   - 推奨: 直接Process使用をProcessRunner経由に変更

4. **マウント状態チェック**
   - 影響範囲: LauncherViewModel
   - 推奨: DiskImageServiceのメソッドを使用

### 🟢 低優先度（現状維持でOK）

5. **ProcessRunnerインスタンス化**
   - 現状: 各サービスが個別保持
   - 評価: DIパターンとして適切、変更不要

6. **ファイルロック処理**
   - 現状: ContainerLockService に集約済み
   - 評価: 問題なし

---

## 🎯 推奨される実装順序

### Phase 1: アプリ実行状態チェックの共通化

```swift
// LauncherService.swift
public func checkIfAppRunning(bundleID: String) -> Bool {  // privateからpublicに変更
    let runningApps = NSWorkspace.shared.runningApplications
    return runningApps.contains { app in
        app.bundleIdentifier == bundleID && !app.isTerminated
    }
}

// 各サービスから呼び出し
// InstallerService, AppUninstallerService, IPAInstallerServiceの
// isAppRunning()を削除し、LauncherService経由で呼び出す
```

### Phase 2: Container URL生成の共通化

```swift
// PlayCoverPaths.swift
extension PlayCoverPaths {
    static func containerURL(for bundleID: String) -> URL {
        return defaultContainerRoot().appendingPathComponent(bundleID, isDirectory: true)
    }
    
    static func appSettingsURL(playCoverBundleID: String, appBundleID: String) -> URL {
        return defaultContainerRoot()
            .appendingPathComponent("\(playCoverBundleID)/App Settings/\(appBundleID).plist")
    }
    
    // 他の設定ファイルパスも同様に追加
}
```

### Phase 3: diskutil実行の統一

```swift
// LauncherViewModel.swift
// 直接Processを使っている箇所をprocessRunner経由に変更
// isExternalDrive(), getDevicePath(), ejectDrive()
```

---

## 📈 期待される効果

### コード削減

- **削除可能な重複コード**: 約150-200行
- **共通化後の新規コード**: 約50行
- **純削減**: 約100-150行

### 保守性向上

- **変更箇所の集約**: アプリ実行状態チェックの修正が1箇所で済む
- **テスト容易性**: 共通化したメソッドを一度テストすれば全体に適用
- **バグ削減**: 同じロジックの重複実装によるバグの可能性を排除

### パフォーマンス

- **実行時**: ほぼ変化なし（メソッド呼び出しのオーバーヘッドは無視できる）
- **メモリ**: わずかに削減（コードサイズ減少）

---

## 結論

**最優先で対応すべきは「アプリ実行状態チェック」の共通化です。**

4つのファイルで完全に同一のロジックが重複しており、保守性とバグリスクの観点から即座に共通化すべきです。
