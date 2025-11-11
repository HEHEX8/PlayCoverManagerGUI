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
        case storageChangeConfirming(mountedCount: Int)  // New: for storage location change
        case processing(status: String)
        case ejectConfirming(volumeDisplayName: String)
        case success(unmountedCount: Int, ejectedDrive: String?)
        case error(title: String, message: String)
        case runningAppsBlocking(runningAppBundleIDs: [String])  // Running apps preventing unmount
        case forceUnmountOffering(failedCount: Int, applyToPlayCoverContainer: Bool)
        case forceEjectOffering(volumeDisplayName: String, devicePath: String)
    }
    var unmountFlowState: UnmountFlowState = .idle
    
    // Track if current unmount is for storage change (vs quit)
    @ObservationIgnored private var isStorageChangeFlow: Bool = false

    // Services and dependencies - not tracked by Observable (no UI impact)
    @ObservationIgnored private let playCoverPaths: PlayCoverPaths
    @ObservationIgnored let diskImageService: DiskImageService  // Internal access for view layer
    @ObservationIgnored private let launcherService: LauncherService
    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private let perAppSettings: PerAppSettingsStore
    @ObservationIgnored private let fileManager: FileManager
    @ObservationIgnored private let lockService: ContainerLockService
    @ObservationIgnored private let processRunner: ProcessRunner

    // Internal state - not tracked by Observable
    @ObservationIgnored private var pendingLaunchContext: LaunchContext?
    @ObservationIgnored private var previouslyRunningApps: Set<String> = []
    
    // Track active auto-unmount tasks to prevent duplicates and allow cancellation
    @ObservationIgnored private var activeUnmountTasks: [String: Task<Void, Never>] = [:]
    
    // Flag to suppress KVO handling during termination sequence
    // nonisolated(unsafe): Safe for Bool flag (atomic read/write at CPU level)
    @ObservationIgnored nonisolated(unsafe) private var isTerminationSequenceActive: Bool = false
    
    // KVO observation for runningApplications (more efficient than notifications)
    // @ObservationIgnored prevents Observable macro from tracking this property
    @ObservationIgnored private var runningAppsObservation: NSKeyValueObservation?

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
        
        // Setup real-time app lifecycle monitoring
        setupAppLifecycleMonitoring()
    }
    
    nonisolated deinit {
        // Remove KVO observation
        runningAppsObservation?.invalidate()
    }
    
    // MARK: - KVO Monitoring Control
    
    /// Temporarily suspend KVO monitoring to prevent race conditions during app termination
    @MainActor
    func suspendKVOMonitoring() {
        Logger.lifecycle("Suspending KVO monitoring for termination sequence")
        runningAppsObservation?.invalidate()
        runningAppsObservation = nil
    }
    
    /// Resume KVO monitoring (typically not needed as app is terminating)
    @MainActor
    func resumeKVOMonitoring() {
        Logger.lifecycle("Resuming KVO monitoring")
        setupAppLifecycleMonitoring()
    }
    
    private func setupAppLifecycleMonitoring() {
        let workspace = NSWorkspace.shared
        
        // Build Set of managed bundle IDs for O(1) lookup (performance optimization)
        let managedBundleIDs = Set(apps.map { $0.bundleIdentifier })
        
        // Initialize tracking set with currently running apps
        previouslyRunningApps = Set(
            workspace.runningApplications
                .compactMap { $0.bundleIdentifier }
                .filter { managedBundleIDs.contains($0) }  // O(1) instead of O(n)
        )
        
        Logger.lifecycle("KVO monitoring setup - tracking \(previouslyRunningApps.count) running apps")
        
        // Use KVO to observe runningApplications - more efficient than notifications
        // This detects ALL app launches and terminations instantly
        runningAppsObservation = workspace.observe(\.runningApplications, options: [.old, .new]) { [weak self] workspace, change in
            guard let self = self else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Skip processing if termination sequence is active
                guard !self.isTerminationSequenceActive else {
                    Logger.lifecycle("KVO event suppressed - termination sequence active")
                    return
                }
                
                // Build Set of managed bundle IDs for O(1) lookup
                let managedBundleIDs = Set(self.apps.map { $0.bundleIdentifier })
                
                // Get current running apps (filter to our managed apps only)
                let currentRunning = Set(
                    workspace.runningApplications
                        .compactMap { $0.bundleIdentifier }
                        .filter { managedBundleIDs.contains($0) }  // O(1) instead of O(n)
                )
                
                // Detect newly launched apps
                let launched = currentRunning.subtracting(self.previouslyRunningApps)
                for bundleID in launched {
                    Logger.lifecycle("KVO detected launch: \(bundleID)")
                    await self.handleAppLaunched(bundleID: bundleID)
                }
                
                // Detect terminated apps
                let terminated = self.previouslyRunningApps.subtracting(currentRunning)
                for bundleID in terminated {
                    Logger.lifecycle("KVO detected termination: \(bundleID)")
                    await self.handleAppTerminated(bundleID: bundleID)
                }
                
                // Update tracking set
                self.previouslyRunningApps = currentRunning
            }
        }
    }
    
    private func handleAppLaunched(bundleID: String) async {
        // Cancel any pending unmount task for this app (user relaunched before unmount)
        if let task = activeUnmountTasks[bundleID] {
            task.cancel()
            activeUnmountTasks.removeValue(forKey: bundleID)
            Logger.lifecycle("Cancelled auto-unmount for \(bundleID) due to relaunch")
        }
        
        // Update only this app's status
        await updateAppStatus(bundleID: bundleID)
    }
    
    private func handleAppTerminated(bundleID: String) async {
        // Always update status first, even if we skip creating a new task
        await updateAppStatus(bundleID: bundleID)
        
        // If there's already an unmount task for this app, don't create another one
        // This prevents duplicate unmount attempts from KVO firing multiple times
        guard activeUnmountTasks[bundleID] == nil else {
            Logger.lifecycle("Unmount task already active for \(bundleID), skipping duplicate task creation but status updated")
            return
        }
        
        // Create new auto-unmount task and track it
        let task = Task {
            await unmountContainer(for: bundleID)
        }
        activeUnmountTasks[bundleID] = task
        
        // Wait for completion and cleanup tracking
        await task.value
        activeUnmountTasks.removeValue(forKey: bundleID)
        
        // Update status after unmount completes (will show red)
        await updateAppStatus(bundleID: bundleID)
    }
    
    /// Update status for a single app (efficient, doesn't check all apps)
    private func updateAppStatus(bundleID: String) async {
        guard let index = apps.firstIndex(where: { $0.bundleIdentifier == bundleID }) else {
            Logger.error("updateAppStatus: App not found for \(bundleID)")
            return
        }
        
        let app = apps[index]
        let containerURL = PlayCoverPaths.containerURL(for: bundleID)
        let isRunning = launcherService.isAppRunning(bundleID: bundleID)
        let isMounted = (try? diskImageService.isMounted(at: containerURL)) ?? false
        

        
        let updatedApp = PlayCoverApp(
            bundleIdentifier: app.bundleIdentifier,
            displayName: app.displayName,
            standardName: app.standardName,
            version: app.version,
            appURL: app.appURL,
            icon: app.icon,
            lastLaunchedFlag: app.lastLaunchedFlag,
            isRunning: isRunning,
            isMounted: isMounted
        )
        
        // Force SwiftUI update by replacing entire array
        var newApps = apps
        newApps[index] = updatedApp
        apps = newApps
        
        applySearch()
    }
    
    // MARK: - Public Helper Methods for AppViewModel
    
    /// Returns the number of active auto-unmount tasks
    var activeUnmountTaskCount: Int {
        activeUnmountTasks.count
    }
    
    /// Cancels all active auto-unmount tasks
    func cancelAllAutoUnmountTasks() async {
        for (bundleID, task) in activeUnmountTasks {
            task.cancel()
            Logger.unmount("Cancelled auto-unmount for: \(bundleID)")
        }
        activeUnmountTasks.removeAll()
    }
    
    /// Suppress KVO handling during app termination sequence
    /// Call this before starting termination unmount to prevent race conditions
    nonisolated func enterTerminationSequence() {
        isTerminationSequenceActive = true
        Task { @MainActor in
            Logger.lifecycle("Termination sequence started - KVO handling suppressed")
        }
    }
    
    /// Resume normal KVO handling (typically not needed as app is terminating)
    nonisolated func exitTerminationSequence() {
        isTerminationSequenceActive = false
        Task { @MainActor in
            Logger.lifecycle("Termination sequence ended - KVO handling resumed")
        }
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
        
        // Swift 6.2: Call actor method asynchronously
        Task.immediate {
            await lockService.cleanupStaleLocks(in: containerURLs)
        }
    }

    func refresh() async {
        do {
            // Refresh app list (includes isRunning check via LauncherService)
            let refreshed = try launcherService.fetchInstalledApps(at: playCoverPaths.applicationsRootURL)
            
            // Update isMounted status for each app
            apps = refreshed.map { app in
                let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
                let isMounted = (try? diskImageService.isMounted(at: containerURL)) ?? false
                
                return PlayCoverApp(
                    bundleIdentifier: app.bundleIdentifier,
                    displayName: app.displayName,
                    standardName: app.standardName,
                    version: app.version,
                    appURL: app.appURL,
                    icon: app.icon,
                    lastLaunchedFlag: app.lastLaunchedFlag,
                    isRunning: app.isRunning,
                    isMounted: isMounted
                )
            }
            
            applySearch()
            
            // Update running apps set for consistency
            previouslyRunningApps = Set(apps.filter { $0.isRunning }.map { $0.bundleIdentifier })
        } catch {
            self.error = AppError.environment(String(localized: "アプリ一覧の更新に失敗"), message: error.localizedDescription, underlying: error)
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
        Logger.lifecycle("Launch requested for: \(app.displayName) (\(app.bundleIdentifier))")
        // Swift 6.2: Task.immediate for instant UI feedback
        Task.immediate { await performLaunch(app: app, resume: false) }
    }

    private func performLaunch(app: PlayCoverApp, resume: Bool) async {
        Logger.lifecycle("Starting launch flow for \(app.bundleIdentifier) (resume: \(resume))")
        isBusy = true
        isShowingStatus = false  // Don't show status overlay for normal launch
        statusMessage = String(localized: "\(app.displayName) を準備しています…")
        defer { 
            isBusy = false
            isShowingStatus = false
        }
        do {
            let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            Logger.debug("Container URL: \(containerURL.path)")
            
            // Clean up any lingering processes from previous failed installations/launches
            await cleanupLingeringProcesses(for: app.bundleIdentifier, containerURL: containerURL)
            
            // Check disk image state
            Logger.diskImage("Checking disk image state for \(app.bundleIdentifier)")
            let state = try DiskImageHelper.checkDiskImageState(
                for: app.bundleIdentifier,
                containerURL: containerURL,
                diskImageService: diskImageService
            )
            Logger.diskImage("Disk image exists: \(state.imageExists), mounted: \(state.isMounted)")
            
            guard state.imageExists else {
                Logger.lifecycle("Disk image not found, requesting creation for \(app.bundleIdentifier)")
                pendingLaunchContext = LaunchContext(app: app, containerURL: containerURL)
                pendingImageCreation = app
                return
            }

            // Check for internal data if not mounted and not resuming
            if !resume && !state.isMounted {
                Logger.debug("Checking for internal data at \(containerURL.path)")
                let internalItems = try detectInternalData(at: containerURL)
                if !internalItems.isEmpty {
                    Logger.lifecycle("Internal data found (\(internalItems.count) items), requesting user action")
                    pendingLaunchContext = LaunchContext(app: app, containerURL: containerURL)
                    pendingDataHandling = DataHandlingRequest(app: app, existingItems: internalItems)
                    return
                }
            }

            // Mount if needed
            if !state.isMounted {
                Logger.diskImage("Mounting disk image for \(app.bundleIdentifier)")
                try await Logger.measureAsync("Mount disk image") {
                    try await DiskImageHelper.mountDiskImageIfNeeded(
                        for: app.bundleIdentifier,
                        containerURL: containerURL,
                        diskImageService: diskImageService,
                        perAppSettings: perAppSettings,
                        globalSettings: settings
                    )
                }
                Logger.diskImage("Successfully mounted disk image")
            } else {
                Logger.diskImage("Disk image already mounted, skipping mount")
            }

            // Swift 6.2: Acquire lock on container before launching (actor method)
            Logger.debug("Acquiring lock for \(app.bundleIdentifier)")
            _ = await lockService.lockContainer(for: app.bundleIdentifier, at: containerURL)
            
            // Get preferred language from per-app settings
            let preferredLanguage = perAppSettings.getPreferredLanguage(for: app.bundleIdentifier)
            
            Logger.lifecycle("Launching \(app.displayName)...")
            if let language = preferredLanguage {
                Logger.debug("Using preferred language: \(language)")
            }
            try await launcherService.openApp(app, preferredLanguage: preferredLanguage)
            Logger.lifecycle("Successfully launched \(app.displayName)")
            pendingLaunchContext = nil
            
            // Cancel any pending unmount task (user relaunched before unmount)
            if let task = activeUnmountTasks[app.bundleIdentifier] {
                task.cancel()
                activeUnmountTasks.removeValue(forKey: app.bundleIdentifier)
                Logger.lifecycle("Cancelled auto-unmount for \(app.bundleIdentifier) due to launch")
            }
            
            // Refresh to update lastLaunchedFlag and status
            // This ensures the launched app becomes the "recent app"
            Task.immediate {
                try? await Task.sleep(for: .seconds(0.5))
                await refresh()
            }
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage(String(localized: "アプリの起動に失敗"), message: error.localizedDescription, underlying: error)
        }
    }

    func confirmImageCreation() {
        guard let context = pendingLaunchContext, let app = pendingImageCreation else { return }
        pendingImageCreation = nil
        // Swift 6.2: Task.immediate for immediate disk image creation start
        Task.immediate {
            await createImageAndResume(app: app, context: context)
        }
    }

    func cancelImageCreation() {
        pendingImageCreation = nil
        pendingLaunchContext = nil
    }

    private func createImageAndResume(app: PlayCoverApp, context: LaunchContext) async {
        CriticalOperationService.shared.beginOperation("ディスクイメージ作成")
        
        isBusy = true
        isShowingStatus = true  // Show status for disk image creation (time-consuming)
        statusMessage = String(localized: "\(app.displayName) 用のディスクイメージを作成しています…")
        defer { 
            isBusy = false
            isShowingStatus = false
            CriticalOperationService.shared.endOperation()
        }
        do {
            _ = try await diskImageService.ensureDiskImageExists(for: app.bundleIdentifier, volumeName: app.bundleIdentifier)
            pendingLaunchContext = nil
            // Swift 6.2: Task.immediate for immediate launch after image creation
            Task.immediate { await performLaunch(app: app, resume: true) }
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage(String(localized: "ディスクイメージの作成に失敗"), message: error.localizedDescription, underlying: error)
        }
    }

    func applyDataHandling(strategy: SettingsStore.InternalDataStrategy) {
        guard let request = pendingDataHandling, let context = pendingLaunchContext else { return }
        pendingDataHandling = nil
        // Swift 6.2: Task.immediate for responsive data handling
        Task.immediate {
            await handleInternalData(strategy: strategy, request: request, context: context)
        }
    }

    private func handleInternalData(strategy: SettingsStore.InternalDataStrategy, request: DataHandlingRequest, context: LaunchContext) async {
        CriticalOperationService.shared.beginOperation("内部データ処理")
        
        isBusy = true
        isShowingStatus = true  // Show status for data handling (time-consuming)
        statusMessage = String(localized: "内部データを処理しています…")
        defer { 
            isBusy = false
            isShowingStatus = false
            CriticalOperationService.shared.endOperation()
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
            // Swift 6.2: Task.immediate for immediate app launch after data handling
            Task.immediate { await performLaunch(app: request.app, resume: true) }
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage(String(localized: "内部データ処理に失敗"), message: error.localizedDescription, underlying: error)
        }
    }

    private func removeItems(_ items: [URL]) throws {
        for url in items {
            do {
                try fileManager.removeItem(at: url)
            } catch {
                throw AppError.diskImage(String(localized: "内部データの削除に失敗"), message: url.lastPathComponent, underlying: error)
            }
        }
    }

    private func mergeInternalData(bundleIdentifier: String, internalItems: [URL], containerURL: URL) async throws {
        CriticalOperationService.shared.beginOperation("内部データマージ")
        defer {
            CriticalOperationService.shared.endOperation()
        }
        
        let tempBase = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/PlayCoverManager/TemporaryMounts", isDirectory: true)
        try fileManager.createDirectory(at: tempBase, withIntermediateDirectories: true)
        let tempMount = try await diskImageService.mountTemporarily(for: bundleIdentifier, temporaryMountBase: tempBase)
        defer {
            // Swift 6.2: Task.immediate for prompt cleanup
            Task.immediate {
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

    func detectInternalData(at url: URL) throws -> [URL] {
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
        // Store for later use (even if apps are running)
        pendingUnmountTask = applyToPlayCoverContainer
        
        // Check for running apps first
        let runningApps = apps.filter { launcherService.isAppRunning(bundleID: $0.bundleIdentifier) }
        
        if !runningApps.isEmpty {
            let runningBundleIDs = runningApps.map { $0.bundleIdentifier }
            unmountFlowState = .runningAppsBlocking(runningAppBundleIDs: runningBundleIDs)
            return
        }
        
        // Show confirmation overlay
        unmountFlowState = .confirming(volumeDisplayName: "")
    }
    
    func confirmUnmount() {
        guard case .confirming = unmountFlowState else { return }
        guard let applyToPlayCoverContainer = pendingUnmountTask else { return }
        
        // Swift 6.2: Task.immediate for immediate unmount start
        Task.immediate { await performUnmountAllAndQuit(applyToPlayCoverContainer: applyToPlayCoverContainer) }
    }
    
    func retryUnmountAll() {
        // Retry unmount after apps have been terminated
        // This is called from the "すべて終了" button in the running apps blocking dialog
        // Note: quitAllAppsAndRetry() already waited 1.5 seconds for auto-eject
        Logger.unmount("retryUnmountAll() called, pendingUnmountTask: \(String(describing: pendingUnmountTask))")
        
        guard let applyToPlayCoverContainer = pendingUnmountTask else {
            Logger.error("retryUnmountAll() - pendingUnmountTask is nil, cannot continue")
            return
        }
        
        Logger.unmount("Continuing unmount flow with applyToPlayCoverContainer: \(applyToPlayCoverContainer)")
        
        // Continue with the unmount flow (skip running apps check since they're already terminated)
        Task {
            await performUnmountAllAndQuit(applyToPlayCoverContainer: applyToPlayCoverContainer)
        }
    }
    
    func cancelUnmount() {
        unmountFlowState = .idle
        pendingUnmountTask = nil
        restoreWindowFocus()
    }
    
    func confirmEject() {
        // Will be set by performUnmountAllAndQuit when needed
        pendingEjectConfirmed = true
    }
    
    func cancelEject() {
        // Skip eject and go straight to completion
        pendingEjectConfirmed = false
    }
    
    func confirmForceEject() {
        // Will be set by performUnmountAllAndQuit when needed
        pendingForceEjectConfirmed = true
    }
    
    func cancelForceEject() {
        // Skip force eject and show success
        pendingForceEjectConfirmed = false
    }
    
    func completeUnmount() {
        unmountFlowState = .idle
        
        // PlayCover container has been ejected at this point
        // App cannot continue normally, so terminate
        Logger.unmount("PlayCover container ejected, terminating app")
        NSApplication.shared.terminate(nil)
    }
    
    func dismissUnmountError() {
        unmountFlowState = .idle
        restoreWindowFocus()
        isStorageChangeFlow = false
    }
    
    // MARK: - Focus Restoration
    
    /// Workaround for macOS focus loss bug after dismissing overlays/dialogs
    /// Forces the window to regain focus and become key window
    private func restoreWindowFocus() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            if let window = NSApp.keyWindow ?? NSApp.windows.first {
                window.makeKey()
                window.makeFirstResponder(window.contentView)
            }
        }
    }
    
    private var pendingEjectConfirmed: Bool?
    private var pendingForceEjectConfirmed: Bool?
    
    func getPerAppSettings() -> PerAppSettingsStore {
        return perAppSettings
    }
    
    private func unmountContainer(for bundleID: String) async {
        let containerURL = PlayCoverPaths.containerURL(for: bundleID)
        
        Logger.unmount("Attempting to eject container for: \(bundleID)")
        
        // Check if mounted
        let descriptor = try? diskImageService.diskImageDescriptor(for: bundleID, containerURL: containerURL)
        guard let descriptor = descriptor, descriptor.isMounted else {
            Logger.unmount("Container not mounted, nothing to do")
            return
        }
        
        Logger.unmount("Container is mounted, proceeding with eject")
        
        // Synchronize preferences to ensure settings are saved
        CFPreferencesAppSynchronize(bundleID as CFString)
        
        // Force filesystem sync to disk
        sync()
        Logger.unmount("Filesystem sync completed")
        
        // Wait 30 seconds before attempting eject
        // This allows quick app relaunches without remounting, and gives cfprefsd time to release
        Logger.unmount("Waiting 30 seconds before eject (allows quick relaunch)")
        try? await Task.sleep(for: .seconds(30.0))
        
        // Check if task was cancelled (e.g., by ALL eject or app relaunch)
        if Task.isCancelled {
            Logger.unmount("Auto-unmount cancelled for: \(bundleID)")
            return
        }
        
        Logger.unmount("Grace period completed, attempting eject")
        
        // Release our lock
        await lockService.unlockContainer(for: bundleID)
        
        // Try to eject directly - if another process has a lock, eject will fail gracefully
        // Don't check canLock() because it can give false positives
        do {
            try await diskImageService.ejectDiskImage(for: containerURL, force: false)
            Logger.unmount("Successfully ejected container for: \(bundleID)")
        } catch {
            Logger.unmount("Failed to eject container for \(bundleID), will remain mounted: \(error)")
            // Silent failure - no user notification needed
            // Container will be unmounted on next launch or manual unmount
        }
    }

    private func performUnmountAllAndQuit(applyToPlayCoverContainer: Bool) async {
        CriticalOperationService.shared.beginOperation("全てのディスクイメージをアンマウント")
        defer {
            CriticalOperationService.shared.endOperation()
        }
        
        Logger.unmount("Starting unmount all and quit flow (includePlayCover: \(applyToPlayCoverContainer))")
        
        // Cancel all active auto-unmount tasks to prevent conflicts
        Logger.unmount("Cancelling \(activeUnmountTasks.count) active auto-unmount tasks")
        for (bundleID, task) in activeUnmountTasks {
            task.cancel()
            Logger.unmount("Cancelled auto-unmount for: \(bundleID)")
        }
        activeUnmountTasks.removeAll()
        
        // Wait for tasks to clean up and release locks
        Logger.unmount("Waiting for lock cleanup...")
        try? await Task.sleep(for: .seconds(1.0))
        
        // Explicitly release all locks to ensure no file handles remain
        Logger.unmount("Releasing all container locks...")
        for app in apps {
            await lockService.unlockContainer(for: app.bundleIdentifier)
            // Flush actor queue to ensure file handle is closed
            _ = await lockService.confirmUnlockCompleted()
        }
        Logger.unmount("Lock cleanup completed")
        
        // Set initial processing state
        await MainActor.run {
            unmountFlowState = .processing(status: String(localized: "ディスクイメージをアンマウントしています…"))
        }
        
        var successCount = 0
        var failedCount = 0
        var ejectedDrive: String?
        
        // Count mounted volumes before unmounting (if storage directory is set)
        var volumesBefore = 0
        var volumesAfter = 0
        if let storageDir = settings.diskImageDirectory {
            volumesBefore = await diskImageService.countMountedVolumes(under: storageDir)
            Logger.unmount("Mounted volumes before unmount: \(volumesBefore)")
        }
        
        // Step 1: Check and force eject any remaining app containers
        // (Auto-eject should have already unmounted terminated apps)
        Logger.unmount("Step 1: Checking for remaining app containers")
        await MainActor.run {
            unmountFlowState = .processing(status: String(localized: "アプリコンテナを確認しています…"))
        }
        
        let unmountStartTime = CFAbsoluteTimeGetCurrent()
        for app in apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            
            // Check if app is currently running
            if launcherService.isAppRunning(bundleID: app.bundleIdentifier) {
                failedCount += 1
                continue
            }
            
            // Check if container is still mounted
            let descriptor = try? diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: container)
            guard let descriptor = descriptor, descriptor.isMounted else {
                continue
            }
            
            // Try normal eject first (apps should already be terminated)
            Logger.unmount("Container still mounted for \(app.bundleIdentifier), attempting normal eject")
            
            // Sync preferences and filesystem
            CFPreferencesAppSynchronize(app.bundleIdentifier as CFString)
            sync()
            
            // Brief wait for sync to complete (not cfprefsd - app is already terminated)
            try? await Task.sleep(for: .milliseconds(500))
            
            do {
                try await diskImageService.ejectDiskImage(for: container, force: false)
                Logger.unmount("Successfully ejected container for \(app.bundleIdentifier)")
                successCount += 1
            } catch {
                Logger.unmount("Normal eject failed for \(app.bundleIdentifier), marking as failed: \(error)")
                failedCount += 1
            }
        }
        
        let unmountElapsed = CFAbsoluteTimeGetCurrent() - unmountStartTime
        Logger.performance("Check and force eject of remaining containers: \(String(format: "%.3f", unmountElapsed * 1000))ms")
        Logger.unmount("Results - Success: \(successCount), Failed: \(failedCount)")
        
        
        // If any app container failed, offer force unmount option
        guard failedCount == 0 else {
            await MainActor.run {
                unmountFlowState = .forceUnmountOffering(failedCount: failedCount, applyToPlayCoverContainer: applyToPlayCoverContainer)
            }
            return
        }
        
        // Step 2: Eject PlayCover container
        if applyToPlayCoverContainer {
            await MainActor.run {
                unmountFlowState = .processing(status: String(localized: "PlayCover コンテナをアンマウントしています…"))
            }
            let playCoverContainer = playCoverPaths.containerRootURL
            
            // Check if it's actually mounted
            let isMounted = (try? diskImageService.isMounted(at: playCoverContainer)) ?? false
            if isMounted {
                Logger.unmount("Ejecting PlayCover container")
                
                // Release PlayCover container lock first
                await lockService.unlockContainer(for: playCoverPaths.bundleIdentifier)
                _ = await lockService.confirmUnlockCompleted()
                Logger.unmount("Released PlayCover container lock")
                
                // Sync filesystem
                sync()
                
                // Brief wait for sync to complete
                try? await Task.sleep(for: .milliseconds(500))
                
                do {
                    try await diskImageService.ejectDiskImage(for: playCoverContainer, force: false)
                    Logger.unmount("Successfully ejected PlayCover container")
                    successCount += 1
                } catch {
                    // PlayCover container failed, show error and abort
                    await MainActor.run {
                        unmountFlowState = .error(
                            title: String(localized: "PlayCover コンテナのアンマウントに失敗しました"),
                            message: String(localized: "PlayCover が実行中の可能性があります。\n\nエラー: \(error.localizedDescription)")
                        )
                    }
                    return
                }
            }
        }
        
        
        // Count mounted volumes after unmounting
        if let storageDir = settings.diskImageDirectory {
            volumesAfter = await diskImageService.countMountedVolumes(under: storageDir)
        }
        
        // Step 3: If external drive, eject the whole drive  
        if let storageDir = settings.diskImageDirectory {
            
            // Check if path is under /Volumes/ (typical external mount point)
            let isUnderVolumes = storageDir.path.hasPrefix("/Volumes/")
            
            let isExternal = (try? await diskImageService.isExternalDrive(storageDir)) ?? false
            
            // Use /Volumes/ check as fallback since diskutil might not detect all cases
            let shouldOfferEject = isExternal || isUnderVolumes
            
            if shouldOfferEject {
                // Get volume info (includes device/media name)
                let volumeInfo = try? await diskImageService.getVolumeInfo(for: storageDir)
                let displayName = volumeInfo?.displayName ?? storageDir.lastPathComponent
                
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
                        unmountFlowState = .processing(status: String(localized: "外部ドライブを取り外し可能な状態にしています…"))
                    }
                    statusMessage = String(localized: "外部ドライブを取り外し可能な状態にしています…")
                    if let devicePath = try? await diskImageService.getDevicePath(for: storageDir) {
                        
                        do {
                            try await diskImageService.ejectDrive(devicePath: devicePath)
                            ejectedDrive = displayName
                        } catch {
                            
                            // Eject failed - offer force eject option
                            await MainActor.run {
                                unmountFlowState = .forceEjectOffering(
                                    volumeDisplayName: displayName,
                                    devicePath: devicePath
                                )
                                pendingForceEjectConfirmed = nil  // Reset confirmation state
                            }
                            
                            // Wait for user decision
                            while await MainActor.run(body: { pendingForceEjectConfirmed }) == nil {
                                try? await Task.sleep(for: .milliseconds(100))
                            }
                            
                            let shouldForceEject = await MainActor.run { pendingForceEjectConfirmed == true }
                            
                            if shouldForceEject {
                                // Attempt force eject
                                await MainActor.run {
                                    unmountFlowState = .processing(status: String(localized: "強制イジェクト中…"))
                                }
                                
                                do {
                                    try await diskImageService.ejectDrive(devicePath: devicePath, force: true)
                                    ejectedDrive = displayName
                                    
                                    // Success - continue to show result
                                } catch {
                                    // Force eject also failed - show error
                                    await MainActor.run {
                                        unmountFlowState = .error(
                                            title: String(localized: "強制イジェクトに失敗"),
                                            message: String(localized: "ドライブを強制イジェクトできませんでした。\n\nFinderから手動でイジェクトしてください。")
                                        )
                                    }
                                    return  // Exit early
                                }
                            } else {
                                // User cancelled force eject - continue to show success without eject
                                ejectedDrive = nil
                            }
                        }
                    } else {
                        
                        // Show error to user
                        await MainActor.run {
                            unmountFlowState = .error(
                                title: String(localized: "デバイスパスの取得に失敗"),
                                message: String(localized: "外部ドライブのデバイスパスを取得できませんでした。\n\nFinderから手動でイジェクトしてください。")
                            )
                        }
                        return  // Exit early
                    }
                } else {
                }
            }
        } else {
        }
        
        
        // Step 4: Show result
        let totalUnmounted = volumesBefore - volumesAfter
        
        await MainActor.run {
            unmountFlowState = .success(
                unmountedCount: totalUnmounted > 0 ? totalUnmounted : successCount,
                ejectedDrive: ejectedDrive
            )
        }
    }
    
    func performForceUnmountAll(applyToPlayCoverContainer: Bool) {
        // Swift 6.2: Task.immediate for responsive force unmount
        Task.immediate {
            if isStorageChangeFlow {
                await performForceUnmountForStorageChange()
            } else {
                await performForceUnmountAllAndQuit(applyToPlayCoverContainer: applyToPlayCoverContainer)
            }
        }
    }
    
    /// Perform force unmount for storage change (does not quit)
    private func performForceUnmountForStorageChange() async {
        CriticalOperationService.shared.beginOperation("ストレージ変更の強制アンマウント")
        defer {
            CriticalOperationService.shared.endOperation()
        }
        
        // Cancel all active auto-unmount tasks
        Logger.unmount("Cancelling \(activeUnmountTasks.count) active auto-unmount tasks for force unmount")
        for (_, task) in activeUnmountTasks {
            task.cancel()
        }
        activeUnmountTasks.removeAll()
        try? await Task.sleep(for: .seconds(1.0))
        
        // Explicitly release all locks
        for app in apps {
            await lockService.unlockContainer(for: app.bundleIdentifier)
            _ = await lockService.confirmUnlockCompleted()
        }
        
        await MainActor.run {
            unmountFlowState = .processing(status: String(localized: "強制アンマウント中…"))
        }
        
        var successCount = 0
        var failedCount = 0
        
        // Force unmount all app containers
        for app in apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            
            let descriptor = try? diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: container)
            guard let descriptor = descriptor, descriptor.isMounted else {
                continue
            }
            
            do {
                try await diskImageService.ejectDiskImage(for: container, force: true)
                successCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        // Force unmount PlayCover container
        // Release PlayCover container lock
        await lockService.unlockContainer(for: playCoverPaths.bundleIdentifier)
        _ = await lockService.confirmUnlockCompleted()
        
        let playCoverContainer = playCoverPaths.containerRootURL
        let isMounted = (try? diskImageService.isMounted(at: playCoverContainer)) ?? false
        if isMounted {
            do {
                try await diskImageService.ejectDiskImage(for: playCoverContainer, force: true)
                successCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        await MainActor.run {
            if failedCount > 0 {
                // Still failed after force - show error
                unmountFlowState = .error(
                    title: String(localized: "強制アンマウントに失敗"),
                    message: String(localized: "\(failedCount) 個のコンテナを強制アンマウントできませんでした。\n\nFinderから手動でイジェクトしてから、再度保存先の変更を試してください。")
                )
                isStorageChangeFlow = false
            } else {
                // All succeeded - proceed to storage selection
                unmountFlowState = .idle
                isStorageChangeFlow = false
                restoreWindowFocus()
                
                // Notify AppViewModel to show storage selection
                onStorageChangeCompleted?()
            }
        }
    }
    
    private func performForceUnmountAllAndQuit(applyToPlayCoverContainer: Bool) async {
        CriticalOperationService.shared.beginOperation("強制アンマウント")
        defer {
            CriticalOperationService.shared.endOperation()
        }
        
        // Cancel all active auto-unmount tasks
        Logger.unmount("Cancelling \(activeUnmountTasks.count) active auto-unmount tasks for force unmount and quit")
        for (_, task) in activeUnmountTasks {
            task.cancel()
        }
        activeUnmountTasks.removeAll()
        try? await Task.sleep(for: .seconds(1.0))
        
        // Explicitly release all locks
        for app in apps {
            await lockService.unlockContainer(for: app.bundleIdentifier)
            _ = await lockService.confirmUnlockCompleted()
        }
        
        await MainActor.run {
            unmountFlowState = .processing(status: String(localized: "強制アンマウント中…"))
        }
        
        var successCount = 0
        var failedCount = 0
        
        // Force unmount all app containers
        for app in apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            
            // Check if container is actually mounted
            let descriptor = try? diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: container)
            guard let descriptor = descriptor, descriptor.isMounted else {
                continue
            }
            
            do {
                try await diskImageService.ejectDiskImage(for: container, force: true)
                successCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        // Force unmount PlayCover container if requested
        if applyToPlayCoverContainer {
            // Release PlayCover container lock
            await lockService.unlockContainer(for: playCoverPaths.bundleIdentifier)
            _ = await lockService.confirmUnlockCompleted()
            
            let playCoverContainer = playCoverPaths.containerRootURL
            let isMounted = (try? diskImageService.isMounted(at: playCoverContainer)) ?? false
            if isMounted {
                do {
                    try await diskImageService.ejectDiskImage(for: playCoverContainer, force: true)
                    successCount += 1
                } catch {
                    failedCount += 1
                }
            }
        }
        
        
        // If all unmounts succeeded, check for external drive and offer eject
        if failedCount == 0 {
            // Check if storage directory is on external drive
            guard let storageDir = settings.diskImageDirectory else {
                // No storage directory, just show success
                await MainActor.run {
                    unmountFlowState = .success(unmountedCount: successCount, ejectedDrive: nil)
                }
                return
            }
            
            let isExternal = (try? await diskImageService.isExternalDrive(storageDir)) ?? false
            
            // Also check if path is under /Volumes/ (external media)
            let storagePath = storageDir.path
            let isUnderVolumes = storagePath.hasPrefix("/Volumes/") && storagePath != "/Volumes/Macintosh HD"
            let shouldOfferEject = isExternal || isUnderVolumes
            
            var ejectedDrive: String? = nil
            
            if shouldOfferEject {
                // Get volume info for display
                let volumeInfo = try? await diskImageService.getVolumeInfo(for: storageDir)
                let displayName = volumeInfo?.displayName ?? storageDir.lastPathComponent
                
                // Show eject confirmation
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
                        unmountFlowState = .processing(status: String(localized: "外部ドライブを取り外し可能な状態にしています…"))
                    }
                    
                    if let devicePath = try? await diskImageService.getDevicePath(for: storageDir) {
                        do {
                            try await diskImageService.ejectDrive(devicePath: devicePath)
                            ejectedDrive = displayName
                        } catch {
                            // Eject failed - offer force eject option
                            await MainActor.run {
                                unmountFlowState = .forceEjectOffering(
                                    volumeDisplayName: displayName,
                                    devicePath: devicePath
                                )
                                pendingForceEjectConfirmed = nil  // Reset confirmation state
                            }
                            
                            // Wait for user decision
                            while await MainActor.run(body: { pendingForceEjectConfirmed }) == nil {
                                try? await Task.sleep(for: .milliseconds(100))
                            }
                            
                            let shouldForceEject = await MainActor.run { pendingForceEjectConfirmed == true }
                            
                            if shouldForceEject {
                                // Attempt force eject
                                await MainActor.run {
                                    unmountFlowState = .processing(status: String(localized: "強制イジェクト中…"))
                                }
                                
                                do {
                                    try await diskImageService.ejectDrive(devicePath: devicePath, force: true)
                                    ejectedDrive = displayName
                                } catch {
                                    // Force eject also failed - show error
                                    await MainActor.run {
                                        unmountFlowState = .error(
                                            title: String(localized: "強制イジェクトに失敗"),
                                            message: String(localized: "ドライブを強制イジェクトできませんでした。\n\nFinderから手動でイジェクトしてください。")
                                        )
                                    }
                                    return  // Exit early
                                }
                            } else {
                                // User cancelled force eject - continue to show success without eject
                                ejectedDrive = nil
                            }
                        }
                    } else {
                        // Could not get device path - show error
                        await MainActor.run {
                            unmountFlowState = .error(
                                title: String(localized: "デバイスパスの取得に失敗"),
                                message: String(localized: "外部ドライブのデバイスパスを取得できませんでした。\n\nFinderから手動でイジェクトしてください。")
                            )
                        }
                        return  // Exit early
                    }
                } else {
                    // User chose not to eject
                    ejectedDrive = nil
                }
            }
            
            // Show success
            await MainActor.run {
                unmountFlowState = .success(unmountedCount: successCount, ejectedDrive: ejectedDrive)
            }
        } else {
            // Some unmounts failed
            await MainActor.run {
                unmountFlowState = .error(
                    title: String(localized: "強制アンマウントに失敗"),
                    message: String(localized: "\(failedCount) 個のコンテナを強制アンマウントできませんでした。\n\n手動でFinderからイジェクトしてください。")
                )
            }
        }
    }
    
    // MARK: - Storage Location Change Flow
    
    /// Callback to notify AppViewModel of storage change completion
    var onStorageChangeCompleted: (() -> Void)?
    
    /// Initiate storage location change flow
    /// 1. Check for running apps
    /// 2. Show confirmation dialog
    /// 3. Unmount all containers
    /// 4. Notify AppViewModel to show storage selection
    func initiateStorageLocationChange() {
        // Check for running apps first
        let runningApps = apps.filter { launcherService.isAppRunning(bundleID: $0.bundleIdentifier) }
        
        if !runningApps.isEmpty {
            let appsList = runningApps.map { "• \($0.displayName)" }.joined(separator: "\n")
            unmountFlowState = .error(
                title: String(localized: "実行中のアプリがあります"),
                message: String(localized: "保存先を変更するには、先にこれらのアプリを終了してください。\n\n\(appsList)")
            )
            return
        }
        
        // Count currently mounted containers
        var mountedCount = 0
        
        // Check app containers
        for app in apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            let isMounted = (try? diskImageService.isMounted(at: container)) ?? false
            if isMounted {
                mountedCount += 1
            }
        }
        
        // Check PlayCover container
        let isMounted = (try? diskImageService.isMounted(at: playCoverPaths.containerRootURL)) ?? false
        if isMounted {
            mountedCount += 1
        }
        
        // Show storage change confirmation
        unmountFlowState = .storageChangeConfirming(mountedCount: mountedCount)
    }
    
    /// Confirm storage location change and proceed with unmounting
    func confirmStorageLocationChange() {
        guard case .storageChangeConfirming = unmountFlowState else { return }
        
        isStorageChangeFlow = true  // Mark as storage change flow
        // Swift 6.2: Task.immediate for immediate unmount operation
        Task.immediate { await performUnmountForStorageChange() }
    }
    
    /// Cancel storage location change
    func cancelStorageLocationChange() {
        unmountFlowState = .idle
        isStorageChangeFlow = false
        restoreWindowFocus()
    }
    
    /// Perform unmount all for storage location change (does not quit)
    private func performUnmountForStorageChange() async {
        CriticalOperationService.shared.beginOperation("ストレージ変更のアンマウント")
        defer {
            CriticalOperationService.shared.endOperation()
        }
        
        // Cancel all active auto-unmount tasks
        Logger.unmount("Cancelling \(activeUnmountTasks.count) active auto-unmount tasks for storage change")
        for (_, task) in activeUnmountTasks {
            task.cancel()
        }
        activeUnmountTasks.removeAll()
        try? await Task.sleep(for: .seconds(1.0))
        
        // Explicitly release all locks
        for app in apps {
            await lockService.unlockContainer(for: app.bundleIdentifier)
            _ = await lockService.confirmUnlockCompleted()
        }
        
        await MainActor.run {
            unmountFlowState = .processing(status: String(localized: "すべてのディスクイメージをアンマウント中…"))
        }
        
        var successCount = 0
        var failedCount = 0
        
        // Unmount all app containers
        for app in apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            
            // Check if container is actually mounted
            let descriptor = try? diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: container)
            guard let descriptor = descriptor, descriptor.isMounted else {
                continue
            }
            
            do {
                try await diskImageService.ejectDiskImage(for: container, force: false)
                successCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        // Unmount PlayCover container
        let playCoverContainer = playCoverPaths.containerRootURL
        let isMounted = (try? diskImageService.isMounted(at: playCoverContainer)) ?? false
        if isMounted {
            do {
                try await diskImageService.ejectDiskImage(for: playCoverContainer, force: false)
                successCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        await MainActor.run {
            if failedCount > 0 {
                // Some failed - offer force unmount
                unmountFlowState = .forceUnmountOffering(failedCount: failedCount, applyToPlayCoverContainer: true)
            } else {
                // All succeeded - proceed to storage selection
                unmountFlowState = .idle
                restoreWindowFocus()
                
                // Notify AppViewModel to show storage selection
                onStorageChangeCompleted?()
            }
        }
    }
    
    // MARK: - Process Cleanup
    
    /// Clean up lingering processes from previous failed installations or crashes
    private func cleanupLingeringProcesses(for bundleID: String, containerURL: URL) async {
        // Check if there are any processes using files in the container
        // This handles cases where installation was interrupted and processes are still running
        
        guard FileManager.default.fileExists(atPath: containerURL.path) else {
            return
        }
        
        Logger.lifecycle("Checking for lingering processes for \(bundleID)")
        
        // Use lsof to find processes using this container
        let lsofProcess = Process()
        lsofProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsofProcess.arguments = ["-t", "+D", containerURL.path]
        
        let pipe = Pipe()
        lsofProcess.standardOutput = pipe
        lsofProcess.standardError = Pipe()
        
        do {
            try lsofProcess.run()
            lsofProcess.waitUntilExit()
            
            if lsofProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    let pids = output.split(separator: "\n")
                        .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                        .filter { $0 != getpid() } // Don't kill ourselves
                    
                    if !pids.isEmpty {
                        Logger.lifecycle("Found \(pids.count) lingering processes, cleaning up: \(pids)")
                        
                        for pid in pids {
                            // Try to get process name for logging
                            let psProcess = Process()
                            psProcess.executableURL = URL(fileURLWithPath: "/bin/ps")
                            psProcess.arguments = ["-p", "\(pid)", "-o", "comm="]
                            let psPipe = Pipe()
                            psProcess.standardOutput = psPipe
                            psProcess.standardError = Pipe()
                            try? psProcess.run()
                            psProcess.waitUntilExit()
                            
                            let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
                            let processName = String(data: psData, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
                            
                            Logger.lifecycle("Killing lingering process: PID \(pid) (\(processName))")
                            
                            // Force kill the process
                            let killProcess = Process()
                            killProcess.executableURL = URL(fileURLWithPath: "/bin/kill")
                            killProcess.arguments = ["-9", "\(pid)"]
                            try? killProcess.run()
                            killProcess.waitUntilExit()
                        }
                        
                        // Wait a moment for processes to fully terminate
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        Logger.lifecycle("Lingering process cleanup completed")
                    }
                }
            }
        } catch {
            Logger.lifecycle("Failed to check for lingering processes: \(error)")
        }
    }
    
}

