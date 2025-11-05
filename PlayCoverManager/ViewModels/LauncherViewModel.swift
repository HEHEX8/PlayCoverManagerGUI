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

    private var pendingLaunchContext: LaunchContext?
    private nonisolated(unsafe) var appTerminationObserver: NSObjectProtocol?

    init(apps: [PlayCoverApp],
         playCoverPaths: PlayCoverPaths,
         diskImageService: DiskImageService,
         launcherService: LauncherService,
         settings: SettingsStore,
         perAppSettings: PerAppSettingsStore,
         lockService: ContainerLockService,
         fileManager: FileManager = .default) {
        self.apps = apps
        self.filteredApps = apps
        self.playCoverPaths = playCoverPaths
        self.diskImageService = diskImageService
        self.launcherService = launcherService
        self.settings = settings
        self.perAppSettings = perAppSettings
        self.lockService = lockService
        self.fileManager = fileManager
        
        // Cleanup stale lock files on startup
        cleanupStaleLockFiles()
        
        // Start monitoring app terminations
        startMonitoringAppTerminations()
    }
    
    nonisolated deinit {
        // Stop monitoring - need to do this synchronously in deinit
        if let observer = appTerminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
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
            let refreshed = try launcherService.fetchInstalledApps(at: playCoverPaths.applicationsRootURL)
            apps = refreshed
            applySearch()
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
            _ = lockService.lockContainer(for: app.bundleIdentifier, at: containerURL)
            
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
        Task { await performUnmountAll(applyToPlayCoverContainer: applyToPlayCoverContainer) }
    }
    
    func getPerAppSettings() -> PerAppSettingsStore {
        return perAppSettings
    }
    
    // MARK: - App Termination Monitoring
    
    private func startMonitoringAppTerminations() {
        appTerminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            guard let bundleID = app.bundleIdentifier else { return }
            
            // Handle app termination on MainActor
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Check if this is one of our managed apps
                let isManagedApp = self.apps.contains { $0.bundleIdentifier == bundleID }
                guard isManagedApp else { return }
                
                // Unmount the container for this app
                await self.unmountContainer(for: bundleID)
                
                // Refresh to update running indicator
                await self.refresh()
            }
        }
    }
    
    private func unmountContainer(for bundleID: String) async {
        let containerURL = containerURL(for: bundleID)
        
        // Release lock first
        lockService.unlockContainer(for: bundleID)
        
        // Check if container is mounted
        let descriptor = try? diskImageService.diskImageDescriptor(for: bundleID, containerURL: containerURL)
        guard let descriptor = descriptor, descriptor.isMounted else {
            return
        }
        
        // Check if any other process has a lock on this container
        if !lockService.canLockContainer(for: bundleID, at: containerURL) {
            // Another process (possibly PlayCover) is using this container
            // Don't unmount
            return
        }
        
        do {
            try await diskImageService.detach(volumeURL: containerURL)
        } catch {
            // Silently fail - don't show error for auto-unmount
            // The user might have manually unmounted it already
        }
    }

    private func performUnmountAll(applyToPlayCoverContainer: Bool) async {
        isBusy = true
        isShowingStatus = true  // Show status for unmount operation
        statusMessage = "ディスクイメージをアンマウントしています…"
        defer { 
            isBusy = false
            isShowingStatus = false
        }
        do {
            var volumeURLs: [URL] = []
            for app in apps {
                let container = containerURL(for: app.bundleIdentifier)
                if fileManager.fileExists(atPath: container.path) && !volumeURLs.contains(container) {
                    volumeURLs.append(container)
                }
            }
            if applyToPlayCoverContainer {
                let playCoverContainer = playCoverPaths.containerRootURL
                if !volumeURLs.contains(playCoverContainer) {
                    volumeURLs.append(playCoverContainer)
                }
            }
            try await diskImageService.detachAll(volumeURLs: volumeURLs)
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage("アンマウントに失敗", message: error.localizedDescription, underlying: error)
        }
    }
}

