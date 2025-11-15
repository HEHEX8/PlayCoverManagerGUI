import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class SetupWizardViewModel {
    enum Step: Int, CaseIterable, Identifiable {
        case installPlayCover
        case selectStorage
        case prepareDiskImage
        case finished

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .installPlayCover:
                return String(localized: "PlayCover の準備")
            case .selectStorage:
                return String(localized: "ディスクイメージ保存先")
            case .prepareDiskImage:
                return String(localized: "ディスクイメージ作成")
            case .finished:
                return String(localized: "完了")
            }
        }

        var description: String {
            switch self {
            case .installPlayCover:
                return String(localized: "PlayCover.app が /Applications に存在する必要があります。")
            case .selectStorage:
                return String(localized: "ASIF ディスクイメージの保存先を選択してください。外部ストレージがおすすめですが強制ではありません。")
            case .prepareDiskImage:
                return String(localized: "io.playcover.PlayCover 用の ASIF イメージを作成しマウントします。")
            case .finished:
                return String(localized: "セットアップが完了しました。")
            }
        }
    }

    var currentStep: Step
    var isBusy = false
    var statusMessage: String = ""
    var error: AppError?
    var storageURL: URL?
    var storageType: DiskImageService.StorageType?
    var showStorageWarning: Bool = false
    var completionMessage: String = String(localized: "セットアップが完了しました。")

    var onCompletion: (() -> Void)?

    private let settings: SettingsStore
    private let environmentService: PlayCoverEnvironmentService
    private let diskImageService: DiskImageService
    private let context: AppPhase.SetupContext
    var detectedPlayCoverPaths: PlayCoverPaths?

    init(settings: SettingsStore,
         environmentService: PlayCoverEnvironmentService,
         diskImageService: DiskImageService,
         context: AppPhase.SetupContext,
         initialPlayCoverPaths: PlayCoverPaths? = nil) {
        self.settings = settings
        self.environmentService = environmentService
        self.diskImageService = diskImageService
        self.context = context
        self.detectedPlayCoverPaths = initialPlayCoverPaths
        if context.missingPlayCover {
            currentStep = .installPlayCover
            // Swift 6.2: Task.immediate for instant PlayCover detection
            Task.immediate { @MainActor in
                if let paths = try? environmentService.detectPlayCover() {
                    self.detectedPlayCoverPaths = paths
                }
            }
        } else if settings.diskImageDirectory == nil {
            currentStep = .selectStorage
        } else {
            currentStep = .prepareDiskImage
        }
        storageURL = settings.diskImageDirectory
    }

    func openPlayCoverWebsite() {
        if let url = URL(string: "https://playcover.io") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func chooseStorageDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "選択")
        panel.title = String(localized: "ディスクイメージの保存先")
        panel.message = String(localized: "ASIF ディスクイメージを保存するフォルダを選択してください。")
        
        // Performance: Set default directory to user's home for faster open
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
        
        // Performance: Disable unnecessary features that cause I/O overhead
        panel.animationBehavior = .none
        panel.showsHiddenFiles = false
        panel.showsTagField = false  // Disable tag field (causes Spotlight metadata queries)
        panel.resolvesAliases = false  // Disable alias resolution (causes filesystem lookups)
        panel.canCreateDirectories = false  // Disable folder creation UI
        panel.treatsFilePackagesAsDirectories = false  // Don't treat .app bundles as directories
        
        if panel.runModal() == .OK, let url = panel.url {
            storageURL = url
            settings.diskImageDirectory = url
            
            // Detect storage type
            Task {
                await detectStorageType(for: url)
            }
        }
    }
    
    func detectStorageType(for url: URL) async {
        do {
            let type = try await diskImageService.detectStorageType(for: url)
            await MainActor.run {
                storageType = type
                showStorageWarning = type.isSlow
                
                // Reject USB 2.0 or lower
                if type.isProhibited, let reason = type.prohibitedReason {
                    error = AppError.environment(
                        String(localized: "このストレージは使用できません"),
                        message: reason
                    )
                    storageURL = nil
                    settings.diskImageDirectory = nil
                }
            }
        } catch {
            Logger.error("Failed to detect storage type: \(error)")
            await MainActor.run {
                storageType = .unknown
                showStorageWarning = true
            }
        }
    }

    func continueAction(playCoverPaths: PlayCoverPaths?) {
        switch currentStep {
        case .installPlayCover:
            // Swift 6.2: Task.immediate for responsive verification
            Task.immediate { await verifyPlayCoverExists() }
        case .selectStorage:
            guard storageURL != nil else {
                error = AppError.environment(String(localized: "保存先が選択されていません"), message: "ディスクイメージ保存先を選択してください")
                return
            }
            advance()
        case .prepareDiskImage:
            let resolvedPaths = playCoverPaths ?? detectedPlayCoverPaths ?? (try? environmentService.detectPlayCover())
            guard let paths = resolvedPaths else {
                error = AppError.environment(String(localized: "PlayCover.app が検出できません"), message: "PlayCover をインストールして再試行してください")
                return
            }
            detectedPlayCoverPaths = paths
            // Swift 6.2: Task.immediate for immediate disk image preparation
            Task.immediate { await prepareDiskImage(bundleID: paths.bundleIdentifier, mountPoint: paths.containerRootURL) }
        case .finished:
            onCompletion?()
        }
    }

    private func verifyPlayCoverExists() async {
        do {
            let paths = try environmentService.detectPlayCover()
            detectedPlayCoverPaths = paths
            advance()
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.environment(String(localized: "PlayCover の確認に失敗"), message: error.localizedDescription, underlying: error)
        }
    }

    private func prepareDiskImage(bundleID: String, mountPoint: URL) async {
        CriticalOperationService.shared.beginOperation("セットアップのディスクイメージ作成")
        defer {
            CriticalOperationService.shared.endOperation()
        }
        
        isBusy = true
        statusMessage = String(localized: "ディスクイメージを作成しています…")
        defer { isBusy = false }
        do {
            _ = try await diskImageService.ensureDiskImageExists(for: bundleID, volumeName: bundleID)
            // Use common helper for mounting
            let perAppSettings = PerAppSettingsStore()
            try await DiskImageHelper.mountDiskImageIfNeeded(
                for: bundleID,
                containerURL: mountPoint,
                diskImageService: diskImageService,
                perAppSettings: perAppSettings,
                globalSettings: settings
            )
            
            // Create Applications directory structure in the mounted volume
            let applicationsDir = mountPoint.appendingPathComponent("Applications", isDirectory: true)
            try FileManager.default.createDirectory(at: applicationsDir, withIntermediateDirectories: true)
            
            advance()
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage(String(localized: "ディスクイメージの準備に失敗"), message: error.localizedDescription, underlying: error)
        }
    }

    private func advance() {
        if let next = Step(rawValue: currentStep.rawValue + 1) {
            currentStep = next
        }
    }

    func back() {
        if let previous = Step(rawValue: currentStep.rawValue - 1) {
            currentStep = previous
        }
    }
}
