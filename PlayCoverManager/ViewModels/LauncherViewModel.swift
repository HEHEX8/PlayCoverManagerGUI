import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class LauncherViewModel {
    struct DataHandlingRequest: Identifiable {
        let id = UUID()
        let app: PlayCoverApp
        let existingItems: [URL]
    }

    private struct LaunchContext {
        let app: PlayCoverApp
        let containerURL: URL
    }

    var apps: [PlayCoverApp]
    var filteredApps: [PlayCoverApp]
    var searchText: String = "" {
        didSet { applySearch() }
    }
    var selectedApp: PlayCoverApp?
    var isBusy: Bool = false
    var isShowingStatus: Bool = false  // Only show status overlay for time-consuming operations
    var error: AppError?
    var pendingDataHandling: DataHandlingRequest?
    var pendingImageCreation: PlayCoverApp?
    var statusMessage: String = ""

    private let playCoverPaths: PlayCoverPaths
    private let diskImageService: DiskImageService
    private let launcherService: LauncherService
    private let settings: SettingsStore
    private let perAppSettings: PerAppSettingsStore
    private let fileManager: FileManager
    private let lockService: ContainerLockService
    private let processRunner: ProcessRunner

    private var pendingLaunchContext: LaunchContext?
    
    // Track running apps for termination detection
    private var previouslyRunningApps: Set<String> = []

    init(apps: [PlayCoverApp],
         playCoverPaths: PlayCoverPaths,
         diskImageService: DiskImageService,
         launcherService: LauncherService,
         settings: SettingsStore,
         perAppSettings: PerAppSettingsStore,
         lockService: ContainerLockService,
         processRunner: ProcessRunner = ProcessRunner(),
         fileManager: FileManager = .default) {
        self.apps = apps
        self.filteredApps = apps
        self.playCoverPaths = playCoverPaths
        self.diskImageService = diskImageService
        self.launcherService = launcherService
        self.settings = settings
        self.perAppSettings = perAppSettings
        self.lockService = lockService
        self.processRunner = processRunner
        self.fileManager = fileManager
        
        // Cleanup stale lock files on startup
        cleanupStaleLockFiles()
    }
    
    nonisolated deinit {
        // Nothing to clean up
    }
    
    private func cleanupStaleLockFiles() {
        // Get all container URLs for installed apps
        var containerURLs: [URL] = []
        for app in apps {
            let container = containerURL(for: app.bundleIdentifier)
            containerURLs.append(container)
        }
        
        // Also include PlayCover's container
        containerURLs.append(playCoverPaths.containerRootURL)
        
        // Cleanup stale locks
        lockService.cleanupStaleLocks(in: containerURLs)
    }

    func refresh() async {
        do {
            // Get current running state before refresh
            let oldRunningApps = Set(apps.filter { $0.isRunning }.map { $0.bundleIdentifier })
            
            // Refresh app list (includes isRunning check via LauncherService)
            let refreshed = try launcherService.fetchInstalledApps(at: playCoverPaths.applicationsRootURL)
            apps = refreshed
            applySearch()
            
            // Get new running state after refresh
            let newRunningApps = Set(apps.filter { $0.isRunning }.map { $0.bundleIdentifier })
            
            // Detect terminated apps (was running before, but not now)
            let terminatedApps = oldRunningApps.subtracting(newRunningApps)
            
            // Auto-unmount terminated apps
            for bundleID in terminatedApps {
                print("[LauncherVM] 🔍 Detected app termination: \(bundleID)")
                await unmountContainer(for: bundleID)
            }
            
            previouslyRunningApps = newRunningApps
        } catch {
            self.error = AppError.environment("アプリ一覧の更新に失敗", message: error.localizedDescription, underlying: error)
        }
    }

    func applySearch() {
        guard !searchText.isEmpty else {
            filteredApps = apps
            return
        }
        let query = searchText.lowercased()
        filteredApps = apps.filter { app in
            app.displayName.lowercased().contains(query) ||
            app.localizedName?.lowercased().contains(query) == true ||
            app.bundleIdentifier.lowercased().contains(query)
        }
    }

    func launch(app: PlayCoverApp) {
        Task { await performLaunch(app: app, resume: false) }
    }

    private func performLaunch(app: PlayCoverApp, resume: Bool) async {
        isBusy = true
        isShowingStatus = false  // Don't show status overlay for normal launch
        statusMessage = "\(app.displayName) を準備しています…"
        defer { 
            isBusy = false
            isShowingStatus = false
        }
        do {
            let containerURL = containerURL(for: app.bundleIdentifier)
            let descriptor = try diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: containerURL)
            guard fileManager.fileExists(atPath: descriptor.imageURL.path) else {
                pendingLaunchContext = LaunchContext(app: app, containerURL: containerURL)
                pendingImageCreation = app
                return
            }

            if !resume && !descriptor.isMounted {
                let internalItems = try detectInternalData(at: containerURL)
                if !internalItems.isEmpty {
                    pendingLaunchContext = LaunchContext(app: app, containerURL: containerURL)
                    pendingDataHandling = DataHandlingRequest(app: app, existingItems: internalItems)
                    return
                }
            }

            if !descriptor.isMounted {
                // Use per-app nobrowse setting if available, otherwise use global default
                let nobrowse = perAppSettings.getNobrowse(for: app.bundleIdentifier, globalDefault: settings.nobrowseEnabled)
                try await diskImageService.mountDiskImage(for: app.bundleIdentifier, at: containerURL, nobrowse: nobrowse)
            }

            // Acquire lock on container before launching
            let lockAcquired = lockService.lockContainer(for: app.bundleIdentifier, at: containerURL)
            print("[LauncherVM] 🔒 Lock acquired for \(app.bundleIdentifier): \(lockAcquired)")
            
            print("[LauncherVM] 🚀 Launching app: \(app.bundleIdentifier) (\(app.displayName))")
            try await launcherService.openApp(app)
            pendingLaunchContext = nil
            print("[LauncherVM] ✅ App launched successfully: \(app.bundleIdentifier)")
            
            // Refresh after a short delay to allow the app to start
            // This updates the "running" indicator
            Task {
                try? await Task.sleep(for: .seconds(0.5))
                await refresh()
            }
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage("アプリの起動に失敗", message: error.localizedDescription, underlying: error)
        }
    }

    func confirmImageCreation() {
        guard let context = pendingLaunchContext, let app = pendingImageCreation else { return }
        pendingImageCreation = nil
        Task {
            await createImageAndResume(app: app, context: context)
        }
    }

    func cancelImageCreation() {
        pendingImageCreation = nil
        pendingLaunchContext = nil
    }

    private func createImageAndResume(app: PlayCoverApp, context: LaunchContext) async {
        isBusy = true
        isShowingStatus = true  // Show status for disk image creation (time-consuming)
        statusMessage = "\(app.displayName) 用のディスクイメージを作成しています…"
        defer { 
            isBusy = false
            isShowingStatus = false
        }
        do {
            _ = try await diskImageService.ensureDiskImageExists(for: app.bundleIdentifier, volumeName: app.bundleIdentifier)
            pendingLaunchContext = nil
            Task { await performLaunch(app: app, resume: true) }
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage("ディスクイメージの作成に失敗", message: error.localizedDescription, underlying: error)
        }
    }

    func applyDataHandling(strategy: SettingsStore.InternalDataStrategy) {
        guard let request = pendingDataHandling, let context = pendingLaunchContext else { return }
        pendingDataHandling = nil
        Task {
            await handleInternalData(strategy: strategy, request: request, context: context)
        }
    }

    private func handleInternalData(strategy: SettingsStore.InternalDataStrategy, request: DataHandlingRequest, context: LaunchContext) async {
        isBusy = true
        isShowingStatus = true  // Show status for data handling (time-consuming)
        statusMessage = "内部データを処理しています…"
        defer { 
            isBusy = false
            isShowingStatus = false
        }
        let containerURL = context.containerURL
        do {
            switch strategy {
            case .discard:
                try removeItems(request.existingItems)
            case .mergeThenDelete:
                try await mergeInternalData(bundleIdentifier: request.app.bundleIdentifier,
                                             internalItems: request.existingItems,
                                             containerURL: containerURL)
            case .leave:
                break
            }
            pendingLaunchContext = nil
            Task { await performLaunch(app: request.app, resume: true) }
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage("内部データ処理に失敗", message: error.localizedDescription, underlying: error)
        }
    }

    private func removeItems(_ items: [URL]) throws {
        for url in items {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw AppError.diskImage("内部データの削除に失敗", message: url.lastPathComponent, underlying: error)
            }
        }
    }

    private func mergeInternalData(bundleIdentifier: String, internalItems: [URL], containerURL: URL) async throws {
        let tempBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PlayCoverManager/TemporaryMounts", isDirectory: true)
        try fileManager.createDirectory(at: tempBase, withIntermediateDirectories: true)
        let tempMount = try await diskImageService.mountTemporarily(for: bundleIdentifier, temporaryMountBase: tempBase)
        defer { Task { try? await diskImageService.detach(volumeURL: tempMount) } }
        let destination = tempMount
        for item in internalItems {
            let destinationURL = destination.appendingPathComponent(item.lastPathComponent)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: item, to: destinationURL)
        }
        try removeItems(internalItems)
    }

    private func containerURL(for bundleIdentifier: String) -> URL {
        let containersRoot = PlayCoverPaths.defaultContainerRoot()
        return containersRoot.appendingPathComponent(bundleIdentifier, isDirectory: true)
    }

    private func detectInternalData(at url: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return []
        }
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey], options: [.skipsHiddenFiles])
        let excludedNames: Set<String> = [".DS_Store", "Desktop.ini", "Thumbs.db", "TemporaryItems"]
        let filtered = contents.filter { item in
            if excludedNames.contains(item.lastPathComponent) { return false }
            if let values = try? item.resourceValues(forKeys: [.isSymbolicLinkKey]), values.isSymbolicLink == true {
                return false
            }
            return true
        }
        return filtered
    }

    func unmountAll(applyToPlayCoverContainer: Bool = true) {
        // Show confirmation dialog first
        let alert = NSAlert()
        alert.messageText = "すべてアンマウントして終了"
        alert.informativeText = "すべてのディスクイメージをアンマウントし、アプリを終了します。\n\n外部ドライブの場合、ドライブごと安全に取り外せる状態にします。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "アンマウントして終了")
        alert.addButton(withTitle: "キャンセル")
        
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return
        }
        
        Task { await performUnmountAllAndQuit(applyToPlayCoverContainer: applyToPlayCoverContainer) }
    }
    
    func getPerAppSettings() -> PerAppSettingsStore {
        return perAppSettings
    }
    
    // MARK: - App Termination Monitoring (Legacy - NSWorkspace notifications)
    // NOTE: NSWorkspace notifications don't work for PlayCover-launched iOS apps
    // This code is kept for reference but not used. Use polling-based detection instead.
    /*
    private func startMonitoringAppTerminations() {
        print("[LauncherVM] Setting up app termination observer")
        appTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            print("[LauncherVM] ===== App Termination Notification Received =====")
            
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                print("[LauncherVM] ERROR: Termination notification received but no app info")
                print("[LauncherVM] Notification userInfo keys: \(notification.userInfo?.keys.map { String(describing: $0) }.joined(separator: ", ") ?? "none")")
                return
            }
            
            let bundleID = app.bundleIdentifier ?? "<no bundle ID>"
            let appName = app.localizedName ?? "<no name>"
            print("[LauncherVM] Terminated app info:")
            print("[LauncherVM]   Bundle ID: \(bundleID)")
            print("[LauncherVM]   App Name: \(appName)")
            print("[LauncherVM]   Process ID: \(app.processIdentifier)")
            
            guard app.bundleIdentifier != nil else {
                print("[LauncherVM] Skipping - app has no bundle ID")
                return
            }
            
            // Handle app termination on MainActor
            Task { @MainActor [weak self] in
                guard let self = self else {
                    print("[LauncherVM] ERROR: Self is nil in termination handler")
                    return
                }
                
                print("[LauncherVM] Checking against managed apps:")
                for managedApp in self.apps {
                    print("[LauncherVM]   - \(managedApp.bundleIdentifier) (\(managedApp.displayName))")
                }
                
                // Check if this is one of our managed apps
                let isManagedApp = self.apps.contains { $0.bundleIdentifier == bundleID }
                print("[LauncherVM] Is managed app: \(isManagedApp)")
                
                guard isManagedApp else {
                    print("[LauncherVM] Not a managed app, ignoring")
                    return
                }
                
                print("[LauncherVM] ✅ Starting auto-unmount for \(bundleID)")
                // Unmount the container for this app
                await self.unmountContainer(for: bundleID)
                
                // Refresh to update running indicator
                await self.refresh()
            }
        }
        print("[LauncherVM] App termination observer registered successfully")
    }
    */"}
    
    
    private func unmountContainer(for bundleID: String) async {
        print("[LauncherVM] unmountContainer called for \(bundleID)")
        let containerURL = containerURL(for: bundleID)
        print("[LauncherVM] Container URL: \(containerURL.path)")
        
        // Release lock first
        print("[LauncherVM] Releasing lock for \(bundleID)")
        lockService.unlockContainer(for: bundleID)
        
        // Check if container is mounted
        let descriptor = try? diskImageService.diskImageDescriptor(for: bundleID, containerURL: containerURL)
        guard let descriptor = descriptor, descriptor.isMounted else {
            print("[LauncherVM] Container not mounted or descriptor failed for \(bundleID)")
            return
        }
        
        print("[LauncherVM] Container is mounted, checking for locks")
        
        // Check if any other process has a lock on this container
        if !lockService.canLockContainer(for: bundleID, at: containerURL) {
            print("[LauncherVM] Container is locked by another process, skipping unmount")
            // Another process (possibly PlayCover) is using this container
            // Don't unmount
            return
        }
        
        print("[LauncherVM] No locks detected, attempting unmount")
        do {
            try await diskImageService.detach(volumeURL: containerURL)
            print("[LauncherVM] Successfully unmounted container for \(bundleID)")
        } catch {
            print("[LauncherVM] Failed to unmount container for \(bundleID): \(error)")
            // Silently fail - don't show error for auto-unmount
            // The user might have manually unmounted it already
        }
    }

    private func performUnmountAllAndQuit(applyToPlayCoverContainer: Bool) async {
        print("[LauncherVM] ===== Starting performUnmountAllAndQuit =====")
        print("[LauncherVM] applyToPlayCoverContainer: \(applyToPlayCoverContainer)")
        isBusy = true
        isShowingStatus = true
        statusMessage = "ディスクイメージをアンマウントしています…"
        
        var successCount = 0
        var failedCount = 0
        var ejectedDrive: String?
        
        // Step 1: Unmount all app containers
        print("[LauncherVM] Step 1: Unmounting app containers (\(apps.count) apps)")
        statusMessage = "アプリコンテナをアンマウントしています…"
        for app in apps {
            let container = containerURL(for: app.bundleIdentifier)
            print("[LauncherVM] Checking app: \(app.bundleIdentifier)")
            
            // Check if container is actually mounted
            let descriptor = try? diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: container)
            guard let descriptor = descriptor, descriptor.isMounted else {
                print("[LauncherVM] Container not mounted, skipping: \(container.path)")
                continue
            }
            
            print("[LauncherVM] Container is mounted, attempting unmount: \(container.path)")
            do {
                try await diskImageService.detach(volumeURL: container)
                successCount += 1
                print("[LauncherVM] Successfully unmounted: \(app.bundleIdentifier)")
            } catch {
                failedCount += 1
                print("[LauncherVM] Failed to unmount \(app.bundleIdentifier): \(error)")
            }
        }
        
        print("[LauncherVM] Step 1 complete. Success: \(successCount), Failed: \(failedCount)")
        
        // If any app container failed, show error and abort
        guard failedCount == 0 else {
            print("[LauncherVM] Aborting due to failed app containers")
            isBusy = false
            isShowingStatus = false
            self.error = AppError.diskImage(
                "アンマウントに失敗しました",
                message: "\(failedCount) 個のコンテナをアンマウントできませんでした。\n実行中のアプリがないか確認してください。"
            )
            return
        }
        
        // Step 2: Unmount PlayCover container
        if applyToPlayCoverContainer {
            print("[LauncherVM] Step 2: Unmounting PlayCover container")
            statusMessage = "PlayCover コンテナをアンマウントしています…"
            let playCoverContainer = playCoverPaths.containerRootURL
            print("[LauncherVM] PlayCover container path: \(playCoverContainer.path)")
            
            // Check if it's actually mounted by querying diskutil
            var isMounted = false
            do {
                let output = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", playCoverContainer.path])
                if let data = output.data(using: .utf8),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let _ = plist["VolumeName"] as? String {
                    isMounted = true
                    print("[LauncherVM] PlayCover container is mounted")
                } else {
                    print("[LauncherVM] PlayCover container is not mounted (no volume name)")
                }
            } catch {
                print("[LauncherVM] PlayCover container is not a mounted volume (diskutil info failed)")
            }
            
            if isMounted {
                // Try to unmount
                print("[LauncherVM] Attempting to unmount PlayCover container")
                do {
                    try await diskImageService.detach(volumeURL: playCoverContainer)
                    successCount += 1
                    print("[LauncherVM] Successfully unmounted PlayCover container")
                } catch {
                    print("[LauncherVM] Failed to unmount PlayCover container: \(error)")
                    // PlayCover container failed, show error and abort
                    isBusy = false
                    isShowingStatus = false
                    self.error = AppError.diskImage(
                        "PlayCover コンテナのアンマウントに失敗しました",
                        message: "PlayCover が実行中の可能性があります。\n\nエラー: \(error.localizedDescription)"
                    )
                    return
                }
            } else {
                print("[LauncherVM] PlayCover container is not mounted, skipping")
            }
        } else {
            print("[LauncherVM] Step 2: Skipping PlayCover container (applyToPlayCoverContainer=false)")
        }
        
        print("[LauncherVM] Step 2 complete. Total success: \(successCount)")
        
        // Step 3: If external drive, eject the whole drive
        print("[LauncherVM] Step 3: Checking for external drive")
        if let storageDir = settings.diskImageDirectory {
            print("[LauncherVM] Storage directory: \(storageDir.path)")
            let isExternal = (try? await isExternalDrive(storageDir)) ?? false
            print("[LauncherVM] Is external drive: \(isExternal)")
            
            if isExternal {
                statusMessage = "外部ドライブを取り外し可能な状態にしています…"
                if let devicePath = try? await getDevicePath(for: storageDir) {
                    print("[LauncherVM] Device path: \(devicePath)")
                    do {
                        try await ejectDrive(devicePath: devicePath)
                        ejectedDrive = storageDir.lastPathComponent
                        print("[LauncherVM] Successfully ejected drive: \(ejectedDrive ?? "unknown")")
                    } catch {
                        print("[LauncherVM] Failed to eject drive (ignoring): \(error)")
                        // Eject failed, but leave it to Finder/System
                        // We already unmounted volumes successfully
                    }
                } else {
                    print("[LauncherVM] Could not get device path for external drive")
                }
            }
        } else {
            print("[LauncherVM] No storage directory configured")
        }
        
        print("[LauncherVM] Step 3 complete")
        
        // Step 4: Show result and quit
        print("[LauncherVM] Step 4: Showing results and quitting")
        print("[LauncherVM] Final stats - Success: \(successCount), Failed: 0, Ejected: \(ejectedDrive ?? "none")")
        await showUnmountResultAndQuit(successCount: successCount, failedCount: 0, ejectedDrive: ejectedDrive)
    }
    
    private func showUnmountResultAndQuit(successCount: Int, failedCount: Int, ejectedDrive: String?) async {
        print("[LauncherVM] Entering showUnmountResultAndQuit")
        print("[LauncherVM] Success: \(successCount), Failed: \(failedCount), Ejected: \(ejectedDrive ?? "none")")
        
        await MainActor.run {
            print("[LauncherVM] On MainActor, hiding status overlay")
            // Hide the status overlay before showing the alert
            self.isBusy = false
            self.isShowingStatus = false
        }
        
        // Give UI a moment to update
        try? await Task.sleep(for: .milliseconds(100))
        
        await MainActor.run {
            print("[LauncherVM] Creating alert")
            let alert = NSAlert()
            
            if let driveName = ejectedDrive {
                alert.messageText = "ドライブの取り外し完了"
                alert.informativeText = "外部ドライブ「\(driveName)」を安全に取り外せる状態にしました。\n\nアンマウント成功: \(successCount) 個\n失敗: \(failedCount) 個"
                print("[LauncherVM] Alert type: external drive ejected")
            } else {
                alert.messageText = "アンマウント完了"
                alert.informativeText = "ディスクイメージをアンマウントしました。\n\n成功: \(successCount) 個\n失敗: \(failedCount) 個"
                print("[LauncherVM] Alert type: unmount complete")
            }
            
            alert.alertStyle = failedCount > 0 ? .warning : .informational
            alert.addButton(withTitle: "OK")
            
            print("[LauncherVM] About to show modal alert")
            let response = alert.runModal()
            print("[LauncherVM] Alert dismissed with response: \(response.rawValue)")
            
            print("[LauncherVM] About to terminate application")
            // Quit app
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func isExternalDrive(_ url: URL) async throws -> Bool {
        // Check if volume is on external/removable media
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return false
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return false
        }
        
        // Check if it's removable media
        if let isInternal = plist["Internal"] as? Bool {
            return !isInternal
        }
        
        return false
    }
    
    private func getDevicePath(for url: URL) async throws -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["info", "-plist", url.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            return nil
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        
        // Get device node (e.g., /dev/disk2)
        if let deviceNode = plist["DeviceNode"] as? String {
            return deviceNode
        }
        
        return nil
    }
    
    private func ejectDrive(devicePath: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
        process.arguments = ["eject", devicePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "不明なエラー"
            throw AppError.diskImage("ドライブの取り出しに失敗", message: errorMessage)
        }
    }
}

