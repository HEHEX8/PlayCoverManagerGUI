import Foundation
import Observation
import AppKit

@Observable
final class AppViewModel {
    var phase: AppPhase = .checking
    var statusMessage: String = String(localized: "環境を確認しています…")
    var playCoverPaths: PlayCoverPaths?
    var launcherViewModel: LauncherViewModel?
    var setupViewModel: SetupWizardViewModel?
    var isBusy: Bool = false
    var progress: Double? = nil
    
    // Termination flow state
    enum TerminationFlowState: Equatable {
        case idle
        case unmounting(status: String)
        case timeout
        case failed(failedCount: Int, runningApps: [String])
    }
    var terminationFlowState: TerminationFlowState = .idle

    private let fileManager: FileManager
    private let settings: SettingsStore
    private let perAppSettings: PerAppSettingsStore
    private let environmentService: PlayCoverEnvironmentService
    private var diskImageService: DiskImageService!
    private let launcherService: LauncherService
    private let lockService: ContainerLockService

    init(fileManager: FileManager = .default,
         settings: SettingsStore,
         perAppSettings: PerAppSettingsStore,
         environmentService: PlayCoverEnvironmentService = PlayCoverEnvironmentService(),
         launcherService: LauncherService = LauncherService()) {
        self.fileManager = fileManager
        self.settings = settings
        self.perAppSettings = perAppSettings
        self.environmentService = environmentService
        self.launcherService = launcherService
        self.lockService = ContainerLockService(fileManager: fileManager)
        self.diskImageService = DiskImageService(fileManager: fileManager, processRunner: ProcessRunner(), settings: settings)
    }

    func onAppear() {
        // Swift 6.2: Task.immediate for immediate UI response
        Task.immediate { await runStartupChecks() }
    }

    func retry() {
        phase = .checking
        statusMessage = String(localized: "環境を再確認しています…")
        // Swift 6.2: Task.immediate starts synchronously until first await
        Task.immediate { await runStartupChecks() }
    }

    private func runStartupChecks() async {
        do {
            // Check macOS version first (ASIF requires Tahoe 26.0+)
            try environmentService.checkASIFSupport()
            
            // Check Full Disk Access permission (required for ~/Library/Containers)
            guard environmentService.checkFullDiskAccess() else {
                throw AppError.permissionDenied(
                    String(localized: "フルディスクアクセス権限が必要です"),
                    message: String(localized: "このアプリは ~/Library/Containers/ にアクセスする必要があります。\n\n対処方法：\n1. システム設定を開く（⌘Space で「システム設定」を検索）\n2. プライバシーとセキュリティ > フルディスクアクセス\n3. 「+」ボタンで PlayCover Manager を追加\n4. アプリを再起動してください")
                )
            }
            
            let playCoverPaths = try environmentService.detectPlayCover()
            self.playCoverPaths = playCoverPaths

            guard let baseDirectory = settings.diskImageDirectory else {
                statusMessage = String(localized: "初期セットアップが必要です")
                let context = AppPhase.SetupContext(missingPlayCover: false, missingDiskImage: true, diskImageMountRequired: true)
                await presentSetup(context: context)
                return
            }

            let diskImageURL = baseDirectory.appendingPathComponent("\(playCoverPaths.bundleIdentifier).asif")
            
            // Check if the storage drive is accessible
            guard fileManager.fileExists(atPath: baseDirectory.path) else {
                // Drive is not accessible - show error with options
                throw AppError.diskImage(
                    String(localized: "ディスクイメージ保存先にアクセスできません"),
                    message: String(localized: "保存先のドライブが接続されていない可能性があります。\n\n保存先: \(baseDirectory.path)")
                )
            }

            if !fileManager.fileExists(atPath: diskImageURL.path) {
                statusMessage = String(localized: "PlayCover 用ディスクイメージが存在しません")
                let context = AppPhase.SetupContext(missingPlayCover: false, missingDiskImage: true, diskImageMountRequired: true)
                await presentSetup(context: context)
                return
            }

            try await ensureContainerMounted(for: playCoverPaths, diskImageURL: diskImageURL)
            await loadLauncher(playCoverPaths: playCoverPaths)
        } catch let error as AppError {
            if case .environment = error.category {
                let context = AppPhase.SetupContext(missingPlayCover: true, missingDiskImage: true, diskImageMountRequired: true)
                await presentSetup(context: context)
            } else {
                phase = .error(error)
            }
        } catch {
            let appError = AppError.unknown(String(localized: "起動時の検証に失敗しました"), message: error.localizedDescription, underlying: error)
            phase = .error(appError)
        }
    }

    private func presentSetup(context: AppPhase.SetupContext) async {
        let setupVM = SetupWizardViewModel(settings: settings,
                                           environmentService: environmentService,
                                           diskImageService: diskImageService,
                                           context: context,
                                           initialPlayCoverPaths: playCoverPaths)
        setupVM.onCompletion = { [weak self] in
            self?.setupViewModel = nil
            self?.phase = .checking
            self?.retry()
        }
        setupViewModel = setupVM
        phase = .setup(context)
    }

    private func ensureContainerMounted(for playCoverPaths: PlayCoverPaths, diskImageURL: URL) async throws {
        await CriticalOperationService.shared.beginOperation("PlayCover コンテナマウント")
        defer {
            Task { @MainActor in
                await CriticalOperationService.shared.endOperation()
            }
        }
        
        let mountPoint = playCoverPaths.containerRootURL
        do {
            // Use PlayCover's own mount method (not our helper since this is PlayCover's container)
            let nobrowse = settings.nobrowseEnabled
            try await environmentService.ensureMount(of: diskImageURL, mountPoint: mountPoint, nobrowse: nobrowse)
            
            // Acquire lock on PlayCover container to prevent unmounting while in use
            Logger.debug("Acquiring lock for PlayCover container: \(playCoverPaths.bundleIdentifier)")
            _ = await lockService.lockContainer(for: playCoverPaths.bundleIdentifier, at: mountPoint)
        } catch {
            throw AppError.diskImage(String(localized: "PlayCover コンテナのマウントに失敗"), message: error.localizedDescription, underlying: error)
        }
    }

    private func loadLauncher(playCoverPaths: PlayCoverPaths) async {
        do {
            let apps = try launcherService.fetchInstalledApps(at: playCoverPaths.applicationsRootURL)
            let vm = LauncherViewModel(apps: apps,
                                       playCoverPaths: playCoverPaths,
                                       diskImageService: diskImageService,
                                       launcherService: launcherService,
                                       settings: settings,
                                       perAppSettings: perAppSettings,
                                       lockService: lockService,
                                       processRunner: ProcessRunner())
            
            // Set callback for storage location change
            vm.onStorageChangeCompleted = { [weak self] in
                self?.completeStorageLocationChange()
            }
            
            launcherViewModel = vm
            phase = .launcher
        } catch {
            let appError = AppError.diskImage(String(localized: "アプリ一覧の取得に失敗"), message: error.localizedDescription, underlying: error)
            phase = .error(appError)
        }
    }

    func openSettings() {
        // SwiftUI Settings scene can be opened via these private selectors.
        // Try the modern name first, then fall back for older toolchains.
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    /// Request to change storage location
    /// This should be called from the settings view or error screen
    func requestStorageLocationChange() {
        // If launcher exists, use its flow (which handles unmounting)
        if let launcherVM = launcherViewModel {
            launcherVM.initiateStorageLocationChange()
        } else {
            // If no launcher (e.g., startup error), directly show storage wizard
            completeStorageLocationChange()
        }
    }
    
    /// Complete storage location change after unmounting
    /// Called by LauncherViewModel after successful unmount
    func completeStorageLocationChange() {
        // Create context for storage change (PlayCover exists, no disk image check, no mount required)
        let context = AppPhase.SetupContext(
            missingPlayCover: false,
            missingDiskImage: false,
            diskImageMountRequired: false
        )
        
        // Create setup wizard for storage selection
        let setupVM = SetupWizardViewModel(
            settings: settings,
            environmentService: environmentService,
            diskImageService: diskImageService,
            context: context,
            initialPlayCoverPaths: playCoverPaths
        )
        
        // Start from selectStorage step
        setupVM.currentStep = .selectStorage
        setupVM.onCompletion = { [weak self] in
            self?.setupViewModel = nil
            self?.phase = .checking
            self?.retry()
        }
        
        setupViewModel = setupVM
        phase = .setup(context)
    }
    
    @available(*, deprecated, message: "Use requestStorageLocationChange instead")
    func changeStorageSettings() {
        requestStorageLocationChange()
    }
    
    func terminateApplication() {
        phase = .terminating
        NSApplication.shared.terminate(nil)
    }
    
    func cancelTermination() {
        terminationFlowState = .idle
        NSApplication.shared.reply(toApplicationShouldTerminate: false)
    }
    
    func forceTerminate() {
        terminationFlowState = .idle
        Logger.debug("[DEBUG] Force terminating application with exit(0)")
        // Use exit(0) to actually force terminate the app
        // This bypasses any further unmount attempts
        exit(0)
    }
    
    func continueWaiting() {
        terminationFlowState = .unmounting(status: String(localized: "アンマウント処理を続行しています…"))
        // Extend timeout by 5 seconds
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            appDelegate.extendTimeout()
        }
    }
    
    /// Unmount PlayCover's own container when app terminates
    @MainActor
    func unmountPlayCoverContainer() async {
        guard let playCoverPaths = playCoverPaths else { return }
        
        await CriticalOperationService.shared.beginOperation("PlayCover コンテナアンマウント")
        defer {
            Task { @MainActor in
                await CriticalOperationService.shared.endOperation()
            }
        }
        
        let containerURL = playCoverPaths.containerRootURL
        
        // Check if mounted
        let isMounted = (try? diskImageService.isMounted(at: containerURL)) ?? false
        guard isMounted else { return }
        
        do {
            // Unmount PlayCover's container with force
            try await diskImageService.ejectDiskImage(for: containerURL, force: true)
            Logger.unmount("Successfully unmounted PlayCover container")
        } catch {
            Logger.error("Failed to unmount PlayCover container: \(error)")
        }
    }
    
    /// Unmount all containers for app termination
    /// Returns result with success status, failed count, and running apps
    @MainActor
    func unmountAllContainersForTermination() async -> (success: Bool, failedCount: Int, runningApps: [String]) {
        guard let launcherVM = launcherViewModel,
              let playCoverPaths = playCoverPaths else {
            return (success: true, failedCount: 0, runningApps: [])
        }
        
        await CriticalOperationService.shared.beginOperation("終了時の全コンテナアンマウント")
        defer {
            Task { @MainActor in
                await CriticalOperationService.shared.endOperation()
            }
        }
        
        var failedCount = 0
        var runningApps: [String] = []
        
        // Step 1: Check for running apps
        for app in launcherVM.apps {
            if launcherService.isAppRunning(bundleID: app.bundleIdentifier) {
                runningApps.append(app.bundleIdentifier)
                failedCount += 1
            }
        }
        
        // If there are running apps, don't proceed
        if !runningApps.isEmpty {
            return (success: false, failedCount: failedCount, runningApps: runningApps)
        }
        
        // Cancel all active auto-unmount tasks to prevent conflicts
        Logger.unmount("Cancelling \(launcherVM.activeUnmountTaskCount) active auto-unmount tasks")
        await launcherVM.cancelAllAutoUnmountTasks()
        
        // Wait for tasks to clean up and release locks
        Logger.unmount("Waiting for lock cleanup...")
        try? await Task.sleep(for: .seconds(1.0))
        
        // Explicitly release all locks to ensure no file handles remain
        Logger.unmount("Releasing all container locks...")
        for app in launcherVM.apps {
            await lockService.unlockContainer(for: app.bundleIdentifier)
            // Flush actor queue to ensure file handle is closed
            _ = await lockService.confirmUnlockCompleted()
        }
        Logger.unmount("Lock cleanup completed")
        
        // Step 2: Check and unmount any remaining app containers
        // (Auto-eject should have already unmounted terminated apps)
        for app in launcherVM.apps {
            let container = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
            
            // Check if still mounted
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
            } catch {
                Logger.unmount("Normal eject failed for \(app.bundleIdentifier), marking as failed: \(error)")
                failedCount += 1
            }
        }
        
        // Step 3: Normal eject PlayCover's own container
        let playCoverContainer = playCoverPaths.containerRootURL
        let isMounted = (try? diskImageService.isMounted(at: playCoverContainer)) ?? false
        
        if isMounted {
            Logger.unmount("Ejecting PlayCover container")
            
            // Release PlayCover container lock first
            await lockService.unlockContainer(for: playCoverPaths.bundleIdentifier)
            _ = await lockService.confirmUnlockCompleted()
            Logger.unmount("Released PlayCover container lock")
            
            // Sync filesystem
            sync()
            try? await Task.sleep(for: .milliseconds(500))
            
            do {
                try await diskImageService.ejectDiskImage(for: playCoverContainer, force: false)
                Logger.unmount("Successfully ejected PlayCover container")
            } catch {
                Logger.unmount("Normal eject failed for PlayCover container: \(error)")
                failedCount += 1
            }
        }
        
        return (success: failedCount == 0, failedCount: failedCount, runningApps: runningApps)
    }
}
