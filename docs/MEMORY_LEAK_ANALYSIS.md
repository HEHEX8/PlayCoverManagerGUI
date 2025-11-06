# メモリリーク・キャッシュ肥大化分析レポート

## 🔴 発見された問題

### 1. **アイコンキャッシュ未実装** - 高優先度

**問題箇所**: `LauncherService.fetchInstalledApps()`

```swift
let icon = NSWorkspace.shared.icon(forFile: url.path)  // 毎回ロード
let app = PlayCoverApp(..., icon: icon, ...)
```

**問題点**:
- `refresh()` が呼ばれるたびに全アプリのアイコンを再ロード
- NSImageは大きなメモリを消費（各アイコン数百KB〜数MB）
- アイコンは変更されないのに毎回ロード

**影響**:
- メモリ使用量が増加
- UIのパフォーマンス低下
- 不要なディスクI/O

**推奨修正**:
- NSCacheでアイコンをキャッシュ
- bundleIdentifierをキーにしてキャッシュ
- メモリプレッシャー時に自動解放

---

### 2. **ProcessRunner: Pipe未クローズ** - 中優先度

**問題箇所**: `ProcessRunner.run()` および `runSync()`

```swift
let stdoutPipe = Pipe()
let stderrPipe = Pipe()
process.standardOutput = stdoutPipe
process.standardError = stderrPipe
// ...
let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
// FileHandle が明示的にクローズされていない
```

**問題点**:
- Pipeから取得したFileHandleが自動クローズに依存
- 大量のプロセス実行でファイルディスクリプタが枯渇する可能性

**推奨修正**:
- readDataToEndOfFile() 後に明示的にクローズ
- deferブロックで確実にクローズ

---

### 3. **LauncherViewModel: apps配列の肥大化リスク** - 低優先度

**問題箇所**: `LauncherViewModel`

```swift
var apps: [PlayCoverApp]
var filteredApps: [PlayCoverApp]
```

**問題点**:
- PlayCoverAppがNSImage?を保持
- refresh()のたびに新しい配列を作成
- 古い配列がすぐに解放されない可能性

**現状評価**:
- SwiftUIの@Observableにより適切に管理されている可能性が高い
- PlayCoverAppの数は通常少ない（10-50個程度）
- 現時点では問題なし

---

### 4. **ContainerLockService: activeLocks辞書** - 問題なし ✅

**評価**:
- `deinit`で適切にクリーンアップ
- `unlockContainer()`で適切に削除
- FileHandleも正しくクローズ
- ✅ 問題なし

---

### 5. **FileHandle リーク潜在リスク** - 低優先度

**問題箇所**: `ContainerLockService.canLockContainer()`

```swift
let fileHandle = try FileHandle(forUpdating: lockFileURL)
// ...
if result == 0 {
    flock(fd, LOCK_UN)
    try? fileHandle.close()  // ✅ OK
    return true
} else {
    try? fileHandle.close()  // ✅ OK
    return false
}
```

**評価**:
- 両方のパスでクローズ済み
- ✅ 問題なし

---

### 6. **readDataToEndOfFile() の大量使用** - 注意

**問題箇所**: 複数ファイル

```swift
// Info.plistの読み込み
let data = try Data(contentsOf: infoPlistURL)

// diskutil出力の読み込み
let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
```

**評価**:
- Info.plistは通常小さい（数KB〜数十KB）
- diskutil出力も通常小さい
- ⚠️ 問題になるのは大きなファイルを読む場合のみ
- 現状の使用では問題なし

---

## 📊 優先度付き修正リスト

### 🔴 高優先度（即座に修正すべき）

1. **アイコンキャッシュの実装**
   - NSCacheを使用
   - bundleIdentifierをキーに
   - メモリ削減効果大

### 🟡 中優先度（できれば修正）

2. **ProcessRunner: FileHandleの明示的クローズ**
   - Pipeのファイルハンドルをクローズ
   - ファイルディスクリプタ枯渇防止

### 🟢 低優先度（現状問題なし）

3. **その他の項目**
   - 現時点では問題なし
   - モニタリング継続

---

## 🔧 推奨実装

### 修正1: アイコンキャッシュの実装

```swift
// LauncherService に追加
private let iconCache = NSCache<NSString, NSImage>()

init(...) {
    // ...
    iconCache.countLimit = 100  // 最大100アイコン
    iconCache.totalCostLimit = 50 * 1024 * 1024  // 50MB
}

func fetchInstalledApps(at applicationsRoot: URL) throws -> [PlayCoverApp] {
    // ...
    for url in contents where url.pathExtension == "app" {
        // ...
        let icon = getCachedIcon(for: bundleID, appURL: url)
        let app = PlayCoverApp(..., icon: icon, ...)
        // ...
    }
}

private func getCachedIcon(for bundleID: String, appURL: URL) -> NSImage? {
    let cacheKey = bundleID as NSString
    
    if let cachedIcon = iconCache.object(forKey: cacheKey) {
        return cachedIcon
    }
    
    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
    iconCache.setObject(icon, forKey: cacheKey)
    return icon
}
```

### 修正2: ProcessRunner: FileHandleクローズ

```swift
func run(...) async throws -> String {
    // ...
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    
    defer {
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()
    }
    
    process.waitUntilExit()
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    // ...
}

func runSync(...) throws -> String {
    // ...
    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    
    defer {
        try? stdoutPipe.fileHandleForReading.close()
        try? stderrPipe.fileHandleForReading.close()
    }
    
    try process.run()
    process.waitUntilExit()
    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
    // ...
}
```

---

## 📈 期待される効果

### アイコンキャッシュ実装後

**メモリ削減**:
- アプリ20個、各アイコン500KB想定
- Before: refresh()ごとに 20 × 500KB = 10MB ロード
- After: 初回のみ10MB、以降は再利用
- **削減効果**: refresh 10回で 90MB のメモリ削減

**パフォーマンス向上**:
- ディスクI/O削減
- UI描画の高速化
- スムーズなrefresh

### FileHandleクローズ後

**安定性向上**:
- ファイルディスクリプタ枯渇防止
- 長時間実行時の安定性向上
- リソースリーク防止

---

## ⚠️ その他の注意点

### 問題なし項目

1. **ContainerLockService** - 適切に管理されている
2. **LauncherViewModel配列** - 通常の使用では問題なし
3. **Info.plist読み込み** - ファイルサイズが小さいため問題なし
4. **Timer** - 使用なし
5. **Strong Reference Cycles** - [weak self]が適切に使用されている

### モニタリング推奨

- `apps`配列のサイズ（アプリ数が100を超える場合）
- `iconCache`のヒット率
- メモリ使用量の推移

---

## 結論

**即座に修正すべき問題**: 1件（アイコンキャッシュ）
**できれば修正**: 1件（FileHandleクローズ）
**問題なし**: その他全て

アイコンキャッシュの実装により、大幅なメモリ削減とパフォーマンス向上が期待できます。
