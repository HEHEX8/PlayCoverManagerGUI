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
    
    // Unmount flow state
    enum UnmountFlowState: Equatable {
        case idle
        case confirming(volumeDisplayName: String)
        case processing(status: String)
        case ejectConfirming(volumeDisplayName: String)
        case success(unmountedCount: Int, ejectedDrive: String?)
        case error(title: String, message: String)
    }
    var unmountFlowState: UnmountFlowState = .idle

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
         processRunner: ProcessRunner,
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
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
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
            // Search in: 1) System language name, 2) Standard (English) name, 3) Bundle ID short name
            app.displayName.lowercased().contains(query) ||
            app.standardName?.lowercased().contains(query) == true ||
            app.bundleShortName.lowercased().contains(query)
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
            let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
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
        defer {
            Task {
                // Eject disk image (unmounts and detaches in one operation)
                try? await diskImageService.ejectDiskImage(for: tempMount)
            }
        }
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

    private var pendingUnmountTask: Bool?
    
    func unmountAll(applyToPlayCoverContainer: Bool = true) {
        // Check for running apps first
        let runningApps = apps.filter { launcherService.isAppRunning(bundleID: $0.bundleIdentifier) }
        
        if !runningApps.isEmpty {
            let appsList = runningApps.map { "• \($0.displayName)" }.joined(separator: "\n")
            unmountFlowState = .error(
                title: "実行中のアプリがあります",
                message: "以下のアプリが実行中です。アンマウントするには先にこれらのアプリを終了してください。\n\n\(appsList)"
            )
            return
        }
        
        // Show confirmation overlay
        unmountFlowState = .confirming(volumeDisplayName: "")
        
        // Store for later use when user confirms
        pendingUnmountTask = applyToPlayCoverContainer
    }
    
    func confirmUnmount() {
        guard case .confirming = unmountFlowState else { return }
        guard let applyToPlayCoverContainer = pendingUnmountTask else { return }
        
        Task { await performUnmountAllAndQuit(applyToPlayCoverContainer: applyToPlayCoverContainer) }
    }
    
    func cancelUnmount() {
        unmountFlowState = .idle
        pendingUnmountTask = nil
    }
    
    func confirmEject() {
        // Will be set by performUnmountAllAndQuit when needed
        pendingEjectConfirmed = true
    }
    
    func cancelEject() {
        // Skip eject and go straight to completion
        pendingEjectConfirmed = false
    }
    
    func completeUnmount() {
        unmountFlowState = .idle
        NSApplication.shared.terminate(nil)
    }
    
    func dismissUnmountError() {
        unmountFlowState = .idle
    }
    
    private var pendingEjectConfirmed: Bool?
    
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
    */
    
    private func unmountContainer(for bundleID: String) async {
        print("[LauncherVM] unmountContainer called for \(bundleID)")
        let containerURL = PlayCoverPaths.containerURL(for: bundleID)
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
        // With two-step unmount (unmount then eject), the lock check won't interfere
        // because we unmount the volume first, releasing any file handles we opened
        if !lockService.canLockContainer(for: bundleID, at: containerURL) {
            print("[LauncherVM] Container is locked by another process, skipping unmount")
            // Another process (possibly PlayCover) is using this container
            // Don't unmount
            return
        }
        
        print("[LauncherVM] No locks detected, attempting to eject disk image")
        do {
            // Two-step eject: unmount volume, then detach device
            try await diskImageService.ejectDiskImage(for: containerURL)
            print("[LauncherVM] Successfully ejected disk image for \(bundleID)")
        } catch {
            print("[LauncherVM] Failed to eject disk image for \(bundleID): \(error)")
            // Silently fail - will retry on next refresh
            // System processes (cfprefsd, etc.) may still be holding file handles
        }
    }

    private func performUnmountAllAndQuit(applyToPlayCoverContainer: Bool) async {
        print("[LauncherVM] ===== Starting performUnmountAllAndQuit =====")
        print("[LauncherVM] applyToPlayCoverContainer: \(applyToPlayCoverContainer)")
        
        // Set initial processing state
        await MainActor.run {
            unmountFlowState = .processing(status: "ディスクイメージをアンマウントしています…")
        }
        
        var successCount = 0
        var failedCount = 0
        var ejectedDrive: String?
        
        // Count mounted volumes before unmounting (if storage directory is set)
        var volumesBefore = 0
        var volumesAfter = 0
        if let storageDir = settings.diskImageDirectory {
            volumesBefore = await diskImageService.countMountedVolumes(under: storageDir)
            print("[LauncherVM] Mounted volumes before unmount: \(volumesBefore)")
        }
        
        // Step 1: Unmount all app containers
        print("[LauncherVM] Step 1: Unmounting app containers (\(apps.count) apps)")
        await MainActor.run {
            unmountFlowState = .processing(status: "アプリコンテナをアンマウントしています…")
        }
        for app in apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            print("[LauncherVM] Checking app: \(app.bundleIdentifier)")
            
            // Check if app is currently running
            if launcherService.isAppRunning(bundleID: app.bundleIdentifier) {
                print("[LauncherVM] App is running, skipping: \(app.bundleIdentifier)")
                failedCount += 1
                continue
            }
            
            // Check if container is actually mounted
            let descriptor = try? diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: container)
            guard let descriptor = descriptor, descriptor.isMounted else {
                print("[LauncherVM] Container not mounted, skipping: \(container.path)")
                continue
            }
            
            print("[LauncherVM] Container is mounted, attempting to eject disk image: \(container.path)")
            do {
                try await diskImageService.ejectDiskImage(for: container)
                successCount += 1
                print("[LauncherVM] Successfully ejected disk image: \(app.bundleIdentifier)")
            } catch {
                failedCount += 1
                print("[LauncherVM] Failed to eject disk image \(app.bundleIdentifier): \(error)")
            }
        }
        
        print("[LauncherVM] Step 1 complete. Success: \(successCount), Failed: \(failedCount)")
        
        // If any app container failed, show error and abort
        guard failedCount == 0 else {
            print("[LauncherVM] Aborting due to failed app containers")
            await MainActor.run {
                unmountFlowState = .error(
                    title: "アンマウントに失敗しました",
                    message: "\(failedCount) 個のコンテナをアンマウントできませんでした。\n実行中のアプリがないか確認してください。"
                )
            }
            return
        }
        
        // Step 2: Unmount PlayCover container
        if applyToPlayCoverContainer {
            print("[LauncherVM] Step 2: Unmounting PlayCover container")
            await MainActor.run {
                unmountFlowState = .processing(status: "PlayCover コンテナをアンマウントしています…")
            }
            let playCoverContainer = playCoverPaths.containerRootURL
            print("[LauncherVM] PlayCover container path: \(playCoverContainer.path)")
            
            // Check if it's actually mounted by querying diskutil
            let isMounted = (try? diskImageService.isMounted(at: playCoverContainer)) ?? false
            if isMounted {
                print("[LauncherVM] PlayCover container is mounted")
                // Try to eject disk image
                print("[LauncherVM] Attempting to eject PlayCover container disk image")
                do {
                    try await diskImageService.ejectDiskImage(for: playCoverContainer)
                    successCount += 1
                    print("[LauncherVM] Successfully ejected PlayCover container disk image")
                } catch {
                    print("[LauncherVM] Failed to eject PlayCover container disk image: \(error)")
                    // PlayCover container failed, show error and abort
                    await MainActor.run {
                        unmountFlowState = .error(
                            title: "PlayCover コンテナのアンマウントに失敗しました",
                            message: "PlayCover が実行中の可能性があります。\n\nエラー: \(error.localizedDescription)"
                        )
                    }
                    return
                }
            } else {
                print("[LauncherVM] PlayCover container is not mounted, skipping")
            }
        } else {
            print("[LauncherVM] Step 2: Skipping PlayCover container (applyToPlayCoverContainer=false)")
        }
        
        print("[LauncherVM] Step 2 complete. Total success: \(successCount)")
        
        // Count mounted volumes after unmounting
        if let storageDir = settings.diskImageDirectory {
            volumesAfter = await diskImageService.countMountedVolumes(under: storageDir)
            print("[LauncherVM] Mounted volumes after unmount: \(volumesAfter)")
            print("[LauncherVM] Total volumes unmounted: \(volumesBefore - volumesAfter)")
        }
        
        // Step 3: If external drive, eject the whole drive  
        print("[LauncherVM] Step 3: Checking for external drive")
        if let storageDir = settings.diskImageDirectory {
            print("[LauncherVM] Storage directory: \(storageDir.path)")
            
            // Check if path is under /Volumes/ (typical external mount point)
            let isUnderVolumes = storageDir.path.hasPrefix("/Volumes/")
            print("[LauncherVM] Is under /Volumes/: \(isUnderVolumes)")
            
            let isExternal = (try? await diskImageService.isExternalDrive(storageDir)) ?? false
            print("[LauncherVM] Is external drive (diskutil): \(isExternal)")
            
            // Use /Volumes/ check as fallback since diskutil might not detect all cases
            let shouldOfferEject = isExternal || isUnderVolumes
            print("[LauncherVM] Should offer eject: \(shouldOfferEject)")
            
            if shouldOfferEject {
                // Get volume info (includes device/media name)
                let volumeInfo = try? await diskImageService.getVolumeInfo(for: storageDir)
                let displayName = volumeInfo?.displayName ?? storageDir.lastPathComponent
                print("[LauncherVM] Volume display name: \(displayName)")
                
                // Show eject confirmation in overlay
                await MainActor.run {
                    unmountFlowState = .ejectConfirming(volumeDisplayName: displayName)
                    pendingEjectConfirmed = nil  // Reset confirmation state
                }
                
                // Wait for user decision
                while await MainActor.run(body: { pendingEjectConfirmed }) == nil {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                
                let shouldEject = await MainActor.run { pendingEjectConfirmed == true }
                
                if shouldEject {
                    await MainActor.run {
                        unmountFlowState = .processing(status: "外部ドライブを取り外し可能な状態にしています…")
                    }
                    statusMessage = "外部ドライブを取り外し可能な状態にしています…"
                    if let devicePath = try? await diskImageService.getDevicePath(for: storageDir) {
                        print("[LauncherVM] Device path: \(devicePath)")
                        
                        do {
                            try await diskImageService.ejectDrive(devicePath: devicePath)
                            ejectedDrive = displayName
                            print("[LauncherVM] Successfully ejected drive: \(ejectedDrive ?? "unknown")")
                        } catch {
                            print("[LauncherVM] Failed to eject drive: \(error)")
                            
                            // Parse error for user-friendly information
                            var errorMessage: String
                            var volumeInfoText: String? = nil
                            
                            if let processError = error as? ProcessRunnerError,
                               case .commandFailed(_, _, let stderr) = processError {
                                // Try to parse stderr for volume and process info
                                if let parsed = await diskImageService.parseEjectError(stderr) {
                                    var details: [String] = []
                                    
                                    if !parsed.volumeNames.isEmpty {
                                        let volNames = parsed.volumeNames.joined(separator: ", ")
                                        details.append("ボリューム: \(volNames)")
                                    }
                                    
                                    if let process = parsed.blockingProcess {
                                        details.append("使用中のプロセス: \(process)")
                                        
                                        // Add explanation if diskimagesiod is blocking
                                        if process.contains("diskimagesiod") {
                                            details.append("\n⚠️ システムプロセスがディスクイメージを処理中です。")
                                            details.append("少し待ってから、Finderで手動でイジェクトしてください。")
                                        }
                                    }
                                    
                                    volumeInfoText = details.joined(separator: "\n")
                                }
                                
                                if stderr.contains("at least one volume could not be unmounted") {
                                    errorMessage = "ドライブ上のボリュームが使用中のため、イジェクトできませんでした。"
                                } else {
                                    errorMessage = "イジェクトに失敗しました。"
                                }
                            } else {
                                errorMessage = error.localizedDescription
                            }
                            
                            // Show error in overlay
                            var fullMessage = errorMessage
                            if let volInfo = volumeInfoText {
                                fullMessage += "\n\n\(volInfo)"
                            }
                            fullMessage += "\n\nFinderから手動でイジェクトしてください。"
                            
                            await MainActor.run {
                                unmountFlowState = .error(
                                    title: "ドライブのイジェクトに失敗",
                                    message: fullMessage
                                )
                            }
                            return  // Exit early, don't continue to success
                        }
                    } else {
                        print("[LauncherVM] Could not get device path for external drive")
                        
                        // Show error to user
                        await MainActor.run {
                            unmountFlowState = .error(
                                title: "デバイスパスの取得に失敗",
                                message: "外部ドライブのデバイスパスを取得できませんでした。\n\nFinderから手動でイジェクトしてください。"
                            )
                        }
                        return  // Exit early
                    }
                } else {
                    print("[LauncherVM] User chose not to eject external drive")
                }
            }
        } else {
            print("[LauncherVM] No storage directory configured")
        }
        
        print("[LauncherVM] Step 3 complete")
        
        // Step 4: Show result
        print("[LauncherVM] Step 4: Showing results")
        let totalUnmounted = volumesBefore - volumesAfter
        print("[LauncherVM] Final stats - Explicitly unmounted: \(successCount), Total volumes unmounted: \(totalUnmounted), Failed: 0, Ejected: \(ejectedDrive ?? "none")")
        
        await MainActor.run {
            unmountFlowState = .success(
                unmountedCount: totalUnmounted > 0 ? totalUnmounted : successCount,
                ejectedDrive: ejectedDrive
            )
        }
    }
    

    
    
    
}

