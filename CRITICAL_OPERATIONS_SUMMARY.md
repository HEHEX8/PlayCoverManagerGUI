# Critical Operation Protection Summary

## Overview
Applied `CriticalOperationService` protection to all critical operations throughout the codebase to prevent app termination (⌘Q/⌘W) during important operations.

## Protected Operations by File

### 1. PlayCoverManager/Views/SettingsRootView.swift
- **IPAInstallerSheet.startInstallation()** - "IPA インストール"
- **AppUninstallerSheet.startUninstallation()** - "アプリのアンインストール"

### 2. PlayCoverManager/ViewModels/LauncherViewModel.swift
- **createImageAndResume()** - "ディスクイメージ作成"
- **handleInternalData()** - "内部データ処理"
- **mergeInternalData()** - "内部データマージ"
- **performUnmountAllAndQuit()** - "全てのディスクイメージをアンマウント"
- **performForceUnmountAllAndQuit()** - "強制アンマウント"
- **performForceUnmountForStorageChange()** - "ストレージ変更の強制アンマウント"
- **performUnmountForStorageChange()** - "ストレージ変更のアンマウント"

### 3. PlayCoverManager/ViewModels/AppViewModel.swift
- **ensureContainerMounted()** - "PlayCover コンテナマウント"
- **unmountPlayCoverContainer()** - "PlayCover コンテナアンマウント"
- **unmountAllContainersForTermination()** - "終了時の全コンテナアンマウント"

### 4. PlayCoverManager/ViewModels/SetupWizardViewModel.swift
- **prepareDiskImage()** - "セットアップのディスクイメージ作成"

## Implementation Pattern

All protected operations follow this consistent pattern:

```swift
private func someOperation() async {
    await CriticalOperationService.shared.beginOperation("operation description")
    defer {
        Task { @MainActor in
            await CriticalOperationService.shared.endOperation()
        }
    }
    
    // ... operation code ...
}
```

## Benefits

1. **Prevents Data Loss**: Users cannot accidentally quit the app during critical operations
2. **User Feedback**: Alert dialog explains why termination is blocked
3. **Automatic Cleanup**: `defer` blocks ensure protection is always released
4. **Consistent Pattern**: Same implementation across all critical operations
5. **Comprehensive Coverage**: All disk operations, installations, and unmounts are protected

## Testing Checklist

- [ ] Install IPA while protected (⌘Q should show alert)
- [ ] Uninstall app while protected (⌘Q should show alert)
- [ ] Create disk image while protected (⌘Q should show alert)
- [ ] Unmount operations while protected (⌘Q should show alert)
- [ ] Verify protection is released after completion
- [ ] Verify normal termination works when no operations are active
