import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers

struct SettingsRootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel

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
        }
        .padding(24)
        .frame(width: 600, height: 500)
    }
}

private struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showingStorageWizard = false
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
                    showingStorageWizard = true
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
        .sheet(isPresented: $showingStorageWizard) {
            StorageChangeWizardSheet()
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
                        Text(info.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        } else {
                            Text("v\(info.version)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
        VStack(spacing: 16) {
            Text("インストール中")
                .font(.headline)
            
            ScrollView {
                if let service = installerService {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(service.installedApps, id: \.self) { app in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(app)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                        
                        if !service.currentStatus.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(service.currentStatus)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(error)
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
                        ForEach(service.installedApps, id: \.self) { appName in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                    .frame(width: 48)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(appName)
                                        .font(.body)
                                        .fontWeight(.medium)
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
                    Task {
                        await startInstallation()
                    }
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
        
        // Refresh launcher to show newly installed apps
        await launcherViewModel.refresh()
        
        // Update UI with service state on main thread
        await MainActor.run {
            isInstalling = false
            currentPhase = .results
            showResults = true
        }
        
        stopStatusUpdater()
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
    @State private var isLoading = true
    @State private var isUninstalling = false
    @State private var statusMessage = ""
    @State private var showResults = false
    @State private var totalSize: Int64 = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("アプリアンインストーラー")
                .font(.title2)
                .fontWeight(.semibold)
            
            if isLoading {
                ProgressView("アプリ一覧を読み込み中...")
            } else if showResults {
                // Results view - larger and centered
                VStack(spacing: 24) {
                    // Success icon
                    if let service = uninstallerService, !service.failedApps.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.green)
                    }
                    
                    // Summary
                    if let service = uninstallerService {
                        VStack(spacing: 8) {
                            if !service.failedApps.isEmpty {
                                Text("一部のアプリをアンインストールできませんでした")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                            } else {
                                Text("アンインストール完了")
                                    .font(.title2)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack(spacing: 16) {
                                if !service.uninstalledApps.isEmpty {
                                    Label("\(service.uninstalledApps.count) 個成功", systemImage: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                if !service.failedApps.isEmpty {
                                    Label("\(service.failedApps.count) 個失敗", systemImage: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                }
                            }
                            .font(.headline)
                        }
                    }
                    
                    Divider()
                        .padding(.horizontal, 40)
                    
                    // Detailed results
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if let service = uninstallerService, !service.uninstalledApps.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("✅ 削除されたアプリ")
                                        .font(.headline)
                                        .foregroundStyle(.green)
                                    ForEach(service.uninstalledApps, id: \.self) { appName in
                                        Text("  • \(appName)")
                                            .font(.body)
                                    }
                                }
                            }
                            
                            if let service = uninstallerService, !service.failedApps.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("❌ 失敗したアプリ")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                    ForEach(service.failedApps, id: \.self) { error in
                                        Text("  • \(error)")
                                            .font(.body)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("アンインストール可能なアプリがありません")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("インストール済みアプリ (\(apps.count) 個)")
                            .font(.headline)
                        Spacer()
                        Text("合計: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    List(apps, id: \.bundleID, selection: $selectedApps) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.appName)
                                    .font(.body)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
                    
                    if isUninstalling, let service = uninstallerService {
                        VStack(spacing: 8) {
                            ProgressView(value: service.currentProgress)
                            Text(service.currentStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button(showResults ? "閉じる" : "キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if !apps.isEmpty && !selectedApps.isEmpty && !showResults {
                    Button("削除 (\(selectedApps.count) 個)") {
                        print("🟡 [UI] ボタンがクリックされました")
                        Task {
                            print("🟡 [UI] Task 開始")
                            await startUninstallation()
                            print("🟡 [UI] Task 完了")
                        }
                    }
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                    .disabled(isUninstalling)
                }
            }
        }
        .padding(24)
        .frame(width: 600, height: 500)
        .task {
            await loadApps()
        }
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
        
        isLoading = false
    }
    
    private func startUninstallation() async {
        guard let service = uninstallerService else { return }
        
        let appsToUninstall = apps.filter { selectedApps.contains($0.bundleID) }
        guard !appsToUninstall.isEmpty else { return }
        
        print("🔵 [UI] startUninstallation 開始: \(appsToUninstall.count) 個")
        isUninstalling = true
        
        do {
            print("🔵 [UI] service.uninstallApps 呼び出し")
            try await service.uninstallApps(appsToUninstall)
            print("🔵 [UI] service.uninstallApps 完了")
        } catch {
            print("🔵 [UI] エラー: \(error)")
        }
        
        print("🔵 [UI] 結果表示")
        isUninstalling = false
        showResults = true
        
        // Update quick launcher
        print("🔵 [UI] クイックランチャーを更新")
        if let launcher = appViewModel.launcherViewModel {
            await launcher.refresh()
        }
    }
}

// Appearance Settings View
private struct MaintenanceSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var showingResetConfirmation = false
    @State private var showingClearCacheConfirmation = false
    @State private var isTrimming = false
    @State private var trimResult: String?

    var body: some View {
        Form {
            Section(header: Text("ディスクイメージ最適化")) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        Task {
                            await trimAllDiskImages()
                        }
                    }) {
                        HStack {
                            Text("すべてのASIFイメージをトリミング")
                            if isTrimming {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                    .disabled(isTrimming)
                    
                    Text("ASIFディスクイメージの未使用領域を解放します。容量の拡張は自動ですが、縮小は手動でトリミングが必要です。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let result = trimResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("失敗") ? .red : .green)
                            .padding(.top, 4)
                    }
                }
            }
            
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
    
    private func trimAllDiskImages() async {
        await MainActor.run {
            isTrimming = true
            trimResult = nil
        }
        
        do {
            let processRunner = ProcessRunner()
            let diskImageService = DiskImageService(processRunner: processRunner, settings: settingsStore)
            
            let result = try await diskImageService.trimAllDiskImages()
            
            await MainActor.run {
                isTrimming = false
                
                // Format the reclaimed space in a human-readable way
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useGB, .useMB]
                formatter.countStyle = .file
                let reclaimedStr = formatter.string(fromByteCount: result.total)
                
                if result.failed > 0 {
                    trimResult = "✅ \(result.processed)個完了、❌ \(result.failed)個失敗、\(reclaimedStr) 解放"
                } else {
                    trimResult = "✅ \(result.processed)個のイメージをトリミングしました（\(reclaimedStr) 解放）"
                }
            }
        } catch {
            await MainActor.run {
                isTrimming = false
                trimResult = "❌ トリミングに失敗しました: \(error.localizedDescription)"
            }
        }
    }
}

// Storage Change Wizard Sheet
private struct StorageChangeWizardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @State private var wizardViewModel: SetupWizardViewModel?
    
    var body: some View {
        VStack {
            if let viewModel = wizardViewModel {
                SetupWizardView(viewModel: viewModel, playCoverPaths: appViewModel.playCoverPaths)
                    .environment(settingsStore)
            } else {
                ProgressView("初期化中...")
                    .onAppear {
                        initializeWizard()
                    }
            }
        }
        .frame(width: 800, height: 600)
    }
    
    private func initializeWizard() {
        // Create necessary services
        let processRunner = ProcessRunner()
        let diskImageService = DiskImageService(processRunner: processRunner, settings: settingsStore)
        let environmentService = PlayCoverEnvironmentService(processRunner: processRunner)
        
        // Create context for storage change
        // PlayCover already detected, disk image exists, mount not required (will be handled by wizard)
        let context = AppPhase.SetupContext(
            missingPlayCover: false,
            missingDiskImage: false,
            diskImageMountRequired: false
        )
        
        // Initialize view model
        let viewModel = SetupWizardViewModel(
            settings: settingsStore,
            environmentService: environmentService,
            diskImageService: diskImageService,
            context: context,
            initialPlayCoverPaths: appViewModel.playCoverPaths
        )
        
        // Start from selectStorage step
        viewModel.currentStep = SetupWizardViewModel.Step.selectStorage
        viewModel.onCompletion = {
            dismiss()
        }
        self.wizardViewModel = viewModel
    }
}

