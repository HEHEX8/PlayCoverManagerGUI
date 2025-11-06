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
        case forceUnmountOffering(failedCount: Int, applyToPlayCoverContainer: Bool)
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
            
            try await launcherService.openApp(app)
            pendingLaunchContext = nil
            
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
        appTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            
            let bundleID = app.bundleIdentifier ?? "<no bundle ID>"
            let appName = app.localizedName ?? "<no name>"
            
            guard app.bundleIdentifier != nil else {
                return
            }
            
            // Handle app termination on MainActor
            Task { @MainActor [weak self] in
                guard let self = self else {
                    return
                }
                
                for managedApp in self.apps {
                }
                
                // Check if this is one of our managed apps
                let isManagedApp = self.apps.contains { $0.bundleIdentifier == bundleID }
                
                guard isManagedApp else {
                    return
                }
                
                // Unmount the container for this app
                await self.unmountContainer(for: bundleID)
                
                // Refresh to update running indicator
                await self.refresh()
            }
        }
    }
    */
    
    private func unmountContainer(for bundleID: String) async {
        let containerURL = PlayCoverPaths.containerURL(for: bundleID)
        
        // Release lock first
        lockService.unlockContainer(for: bundleID)
        
        // Check if container is mounted
        let descriptor = try? diskImageService.diskImageDescriptor(for: bundleID, containerURL: containerURL)
        guard let descriptor = descriptor, descriptor.isMounted else {
            return
        }
        
        
        // Check if any other process has a lock on this container
        // With two-step unmount (unmount then eject), the lock check won't interfere
        // because we unmount the volume first, releasing any file handles we opened
        if !lockService.canLockContainer(for: bundleID, at: containerURL) {
            // Another process (possibly PlayCover) is using this container
            // Don't unmount
            return
        }
        
        do {
            // Two-step eject: unmount volume, then detach device
            try await diskImageService.ejectDiskImage(for: containerURL)
        } catch {
            // Silently fail - will retry on next refresh
            // System processes (cfprefsd, etc.) may still be holding file handles
        }
    }

    private func performUnmountAllAndQuit(applyToPlayCoverContainer: Bool) async {
        
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
        }
        
        // Step 1: Unmount all app containers
        await MainActor.run {
            unmountFlowState = .processing(status: "アプリコンテナをアンマウントしています…")
        }
        for app in apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            
            // Check if app is currently running
            if launcherService.isAppRunning(bundleID: app.bundleIdentifier) {
                failedCount += 1
                continue
            }
            
            // Check if container is actually mounted
            let descriptor = try? diskImageService.diskImageDescriptor(for: app.bundleIdentifier, containerURL: container)
            guard let descriptor = descriptor, descriptor.isMounted else {
                continue
            }
            
            do {
                try await diskImageService.ejectDiskImage(for: container)
                successCount += 1
            } catch {
                failedCount += 1
            }
        }
        
        
        // If any app container failed, offer force unmount option
        guard failedCount == 0 else {
            await MainActor.run {
                unmountFlowState = .forceUnmountOffering(failedCount: failedCount, applyToPlayCoverContainer: applyToPlayCoverContainer)
            }
            return
        }
        
        // Step 2: Unmount PlayCover container
        if applyToPlayCoverContainer {
            await MainActor.run {
                unmountFlowState = .processing(status: "PlayCover コンテナをアンマウントしています…")
            }
            let playCoverContainer = playCoverPaths.containerRootURL
            
            // Check if it's actually mounted by querying diskutil
            let isMounted = (try? diskImageService.isMounted(at: playCoverContainer)) ?? false
            if isMounted {
                // Try to eject disk image
                do {
                    try await diskImageService.ejectDiskImage(for: playCoverContainer)
                    successCount += 1
                } catch {
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
            }
        } else {
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
                        unmountFlowState = .processing(status: "外部ドライブを取り外し可能な状態にしています…")
                    }
                    statusMessage = "外部ドライブを取り外し可能な状態にしています…"
                    if let devicePath = try? await diskImageService.getDevicePath(for: storageDir) {
                        
                        do {
                            try await diskImageService.ejectDrive(devicePath: devicePath)
                            ejectedDrive = displayName
                        } catch {
                            
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
        Task {
            await performForceUnmountAllAndQuit(applyToPlayCoverContainer: applyToPlayCoverContainer)
        }
    }
    
    private func performForceUnmountAllAndQuit(applyToPlayCoverContainer: Bool) async {
        
        await MainActor.run {
            unmountFlowState = .processing(status: "強制アンマウント中…")
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
        
        
        // Show result
        if failedCount == 0 {
            await MainActor.run {
                unmountFlowState = .success(unmountedCount: successCount, ejectedDrive: nil)
            }
        } else {
            await MainActor.run {
                unmountFlowState = .error(
                    title: "強制アンマウントに失敗",
                    message: "\(failedCount) 個のコンテナを強制アンマウントできませんでした。\n\n手動でFinderからイジェクトしてください。"
                )
            }
        }
    }
    
    
    
}

