# Bug Fix: PlayCover Container Unmount and Auto-Unmount Issues

## Date: 2025-11-06

## Issues Fixed

### 1. PlayCover Container Not Unmounting in "All Unmount" Operation
**Problem**: When using the "All Unmount" button, individual app containers unmounted successfully, but the PlayCover container did not unmount, and no error or result dialog was displayed.

**Root Cause**: 
- The code checked if the PlayCover container directory exists (`fileManager.fileExists`) but did not verify if it was actually **mounted**
- `diskImageService.detach()` uses `diskutil unmount force` which fails if the volume is not mounted
- When the container wasn't mounted, `detach()` threw an error, causing the process to abort silently

**Fix**: 
- Added proper mount status check using `diskutil info -plist` before attempting unmount
- Only attempt unmount if the volume is actually mounted (has a VolumeName in diskutil output)
- If not mounted, skip unmount gracefully without error

**Code Changes** (`LauncherViewModel.swift` lines 432-465):
```swift
// Before:
if fileManager.fileExists(atPath: playCoverContainer.path) {
    try await diskImageService.detach(volumeURL: playCoverContainer)
    // ^ This fails if not mounted
}

// After:
if fileManager.fileExists(atPath: playCoverContainer.path) {
    // Check if it's actually mounted first
    let output = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", playCoverContainer.path])
    if let data = output.data(using: .utf8),
       let plist = try? PropertyListSerialization.propertyList(...),
       let _ = plist["VolumeName"] as? String {
        // It's mounted, safe to unmount
        try await diskImageService.detach(volumeURL: playCoverContainer)
    }
}
```

### 2. Result Dialog Not Displaying Before App Quit
**Problem**: The results dialog showing unmount success/failure did not appear before the app terminated.

**Root Cause**:
- The status overlay (`isBusy = true`, `isShowingStatus = true`) was still visible when trying to show the alert
- Race condition between UI updates and alert display

**Fix**:
- Explicitly hide the status overlay on MainActor before showing the alert
- Added a small delay (100ms) to allow UI to update
- Added extensive debug logging to track execution flow

**Code Changes** (`LauncherViewModel.swift` `showUnmountResultAndQuit` method):
```swift
await MainActor.run {
    // Hide the status overlay before showing the alert
    self.isBusy = false
    self.isShowingStatus = false
}

// Give UI a moment to update
try? await Task.sleep(for: .milliseconds(100))

await MainActor.run {
    let alert = NSAlert()
    // ... configure alert ...
    alert.runModal()  // Now displays properly
    NSApplication.shared.terminate(nil)
}
```

### 3. Auto-Unmount on App Termination Not Working
**Problem**: When an iOS app terminates, its container should auto-unmount, but this wasn't happening.

**Potential Root Causes** (needs testing to confirm):
1. NSWorkspace notification not firing
2. App not recognized as "managed app"
3. Lock check preventing unmount
4. diskutil detach failing silently

**Existing Debug Logging**:
The code already has extensive debug logging for this feature:
- `[LauncherVM] App terminated: <bundleID>`
- `[LauncherVM] Is managed app: <true/false>`
- `[LauncherVM] Starting auto-unmount for <bundleID>`
- `[LauncherVM] Container is mounted, checking for locks`
- `[LauncherVM] Successfully unmounted container`

**Next Steps**: User should test with the current changes and provide console output to diagnose the exact cause.

## Technical Implementation Details

### New Dependency: ProcessRunner
Added `ProcessRunner` to `LauncherViewModel` to enable synchronous diskutil checks:

**Changes**:
1. Added property: `private let processRunner: ProcessRunner`
2. Updated init to accept processRunner parameter (with default value)
3. Updated `AppViewModel.swift` to pass ProcessRunner instance

### Mount Status Detection
The fix uses the same approach as `DiskImageService.diskImageDescriptor()`:
```swift
diskutil info -plist <path>
```
Returns plist with:
- `VolumeName`: Present if mounted
- `DeviceNode`: Device path (e.g., /dev/disk2s1)
- `Internal`: Whether internal or external drive

### Unmount Sequence (Correct Flow)
1. **Individual App Containers**: Unmount all app containers
   - If any fail → Show error and abort
2. **PlayCover Container**: Unmount PlayCover's container
   - Only if mounted (new check)
   - If fails → Show error and abort
3. **External Drive Eject**: If on external drive, eject entire drive
   - If fails → Continue anyway (leave to Finder/System)
4. **Results Dialog**: Show results and quit
   - Now properly displays after hiding status overlay

## Debug Logging Added

All critical operations now have extensive logging:
- `[LauncherVM]` prefix for LauncherViewModel operations
- Logs for: mount checks, unmount attempts, success/failure, alert display
- Helps diagnose issues through Console.app

## Files Modified

1. **PlayCoverManager/ViewModels/LauncherViewModel.swift**
   - Added `processRunner` property and init parameter
   - Fixed PlayCover container unmount with proper mount check
   - Improved result dialog display with UI update timing

2. **PlayCoverManager/ViewModels/AppViewModel.swift**
   - Updated LauncherViewModel instantiation to pass ProcessRunner

## Testing Recommendations

1. **PlayCover Container Unmount**: 
   - Test with PlayCover container mounted
   - Test with PlayCover container not mounted
   - Verify proper dialog display before quit

2. **Auto-Unmount**:
   - Launch an iOS app
   - Quit the iOS app
   - Check Console.app for `[LauncherVM]` logs
   - Verify container unmounts automatically

3. **External Drive Eject**:
   - Test with containers on external drive
   - Verify eject command sent after unmount
   - Check if drive becomes safely removable

## Known Limitations

1. **Auto-Unmount Issue**: Still needs diagnosis through console logs
2. **Force Unmount**: Uses `diskutil unmount force` which may fail if files are in use
3. **No Partial Unmount**: All operations must succeed or entire process aborts

## References

- `diskutil` man page: https://ss64.com/osx/diskutil.html
- Swift Concurrency: MainActor, Task.sleep
- NSWorkspace notifications for app termination
- File locking with flock() system call
