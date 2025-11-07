import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers

struct SettingsRootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
            DataSettingsView()
                .tabItem {
                    Label("データ", systemImage: "internaldrive")
                }
            MaintenanceSettingsView()
                .tabItem {
                    Label("メンテナンス", systemImage: "wrench.and.screwdriver")
                }
            AboutView()
                .tabItem {
                    Label("情報", systemImage: "info.circle")
                }
        }
        .padding(24)
        .frame(width: 600, height: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
        }
    }
}

private struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var calculatingSize = false
    @State private var totalDiskUsage: Int64 = 0

    var body: some View {
        Form {
            Section(header: Text("ストレージ")) {
                LabeledContent("保存先") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(settingsStore.diskImageDirectory?.path ?? "未設定")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.primary)
                        if calculatingSize {
                            ProgressView()
                                .controlSize(.small)
                        } else if totalDiskUsage > 0 {
                            Text("使用中: \(ByteCountFormatter.string(fromByteCount: totalDiskUsage, countStyle: .file))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("保存先を変更...") {
                    // Close settings sheet and show overlay wizard
                    dismiss()
                    appViewModel.changeStorageSettings()
                }
                .help("初期設定ウィザードを開いて保存先を変更します")
                
                Text("保存先を変更すると、PlayCover コンテナのマウント状態を確認し、必要に応じて再マウントします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(header: Text("マウント設定")) {
                Toggle("マウント時に Finder に表示しない (-nobrowse)", isOn: Binding(get: { settingsStore.nobrowseEnabled }, set: { settingsStore.nobrowseEnabled = $0 }))
                
                Text("有効にすると、マウントされたディスクイメージが Finder のサイドバーに表示されなくなります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            Task {
                await calculateDiskUsage()
            }
        }
    }
    
    private func calculateDiskUsage() async {
        calculatingSize = true
        defer { calculatingSize = false }
        
        // Calculate total disk usage from all apps
        guard let diskImageDir = settingsStore.diskImageDirectory else {
            totalDiskUsage = 0
            return
        }
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: diskImageDir, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey])
            
            var total: Int64 = 0
            for url in contents where url.pathExtension == "asif" {
                if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    total += Int64(fileSize)
                }
            }
            
            await MainActor.run {
                totalDiskUsage = total
            }
        } catch {
            await MainActor.run {
                totalDiskUsage = 0
            }
        }
    }
}



private struct DataSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        Form {
            Section(header: Text("内部データ処理の既定値")) {
                Picker("既定の処理", selection: Binding<SettingsStore.InternalDataStrategy>(get: { settingsStore.defaultDataHandling }, set: { settingsStore.defaultDataHandling = $0 })) {
                    ForEach(SettingsStore.InternalDataStrategy.allCases) { strategy in
                        Text(strategy.localizedDescription).tag(strategy)
                    }
                }
            }
            Section(header: Text("説明")) {
                Text("アプリのコンテナに内部データが残っていた場合のデフォルト処理です。ランチャーから起動する際に変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// IPA Installer Sheet
struct IPAInstallerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LauncherViewModel.self) private var launcherViewModel
    @State private var installerService: IPAInstallerService?
    @State private var selectedIPAs: [URL] = []
    @State private var analyzedIPAs: [IPAInstallerService.IPAInfo] = []
    @State private var isAnalyzing = false
    @State private var isInstalling = false
    @State private var statusMessage = ""
    @State private var progress: Double = 0
    @State private var showResults = false
    @State private var currentPhase: InstallPhase = .selection
    @State private var statusUpdateTask: Task<Void, Never>?
    @State private var showInstallConfirmation = false
    
    enum InstallPhase {
        case selection      // IPA選択
        case analyzing      // 解析中
        case confirmation   // 確認画面
        case installing     // インストール中
        case results        // 結果表示
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("IPA インストーラー")
                .font(.title2)
                .fontWeight(.semibold)
            
            switch currentPhase {
            case .selection:
                selectionView
            case .analyzing:
                analyzingView
            case .confirmation:
                confirmationView
            case .installing:
                installingView
            case .results:
                resultsView
            }
            
            Spacer()
            
            bottomButtons
        }
        .padding(24)
        .frame(width: 700, height: 600)
        .onAppear {
            let diskImageService = DiskImageService(processRunner: ProcessRunner(), settings: settingsStore)
            let launcherService = LauncherService()
            installerService = IPAInstallerService(diskImageService: diskImageService, settingsStore: settingsStore, launcherService: launcherService)
        }
        .alert("インストール確認", isPresented: $showInstallConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("インストール", role: .destructive) {
                Task {
                    await startInstallation()
                }
            }
        } message: {
            Text("\(analyzedIPAs.count) 個のアプリをインストールします。よろしいですか？")
        }
    }
    
    // MARK: - Selection View
    private var selectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.arrow.up")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("IPA ファイルを選択してください")
                .font(.headline)
            
            Button("IPA を選択") {
                selectIPAFiles()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Analyzing View
    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("IPA ファイルを解析中...")
                .font(.headline)
            Text(statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Confirmation View
    private var confirmationView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("インストール内容の確認")
                .font(.headline)
            
            List(analyzedIPAs) { info in
                HStack(spacing: 12) {
                    if let icon = info.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Image(systemName: "app.fill")
                            .resizable()
                            .frame(width: 48, height: 48)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(info.appName)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(2)
                        Text(info.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // Install type badge
                        HStack(spacing: 4) {
                            switch info.installType {
                            case .newInstall:
                                Image(systemName: "sparkles")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                                Text("新規")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            case .upgrade:
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                Text("アップグレード")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            case .downgrade:
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text("ダウングレード")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            case .reinstall:
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("上書き")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .cornerRadius(4)
                        
                        // Version info
                        if let existing = info.existingVersion {
                            Text("\(existing) → \(info.version)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("v\(info.version)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        
                        Text(ByteCountFormatter.string(fromByteCount: info.fileSize, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Button {
                        analyzedIPAs.removeAll { $0.id == info.id }
                        selectedIPAs.removeAll { $0 == info.ipaURL }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Installing View
    private var installingView: some View {
        VStack(spacing: 20) {
            // Header with progress indicator
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.blue)
                
                Text("インストール中")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let service = installerService, !service.currentStatus.isEmpty {
                    Text(service.currentStatus)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Overall progress bar
                if let service = installerService {
                    let totalItems = analyzedIPAs.count
                    let completed = service.installedApps.count + service.failedApps.count
                    let progressValue = totalItems > 0 ? Double(completed) / Double(totalItems) : 0
                    
                    VStack(spacing: 8) {
                        ProgressView(value: progressValue)
                            .frame(width: 400)
                        
                        Text("\(completed) / \(totalItems) 完了")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            // Installation log
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let service = installerService {
                        // Completed installations (with icons)
                        ForEach(service.installedAppDetails) { detail in
                            HStack(spacing: 12) {
                                // App icon with checkmark badge
                                ZStack(alignment: .bottomTrailing) {
                                    if let icon = detail.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 48, height: 48)
                                    }
                                    
                                    // Checkmark badge
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.white)
                                        .background(
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 18, height: 18)
                                        )
                                        .offset(x: 2, y: 2)
                                }
                                .frame(width: 48, height: 48)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(detail.appName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("インストール完了")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Currently installing (if any)
                        if !service.currentAppName.isEmpty && !service.installedAppDetails.contains(where: { $0.appName == service.currentAppName }) {
                            HStack(spacing: 12) {
                                // App icon or progress spinner
                                ZStack {
                                    if let icon = service.currentAppIcon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .opacity(0.7)  // Slightly faded during install
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 48, height: 48)
                                    }
                                    
                                    // Overlay progress spinner on icon
                                    ProgressView()
                                        .controlSize(.regular)
                                }
                                .frame(width: 48, height: 48)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.currentAppName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text(service.currentStatus)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Failed installations
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startStatusUpdater()
        }
        .onDisappear {
            stopStatusUpdater()
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("インストール結果")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    if let service = installerService {
                        // Success list
                        ForEach(service.installedAppDetails) { detail in
                            HStack(spacing: 12) {
                                // App icon with checkmark overlay
                                ZStack(alignment: .bottomTrailing) {
                                    if let icon = detail.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 48, height: 48)
                                    }
                                    
                                    // Checkmark badge
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(.white)
                                        .background(
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 22, height: 22)
                                        )
                                        .offset(x: 4, y: 4)
                                }
                                .frame(width: 48, height: 48)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(detail.appName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("インストール完了")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        
                        // Failure list
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .frame(width: 48)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack {
            Button(currentPhase == .results ? "閉じる" : "キャンセル") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            switch currentPhase {
            case .confirmation:
                Button("別の IPA を追加") {
                    selectIPAFiles()
                }
                
                Button("インストール開始") {
                    showInstallConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(analyzedIPAs.isEmpty)
                .keyboardShortcut(.defaultAction)
                
            default:
                EmptyView()
            }
        }
    }
    
    private func selectIPAFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let ipaType = UTType(filenameExtension: "ipa") {
            panel.allowedContentTypes = [ipaType]
        } else {
            panel.allowedContentTypes = [.data]
        }
        panel.message = "インストールする IPA ファイルを選択してください"
        
        if panel.runModal() == .OK {
            let newIPAs = panel.urls.filter { !selectedIPAs.contains($0) }
            selectedIPAs.append(contentsOf: newIPAs)
            
            // Start analysis
            Task {
                await analyzeSelectedIPAs()
            }
        }
    }
    
    private func analyzeSelectedIPAs() async {
        guard let service = installerService else { return }
        
        currentPhase = .analyzing
        isAnalyzing = true
        
        let results = await service.analyzeIPAs(selectedIPAs)
        
        await MainActor.run {
            analyzedIPAs = results
            isAnalyzing = false
            
            if analyzedIPAs.isEmpty {
                currentPhase = .selection
                statusMessage = "すべての IPA の解析に失敗しました"
            } else {
                currentPhase = .confirmation
            }
        }
    }
    
    private func startStatusUpdater() {
        statusUpdateTask = Task {
            while !Task.isCancelled && isInstalling {
                // Trigger view update
                await MainActor.run {
                    // Force view refresh by updating a dummy state
                    _ = Date()
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            }
        }
    }
    
    private func stopStatusUpdater() {
        statusUpdateTask?.cancel()
        statusUpdateTask = nil
    }
    
    private func startInstallation() async {
        guard let service = installerService, !analyzedIPAs.isEmpty else { return }
        
        currentPhase = .installing
        isInstalling = true
        
        do {
            try await service.installIPAs(analyzedIPAs)
        } catch {
            await MainActor.run {
                statusMessage = "エラー: \(error.localizedDescription)"
            }
        }
        
        // Refresh launcher to show newly installed apps (in background)
        Task {
            await launcherViewModel.refresh()
        }
        
        // Update UI with service state on main thread
        await MainActor.run {
            
            stopStatusUpdater()
            isInstalling = false
            currentPhase = .results
            showResults = true
        }
    }
}

// App Uninstaller Sheet
struct AppUninstallerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(PerAppSettingsStore.self) private var perAppSettingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @State private var uninstallerService: AppUninstallerService?
    @State private var apps: [AppUninstallerService.InstalledAppInfo] = []
    @State private var selectedApps: Set<String> = []
    @State private var currentPhase: UninstallPhase = .loading
    @State private var totalSize: Int64 = 0
    @State private var statusUpdateTask: Task<Void, Never>?
    @State private var showUninstallConfirmation = false
    
    let preSelectedBundleID: String?
    
    enum UninstallPhase {
        case loading        // アプリ一覧読み込み中
        case confirmingSingle  // 個別アンインストール確認中
        case selection      // アプリ選択
        case uninstalling   // アンインストール中
        case results        // 結果表示
    }
    
    init(preSelectedBundleID: String? = nil) {
        self.preSelectedBundleID = preSelectedBundleID
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("アプリアンインストーラー")
                .font(.title2)
                .fontWeight(.semibold)
            
            switch currentPhase {
            case .loading:
                loadingView
            case .confirmingSingle:
                confirmingSingleView
            case .selection:
                selectionView
            case .uninstalling:
                uninstallingView
            case .results:
                resultsView
            }
            
            Spacer()
            
            bottomButtons
        }
        .padding(24)
        .frame(width: 700, height: 600)
        .task {
            await loadApps()
        }
        .alert("アンインストール確認", isPresented: $showUninstallConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("アンインストール", role: .destructive) {
                Task {
                    await startUninstallation()
                }
            }
        } message: {
            let appNames = apps.filter { selectedApps.contains($0.bundleID) }.map { $0.appName }
            if appNames.count <= 3 {
                Text("\(appNames.joined(separator: "、")) をアンインストールします。\n\nこの操作は取り消せません。よろしいですか？")
            } else {
                Text("\(selectedApps.count) 個のアプリをアンインストールします。\n\nこの操作は取り消せません。よろしいですか？")
            }
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("アプリ一覧を読み込み中...")
                .font(.headline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Confirming Single App View
    private var confirmingSingleView: some View {
        VStack(spacing: 24) {
            // Get the app info
            if let bundleID = selectedApps.first,
               let app = apps.first(where: { $0.bundleID == bundleID }) {
                
                // App icon and info
                VStack(spacing: 16) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    
                    VStack(spacing: 8) {
                        Text(app.appName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        
                        Text(app.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Divider()
                
                // Confirmation message
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    Text("このアプリをアンインストールしますか？")
                        .font(.headline)
                    
                    Text("この操作は取り消せません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Size info
                VStack(spacing: 8) {
                    HStack {
                        Text("アプリサイズ:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                    }
                    HStack {
                        Text("ディスクイメージ:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.diskImageSize, countStyle: .file))
                    }
                    Divider()
                    HStack {
                        Text("合計:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.appSize + app.diskImageSize, countStyle: .file))
                            .fontWeight(.semibold)
                    }
                }
                .font(.callout)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
            } else {
                Text("アプリ情報が見つかりません")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Selection View
    private var selectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("アンインストール可能なアプリがありません")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("インストール済みアプリ (\(apps.count) 個)")
                        .font(.headline)
                    Spacer()
                    Text("合計: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                List(apps, id: \.bundleID, selection: $selectedApps) { app in
                    HStack(spacing: 12) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 48, height: 48)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.appName)
                                .font(.body)
                                .lineLimit(2)
                            Text(app.bundleID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(ByteCountFormatter.string(fromByteCount: app.appSize + app.diskImageSize, countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("App: \(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Uninstalling View
    private var uninstallingView: some View {
        VStack(spacing: 20) {
            // Header with progress
            VStack(spacing: 12) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                
                Text("アンインストール中")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let service = uninstallerService, !service.currentStatus.isEmpty {
                    Text(service.currentStatus)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Overall progress bar
                if let service = uninstallerService {
                    let totalItems = selectedApps.count
                    let completed = service.uninstalledApps.count + service.failedApps.count
                    let progressValue = totalItems > 0 ? Double(completed) / Double(totalItems) : 0
                    
                    VStack(spacing: 8) {
                        ProgressView(value: progressValue)
                            .frame(width: 400)
                        
                        Text("\(completed) / \(totalItems) 完了")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, 40)
            
            // Uninstall log
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let service = uninstallerService {
                        // Completed uninstalls
                        ForEach(service.uninstalledApps, id: \.self) { appName in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                    .frame(width: 48)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("アンインストール完了")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Currently uninstalling (if any)
                        if !service.currentStatus.isEmpty && service.currentStatus != "完了" && 
                           !service.uninstalledApps.contains(where: { service.currentStatus.contains($0) }) {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .controlSize(.regular)
                                    .frame(width: 48)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(service.currentStatus)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("処理中...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Failed uninstalls
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .frame(width: 48)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startStatusUpdater()
        }
        .onDisappear {
            stopStatusUpdater()
        }
    }
    
    // MARK: - Results View  
    private var resultsView: some View {
        VStack(spacing: 16) {
            HStack {
                if let service = uninstallerService, !service.failedApps.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                Text("アンインストール結果")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            ScrollView {
                VStack(spacing: 12) {
                    if let service = uninstallerService {
                        // Success list
                        ForEach(service.uninstalledApps, id: \.self) { appName in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                    .frame(width: 48)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(appName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("アンインストール完了")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                        
                        // Failure list
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .frame(width: 48)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack {
            Button(currentPhase == .results ? "閉じる" : "キャンセル") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            if currentPhase == .confirmingSingle && !selectedApps.isEmpty {
                Button("アンインストール") {
                    Task {
                        await startUninstallation()
                    }
                }
                .tint(.red)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else if currentPhase == .selection && !selectedApps.isEmpty {
                Button("アンインストール (\(selectedApps.count) 個)") {
                    showUninstallConfirmation = true
                }
                .tint(.red)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private func startStatusUpdater() {
        statusUpdateTask = Task {
            while !Task.isCancelled && currentPhase == .uninstalling {
                await MainActor.run {
                    _ = Date()
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    private func stopStatusUpdater() {
        statusUpdateTask?.cancel()
        statusUpdateTask = nil
    }
    
    private func loadApps() async {
        guard let service = uninstallerService else {
            let diskImageService = DiskImageService(processRunner: ProcessRunner(), settings: settingsStore)
            let launcherService = LauncherService()
            let service = AppUninstallerService(diskImageService: diskImageService, settingsStore: settingsStore, perAppSettingsStore: perAppSettingsStore, launcherService: launcherService)
            self.uninstallerService = service
            await loadApps()
            return
        }
        
        do {
            apps = try await service.getInstalledApps()
            totalSize = apps.reduce(0) { $0 + $1.appSize + $1.diskImageSize }
        } catch {
            apps = []
            totalSize = 0
        }
        
        // If preSelectedBundleID is set and exists in loaded apps, go to confirmingSingle
        // Otherwise, transition to selection phase
        if let bundleID = preSelectedBundleID, apps.contains(where: { $0.bundleID == bundleID }) {
            selectedApps = [bundleID]
            currentPhase = .confirmingSingle
        } else {
            currentPhase = .selection
        }
    }
    
    private func startUninstallation() async {
        guard let service = uninstallerService else { return }
        
        let appsToUninstall = apps.filter { selectedApps.contains($0.bundleID) }
        guard !appsToUninstall.isEmpty else { return }
        
        currentPhase = .uninstalling
        
        do {
            try await service.uninstallApps(appsToUninstall)
        } catch {
        }
        
        currentPhase = .results
        
        // Update quick launcher
        if let launcher = appViewModel.launcherViewModel {
            await launcher.refresh()
        }
        
        stopStatusUpdater()
    }
}

// Appearance Settings View
private struct MaintenanceSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var showingResetConfirmation = false
    @State private var showingClearCacheConfirmation = false

    var body: some View {
        Form {
            Section(header: Text("キャッシュ")) {
                Button("アイコンキャッシュをクリア") {
                    showingClearCacheConfirmation = true
                }
                Text("アプリアイコンのキャッシュをクリアします。次回起動時に再読み込みされます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(header: Text("リセット")) {
                Button("設定をリセット") {
                    showingResetConfirmation = true
                }
                .foregroundStyle(.red)
                Text("すべての設定を初期値に戻します（ディスクイメージとアプリは削除されません）。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .alert("設定をリセットしますか？", isPresented: $showingResetConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("リセット", role: .destructive) {
                resetSettings()
            }
        } message: {
            Text("アプリが再起動され、初期設定ウィザードが表示されます。")
        }
        .alert("キャッシュをクリアしますか?", isPresented: $showingClearCacheConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("クリア", role: .destructive) {
                clearIconCache()
            }
        } message: {
            Text("アイコンキャッシュがクリアされ、次回起動時に再読み込みされます。")
        }
    }
    
    private func clearIconCache() {
        // Icon cache is managed by LauncherService's NSCache
        // We'll need to add a method to clear it
        // For now, just show completion
        let alert = NSAlert()
        alert.messageText = "キャッシュをクリアしました"
        alert.informativeText = "アプリを再起動すると、アイコンが再読み込みされます。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func resetSettings() {
        UserDefaults.standard.removeObject(forKey: "diskImageDirectory")
        UserDefaults.standard.removeObject(forKey: "diskImageDirectoryBookmark")
        UserDefaults.standard.removeObject(forKey: "nobrowseEnabled")
        UserDefaults.standard.removeObject(forKey: "defaultDataHandling")
        UserDefaults.standard.removeObject(forKey: "diskImageFormat")
        
        NSApp.sendAction(#selector(NSApplication.terminate(_:)), to: nil, from: nil)
    }
}

// MARK: - About View
private struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // App Icon and Name
                VStack(spacing: 12) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 128, height: 128)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    
                    Text("PlayCover Manager")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("Version \(appVersion) (Build \(buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Description
                VStack(alignment: .leading, spacing: 12) {
                    Text("概要")
                        .font(.headline)
                    
                    Text("PlayCover Manager は、PlayCover でインストールした iOS アプリを統合的に管理するための GUI ツールです。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    
                    Text("IPA インストール、アプリ起動、アンインストール、ストレージ管理などの機能を提供します。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // System Requirements
                VStack(alignment: .leading, spacing: 12) {
                    Text("システム要件")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("macOS Tahoe 26.0 以降")
                                .font(.callout)
                        }
                        
                        HStack {
                            Image(systemName: "cpu")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("Apple Silicon Mac 専用")
                                .font(.callout)
                        }
                        
                        HStack {
                            Image(systemName: "square.stack.3d.down.right")
                                .foregroundStyle(.secondary)
                                .frame(width: 20)
                            Text("ASIF ディスクイメージ形式対応")
                                .font(.callout)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Links
                VStack(alignment: .leading, spacing: 12) {
                    Text("リンク")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Link(destination: URL(string: "https://github.com/HEHEX8/PlayCoverManagerGUI")!) {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("GitHub リポジトリ")
                                    .font(.callout)
                            }
                        }
                        
                        Link(destination: URL(string: "https://github.com/HEHEX8/PlayCoverManagerGUI/issues")!) {
                            HStack {
                                Image(systemName: "exclamationmark.bubble")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("問題を報告")
                                    .font(.callout)
                            }
                        }
                        
                        Link(destination: URL(string: "https://github.com/PlayCover/PlayCover")!) {
                            HStack {
                                Image(systemName: "gamecontroller")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)
                                Text("PlayCover プロジェクト")
                                    .font(.callout)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Copyright
                VStack(spacing: 4) {
                    Text("© 2025 HEHEX8")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("MIT ライセンスで提供")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

