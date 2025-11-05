import Foundation
import Combine
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var phase: AppPhase = .checking
    @Published var statusMessage: String = "環境を確認しています…"
    @Published var playCoverPaths: PlayCoverPaths?
    @Published var launcherViewModel: LauncherViewModel?
    @Published var setupViewModel: SetupWizardViewModel?
    @Published var isBusy: Bool = false
    @Published var progress: Double? = nil

    private let fileManager: FileManager
    private let settings: SettingsStore
    private let environmentService: PlayCoverEnvironmentService
    private var diskImageService: DiskImageService!
    private let launcherService: LauncherService
    private let installerService: InstallerService

    init(fileManager: FileManager = .default,
         settings: SettingsStore,
         environmentService: PlayCoverEnvironmentService = PlayCoverEnvironmentService(),
         launcherService: LauncherService = LauncherService(),
         installerService: InstallerService = InstallerService()) {
        self.fileManager = fileManager
        self.settings = settings
        self.environmentService = environmentService
        self.launcherService = launcherService
        self.installerService = installerService
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
            let playCoverPaths = try environmentService.detectPlayCover()
            self.playCoverPaths = playCoverPaths

            guard let baseDirectory = settings.diskImageDirectory else {
                statusMessage = "初期セットアップが必要です"
                let context = AppPhase.SetupContext(missingPlayCover: false, missingDiskImage: true, diskImageMountRequired: true)
                await presentSetup(context: context)
                return
            }

            let diskImageURL = baseDirectory.appendingPathComponent("\(playCoverPaths.bundleIdentifier).asif")
            guard fileManager.fileExists(atPath: baseDirectory.path) else {
                statusMessage = "ディスクイメージ保存先が見つかりません"
                let context = AppPhase.SetupContext(missingPlayCover: false, missingDiskImage: true, diskImageMountRequired: true)
                await presentSetup(context: context)
                return
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
                                       settings: settings)
            launcherViewModel = vm
            phase = .launcher
        } catch {
            let appError = AppError.diskImage("アプリ一覧の取得に失敗", message: error.localizedDescription, underlying: error)
            phase = .error(appError)
        }
    }

    func openSettings() {
        NSApp.sendAction(#selector(NSApplicationDelegate.openPreferences), to: nil, from: nil)
    }

    func terminateApplication() {
        phase = .terminating
        NSApplication.shared.terminate(nil)
    }
}
