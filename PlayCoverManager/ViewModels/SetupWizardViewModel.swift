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
                return "PlayCover の準備"
            case .selectStorage:
                return "ディスクイメージ保存先"
            case .prepareDiskImage:
                return "ディスクイメージ作成"
            case .finished:
                return "完了"
            }
        }

        var description: String {
            switch self {
            case .installPlayCover:
                return "PlayCover.app が /Applications に存在する必要があります。"
            case .selectStorage:
                return "ASIF ディスクイメージの保存先を選択してください。外部ストレージがおすすめですが強制ではありません。"
            case .prepareDiskImage:
                return "io.playcover.PlayCover 用の ASIF イメージを作成しマウントします。"
            case .finished:
                return "セットアップが完了しました。"
            }
        }
    }

    var currentStep: Step
    var isBusy = false
    var statusMessage: String = ""
    var error: AppError?
    var storageURL: URL?
    var completionMessage: String = "セットアップが完了しました。"

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
            // Try to detect PlayCover immediately on init
            Task { @MainActor in
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
        panel.prompt = "選択"
        panel.title = "ディスクイメージの保存先"
        panel.message = "ASIF ディスクイメージを保存するフォルダを選択してください。"
        if panel.runModal() == .OK, let url = panel.url {
            storageURL = url
            settings.diskImageDirectory = url
        }
    }

    func continueAction(playCoverPaths: PlayCoverPaths?) {
        switch currentStep {
        case .installPlayCover:
            Task { await verifyPlayCoverExists() }
        case .selectStorage:
            guard storageURL != nil else {
                error = AppError.environment("保存先が選択されていません", message: "ディスクイメージ保存先を選択してください")
                return
            }
            advance()
        case .prepareDiskImage:
            let resolvedPaths = playCoverPaths ?? detectedPlayCoverPaths ?? (try? environmentService.detectPlayCover())
            guard let paths = resolvedPaths else {
                error = AppError.environment("PlayCover.app が検出できません", message: "PlayCover をインストールして再試行してください")
                return
            }
            detectedPlayCoverPaths = paths
            Task { await prepareDiskImage(bundleID: paths.bundleIdentifier, mountPoint: paths.containerRootURL) }
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
            self.error = AppError.environment("PlayCover の確認に失敗", message: error.localizedDescription, underlying: error)
        }
    }

    private func prepareDiskImage(bundleID: String, mountPoint: URL) async {
        isBusy = true
        statusMessage = "ディスクイメージを作成しています…"
        defer { isBusy = false }
        do {
            _ = try await diskImageService.ensureDiskImageExists(for: bundleID, volumeName: bundleID)
            let nobrowse = settings.nobrowseEnabled
            try await diskImageService.mountDiskImage(for: bundleID, at: mountPoint, nobrowse: nobrowse)
            
            // Create Applications directory structure in the mounted volume
            let applicationsDir = mountPoint.appendingPathComponent("Applications", isDirectory: true)
            try FileManager.default.createDirectory(at: applicationsDir, withIntermediateDirectories: true)
            
            advance()
        } catch let error as AppError {
            self.error = error
        } catch {
            self.error = AppError.diskImage("ディスクイメージの準備に失敗", message: error.localizedDescription, underlying: error)
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
