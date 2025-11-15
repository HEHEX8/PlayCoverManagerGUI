# Pre-Mount Feature Implementation Summary

## ✅ Implementation Complete

All compilation errors have been resolved. The pre-mount feature is ready for testing.

---

## 📋 Feature Requirements (User Specification)

### 1. **Startup Pre-mounting**
When PlayCoverManager starts, automatically mount the "last launched app" (the app shown in the "前回起動" button) in the background, so it's ready for instant launch when QuickLauncher appears.

### 2. **Smart Eject on Different App Launch**
If the pre-mounted app is NOT launched and a different app is launched instead, immediately eject the unused pre-mounted app.

### 3. **Keep Mounted While in Last Position**
The app in the "last launched" position should be exempt from auto-unmount - it stays mounted (orange state) as long as it holds that position.

### 4. **Eject on Position Change**
When a different app becomes the "last launched" app AND the old one is not running, immediately eject the old one.

---

## 🔧 Implementation Details

### Code Changes in `LauncherViewModel.swift`

#### 1. **Properties Added (Lines 75-76)**
```swift
// Pre-mount management for last launched apps
@ObservationIgnored private var preMountedApp: String? = nil  // Currently pre-mounted app bundle ID
@ObservationIgnored private var lastLaunchedApp: String? = nil  // Last launched app bundle ID
```

**Purpose**: Track which app is pre-mounted and which app holds the "last launched" position.

---

#### 2. **Modified `refresh()` to Trigger Pre-mount (Lines 355-358)**
```swift
// Pre-mount last launched app in background
Task.detached { [weak self] in
    await self?.preMountLastLaunchedApp()
}
```

**Purpose**: After app list is loaded, start pre-mounting the last launched app in the background.

**Behavior**:
- Uses `Task.detached` to run in background without blocking UI
- Weak self reference to prevent memory leaks
- Non-blocking - QuickLauncher appears immediately

---

#### 3. **Modified `handleAppTerminated()` to Skip Auto-unmount (Lines 232-234)**
```swift
// Skip auto-unmount if this is the last launched app (keep it pre-mounted)
if bundleID == lastLaunchedApp {
    Logger.lifecycle("Skipping auto-unmount for last launched app: \(bundleID)")
    return
}
```

**Purpose**: Prevent auto-eject for the last launched app.

**Behavior**:
- When app terminates, check if it's the `lastLaunchedApp`
- If yes, skip the 5-second auto-unmount timer
- Container stays mounted (orange state) for instant relaunch

---

#### 4. **New Function: `preMountLastLaunchedApp()` (Lines 1679-1737)**
```swift
/// Pre-mount last launched app for quick access
private func preMountLastLaunchedApp() async {
    guard let lastApp = apps.first(where: { $0.lastLaunchedFlag }) else {
        Logger.lifecycle("Pre-mount: No last launched app found")
        return
    }
    
    Logger.lifecycle("Pre-mount: Starting pre-mount for \(lastApp.displayName)")
    
    let containerURL = PlayCoverPaths.containerURL(for: lastApp.bundleIdentifier)
    
    do {
        let state = try DiskImageHelper.checkDiskImageState(
            for: lastApp.bundleIdentifier,
            containerURL: containerURL,
            diskImageService: diskImageService
        )
        
        guard state.imageExists else {
            Logger.lifecycle("Pre-mount: Disk image not found for \(lastApp.displayName)")
            return
        }
        
        if state.isMounted {
            Logger.lifecycle("Pre-mount: \(lastApp.displayName) already mounted")
            await MainActor.run {
                self.preMountedApp = lastApp.bundleIdentifier
                self.lastLaunchedApp = lastApp.bundleIdentifier
            }
            return
        }
        
        Logger.lifecycle("Pre-mount: Mounting \(lastApp.displayName)")
        try await DiskImageHelper.mountDiskImageIfNeeded(
            for: lastApp.bundleIdentifier,
            containerURL: containerURL,
            diskImageService: diskImageService,
            perAppSettings: perAppSettings,
            globalSettings: settings
        )
        Logger.lifecycle("Pre-mount: Successfully mounted \(lastApp.displayName)")
        
        await MainActor.run {
            self.preMountedApp = lastApp.bundleIdentifier
            self.lastLaunchedApp = lastApp.bundleIdentifier
        }
        
        await updateAppStatus(bundleID: lastApp.bundleIdentifier)
        
    } catch {
        Logger.error("Pre-mount: Failed to mount \(lastApp.displayName): \(error)")
    }
}
```

**Purpose**: Find and mount the last launched app in the background.

**Behavior**:
1. Searches for app with `lastLaunchedFlag = true`
2. Checks if disk image exists and is already mounted
3. If not mounted, mounts it using existing `DiskImageHelper`
4. Updates tracking variables on MainActor
5. Updates app status to show orange icon

---

#### 5. **New Function: `handlePreMountOnLaunch()` (Lines 1740-1760)**
```swift
/// Handle pre-mounted app when launching different app
func handlePreMountOnLaunch(launchedApp: PlayCoverApp) async {
    guard let preMounted = preMountedApp else { return }
    
    if launchedApp.bundleIdentifier == preMounted {
        Logger.lifecycle("Pre-mount: Launching pre-mounted app \(launchedApp.displayName)")
        return
    }
    
    Logger.lifecycle("Pre-mount: Different app launched, checking if pre-mounted app should be ejected")
    
    let isPreMountedRunning = await launcherService.isAppRunning(bundleID: preMounted)
    if !isPreMountedRunning {
        Logger.lifecycle("Pre-mount: Ejecting unused pre-mounted app")
        await immediateEjectContainer(for: preMounted)
    }
    
    preMountedApp = nil
}
```

**Purpose**: Handle the pre-mounted app when a different app is launched.

**Behavior**:
1. If launching the pre-mounted app → keep it mounted (do nothing)
2. If launching a different app:
   - Check if pre-mounted app is running
   - If not running → immediately eject it
   - Clear pre-mount tracking

---

#### 6. **New Function: `updateLastLaunchedTracking()` (Lines 1763-1778)**
```swift
/// Update last launched app tracking when app is launched
func updateLastLaunchedTracking(bundleID: String) async {
    if let previous = lastLaunchedApp, previous != bundleID {
        Logger.lifecycle("Pre-mount: Last launched app changed from \(previous) to \(bundleID)")
        
        let isPreviousRunning = await launcherService.isAppRunning(bundleID: previous)
        if !isPreviousRunning {
            Logger.lifecycle("Pre-mount: Ejecting previous last-launched app \(previous)")
            await immediateEjectContainer(for: previous)
        }
    }
    
    lastLaunchedApp = bundleID
}
```

**Purpose**: Handle position changes in the "last launched" slot.

**Behavior**:
1. Check if `lastLaunchedApp` has changed
2. If changed and previous app is not running:
   - Immediately eject the previous app
3. Update `lastLaunchedApp` to new value

---

#### 7. **Modified `performLaunch()` to Call Pre-mount Handlers (Lines 552-556)**
```swift
// Handle pre-mount logic (eject unused pre-mounted app)
await handlePreMountOnLaunch(launchedApp: app)

// Update last launched tracking
await updateLastLaunchedTracking(bundleID: app.bundleIdentifier)
```

**Purpose**: Integrate pre-mount logic into the main launch flow.

**Behavior**:
1. First handle pre-mount (eject if necessary)
2. Then update last-launched tracking (eject old one if necessary)
3. Both happen before app actually launches

---

#### 8. **Fixed Deprecation Warning (Line 418)**
Changed from:
```swift
runningApp.activate(options: .activateIgnoringOtherApps)
```

To:
```swift
runningApp.activate()
```

**Reason**: `activate(options:)` is deprecated in macOS 14.0+. Modern `activate()` is sufficient.

---

## 🧪 Testing Checklist

### Test Case 1: Startup Pre-mounting
**Steps**:
1. Quit PlayCoverManager completely
2. Launch PlayCoverManager
3. Wait for QuickLauncher to appear
4. Check if the "前回起動" app shows orange icon

**Expected Result**:
- Last launched app is mounted in background
- Orange icon appears when QuickLauncher is ready
- Launch is instant (no mounting delay)

**Log Messages to Look For**:
```
Pre-mount: Starting pre-mount for <AppName>
Pre-mount: Mounting <AppName>
Pre-mount: Successfully mounted <AppName>
```

---

### Test Case 2: Launch Pre-mounted App
**Steps**:
1. After startup, click the "前回起動" button to launch the pre-mounted app

**Expected Result**:
- App launches instantly (no mounting delay)
- No eject happens

**Log Messages to Look For**:
```
Pre-mount: Launching pre-mounted app <AppName>
```

---

### Test Case 3: Launch Different App (Eject Pre-mounted)
**Steps**:
1. After startup, launch a DIFFERENT app (not the pre-mounted one)
2. Check if the pre-mounted app gets ejected

**Expected Result**:
- Pre-mounted app is immediately ejected
- Only the newly launched app is mounted

**Log Messages to Look For**:
```
Pre-mount: Different app launched, checking if pre-mounted app should be ejected
Pre-mount: Ejecting unused pre-mounted app
```

---

### Test Case 4: Keep Mounted While in Last Position
**Steps**:
1. Launch App A
2. Quit App A (terminate it)
3. Wait 10 seconds (longer than normal auto-unmount delay)
4. Check if App A remains mounted (orange icon)

**Expected Result**:
- App A stays mounted (orange icon)
- No auto-unmount happens
- "Skipping auto-unmount" log appears

**Log Messages to Look For**:
```
Skipping auto-unmount for last launched app: <BundleID>
```

---

### Test Case 5: Eject on Position Change
**Steps**:
1. Launch App A (becomes last launched)
2. Quit App A
3. Launch App B (App B becomes new last launched)
4. Check if App A gets ejected

**Expected Result**:
- App A loses "last launched" position
- App A is immediately ejected
- App B is now mounted and becomes new last launched

**Log Messages to Look For**:
```
Pre-mount: Last launched app changed from <AppA> to <AppB>
Pre-mount: Ejecting previous last-launched app <AppA>
```

---

### Test Case 6: Position Change But Old App Still Running
**Steps**:
1. Launch App A (becomes last launched, running)
2. Launch App B (App B becomes new last launched)
3. Check if App A stays mounted (because it's still running)

**Expected Result**:
- App A keeps its mount (orange icon)
- No eject happens (app is still running)
- App B is also mounted

**Log Messages to Look For**:
```
Pre-mount: Last launched app changed from <AppA> to <AppB>
(No eject message should appear)
```

---

## 🎯 Success Criteria

✅ **All test cases pass**
✅ **No unexpected unmounts**
✅ **Instant launch for pre-mounted app**
✅ **Memory leaks prevented (weak self references)**
✅ **No blocking operations (background tasks)**

---

## 📝 Notes

- Uses existing `lastLaunchedFlag` system (no new persistence needed)
- Leverages existing `DiskImageHelper` for mounting
- Non-blocking design using `Task.detached`
- Proper MainActor isolation for UI state updates
- Comprehensive logging for debugging

---

## 🚀 Ready for Production Testing

The implementation is complete and ready for real-world testing in the PlayCoverManager environment.
