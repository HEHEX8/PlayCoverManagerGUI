import Foundation
import Observation
import AppKit

@Observable
final class AppViewModel {
    var phase: AppPhase = .checking
    var statusMessage: String = "環境を確認しています…"
    var playCoverPaths: PlayCoverPaths?
    var launcherViewModel: LauncherViewModel?
    var setupViewModel: SetupWizardViewModel?
    var isBusy: Bool = false
    var progress: Double? = nil

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
        Task { await runStartupChecks() }
    }

    func retry() {
        phase = .checking
        statusMessage = "環境を再確認しています…"
        Task { await runStartupChecks() }
    }

    private func runStartupChecks() async {
        do {
            // Check macOS version first (ASIF requires Tahoe 26.0+)
            try environmentService.checkASIFSupport()
            
            let playCoverPaths = try environmentService.detectPlayCover()
            self.playCoverPaths = playCoverPaths

            guard let baseDirectory = settings.diskImageDirectory else {
                statusMessage = "初期セットアップが必要です"
                let context = AppPhase.SetupContext(missingPlayCover: false, missingDiskImage: true, diskImageMountRequired: true)
                await presentSetup(context: context)
                return
            }

            let diskImageURL = baseDirectory.appendingPathComponent("\(playCoverPaths.bundleIdentifier).asif")
            
            // Check if the storage drive is accessible
            guard fileManager.fileExists(atPath: baseDirectory.path) else {
                // Drive is not accessible - show error with options
                throw AppError.diskImage(
                    "ディスクイメージ保存先にアクセスできません",
                    message: "保存先のドライブが接続されていない可能性があります。\n\n保存先: \(baseDirectory.path)"
                )
            }

            if !fileManager.fileExists(atPath: diskImageURL.path) {
                statusMessage = "PlayCover 用ディスクイメージが存在しません"
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
            let appError = AppError.unknown("起動時の検証に失敗しました", message: error.localizedDescription, underlying: error)
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
        let mountPoint = playCoverPaths.containerRootURL
        let nobrowse = settings.nobrowseEnabled
        do {
            try await environmentService.ensureMount(of: diskImageURL, mountPoint: mountPoint, nobrowse: nobrowse)
        } catch {
            throw AppError.diskImage("PlayCover コンテナのマウントに失敗", message: error.localizedDescription, underlying: error)
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
            let appError = AppError.diskImage("アプリ一覧の取得に失敗", message: error.localizedDescription, underlying: error)
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
    /// This should be called from the settings view
    /// The actual UI flow is handled by the LauncherViewModel
    func requestStorageLocationChange() {
        print("[AppViewModel] Storage location change requested")
        // Signal the launcher to initiate storage change flow
        launcherViewModel?.initiateStorageLocationChange()
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
}
