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
                .help(String(localized: "設定を閉じる (Esc)"))
            }
            
            ToolbarSpacer()
            
            ToolbarItem(placement: .automatic) {
                Text("PlayCover Manager 設定")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
}

private struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var calculatingSize = false
    @State private var totalDiskUsage: Int64 = 0
    @State private var showLanguageChangeAlert = false
    @State private var previousLanguage: SettingsStore.AppLanguage

    init() {
        // Initialize with current language
        let store = SettingsStore()
        _previousLanguage = State(initialValue: store.appLanguage)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Storage Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("ストレージ", systemImage: "externaldrive.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Storage path display
                        VStack(alignment: .leading, spacing: 8) {
                            Text("保存先")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            HStack {
                                Text(settingsStore.diskImageDirectory?.path ?? "未設定")
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                    .truncationMode(.middle)
                                Spacer()
                                if calculatingSize {
                                    ProgressView()
                                        .controlSize(.small)
                                } else if totalDiskUsage > 0 {
                                    Text(ByteCountFormatter.string(fromByteCount: totalDiskUsage, countStyle: .file))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                                }
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Button {
                            dismiss()
                            appViewModel.requestStorageLocationChange()
                        } label: {
                            Label("保存先を変更", systemImage: "folder.badge.gearshape")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .help(String(localized: "すべてのコンテナをアンマウントしてから保存先を変更します"))
                        
                        Text("保存先を変更すると、マウント中のコンテナをすべてアンマウントしてから新しい保存先に環境を構築します。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        // Gradient glow
                        LinearGradient(
                            colors: [.blue.opacity(0.06), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .blur(radius: 20)
                        
                        // Main glass
                        RoundedRectangle(cornerRadius: 12)
                            .glassEffect(.regular.tint(.blue.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12))
                    }
                )
                .overlay {
                    // Shine effect
                    LinearGradient(
                        colors: [.white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .shadow(color: .blue.opacity(0.15), radius: 12, x: 0, y: 4)
                
                // Mount Settings Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("マウント設定", systemImage: "internaldrive")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: Binding(get: { settingsStore.nobrowseEnabled }, set: { settingsStore.nobrowseEnabled = $0 })) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Finder に表示しない (-nobrowse)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("有効にすると、マウントされたディスクイメージが Finder のサイドバーに表示されなくなります。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        LinearGradient(colors: [.purple.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 20)
                        RoundedRectangle(cornerRadius: 12).glassEffect(.regular.tint(.purple.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12))
                    }
                )
                .overlay { LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 12)) }
                .shadow(color: .purple.opacity(0.15), radius: 12, x: 0, y: 4)
                

                // Language Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("言語", systemImage: "globe")
                        .font(.headline)
                        .foregroundStyle(.green)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("アプリの言語")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: Binding(
                                get: { settingsStore.appLanguage },
                                set: { newValue in
                                    if newValue != previousLanguage {
                                        settingsStore.appLanguage = newValue
                                        showLanguageChangeAlert = true
                                    }
                                }
                            )) {
                                ForEach(SettingsStore.AppLanguage.allCases) { language in
                                    Text(language.localizedDescription).tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        Text("言語を変更すると、アプリを再起動する必要があります。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        LinearGradient(colors: [.green.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 20)
                        RoundedRectangle(cornerRadius: 12).glassEffect(.regular.tint(.green.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12))
                    }
                )
                .overlay { LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 12)) }
                .shadow(color: .green.opacity(0.15), radius: 12, x: 0, y: 4)
            }
            .padding(20)
        }
        .onAppear {
            previousLanguage = settingsStore.appLanguage
            Task {
                await calculateDiskUsage()
            }
        }
        .keyboardNavigableAlert(
            isPresented: $showLanguageChangeAlert,
            title: String(localized: "言語を変更しました"),
            message: String(localized: "言語の変更を完全に反映するには、アプリを再起動する必要があります。"),
            buttons: [
                AlertButton("後で再起動", role: .cancel, style: .bordered, keyEquivalent: .cancel) {
                    previousLanguage = settingsStore.appLanguage
                    showLanguageChangeAlert = false
                },
                AlertButton("今すぐ再起動", style: .borderedProminent, keyEquivalent: .default) {
                    restartApp()
                }
            ],
            icon: .info
        )
    }
    
    private func restartApp() {
        let bundlePath = Bundle.main.bundlePath
        
        // Use shell script to wait and relaunch
        // This approach bypasses AppDelegate termination flow
        let script = """
        sleep 0.3
        open "\(bundlePath)"
        """
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]
        
        do {
            try task.run()
            // Use Darwin.exit to bypass AppDelegate
            Darwin.exit(0)
        } catch {
            Logger.error("Failed to restart: \(error)")
            // Fallback to normal termination
            NSApplication.shared.terminate(nil)
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
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Internal Data Handling Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("内部データ処理の既定値", systemImage: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("既定の処理")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: Binding<SettingsStore.InternalDataStrategy>(
                                get: { settingsStore.defaultDataHandling },
                                set: { settingsStore.defaultDataHandling = $0 }
                            )) {
                                ForEach(SettingsStore.InternalDataStrategy.allCases) { strategy in
                                    Text(strategy.localizedDescription).tag(strategy)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        // Description with info icon
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("説明")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Text("アプリのコンテナに内部データが残っていた場合のデフォルト処理です。ランチャーから起動する際に変更できます。")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        LinearGradient(colors: [.orange.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 20)
                        RoundedRectangle(cornerRadius: 12).glassEffect(.regular.tint(.orange.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12))
                    }
                )
                .overlay { LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 12)) }
                .shadow(color: .orange.opacity(0.15), radius: 12, x: 0, y: 4)
                
                Spacer()
            }
            .padding(20)
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
        VStack(spacing: 16) {
            Text("IPA インストーラー")
                .font(.title3)
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
        .padding(20)
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
        VStack(spacing: 24) {
            // Single or multiple app confirmation
            if analyzedIPAs.count == 1, let info = analyzedIPAs.first {
                // Single app confirmation
                VStack(spacing: 16) {
                    // App icon
                    if let icon = info.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                    }
                    
                    VStack(spacing: 8) {
                        Text(info.appName)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        
                        Text(info.bundleID)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Divider()
                
                // Install type indicator
                VStack(spacing: 12) {
                    installTypeIndicator(for: info)
                    
                    Text(installTypeMessage(for: info))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Details
                VStack(spacing: 8) {
                    HStack {
                        Text("バージョン(ラベル)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let existing = info.existingVersion {
                            Text("\(existing) → \(info.version)")
                                .fontWeight(.medium)
                        } else {
                            Text(info.version)
                                .fontWeight(.medium)
                        }
                    }
                    HStack {
                        Text("ファイルサイズ(ラベル)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: info.fileSize, countStyle: .file))
                    }
                }
                .font(.callout)
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
            } else if analyzedIPAs.count > 1 {
                // Multiple apps confirmation with expanded list view
                VStack(spacing: 0) {
                    // Compact header with summary
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.blue)
                            
                            Text("\(analyzedIPAs.count) 個のアプリをインストールしますか？")
                                .font(.headline)
                            
                            Spacer()
                        }
                        
                        // Summary badges in compact layout
                        let newInstalls = analyzedIPAs.filter { $0.installType == .newInstall }.count
                        let upgrades = analyzedIPAs.filter { $0.installType == .upgrade }.count
                        let others = analyzedIPAs.count - newInstalls - upgrades
                        let totalSize = analyzedIPAs.reduce(0) { $0 + $1.fileSize }
                        
                        HStack(spacing: 10) {
                            if newInstalls > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                    Text("\(newInstalls)")
                                }
                                .font(.caption)
                                .foregroundStyle(.blue)
                            }
                            if upgrades > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.caption2)
                                    Text("\(upgrades)")
                                }
                                .font(.caption)
                                .foregroundStyle(.green)
                            }
                            if others > 0 {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.caption2)
                                    Text("\(others)")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            
                            Text("・")
                                .foregroundStyle(.tertiary)
                                .font(.caption)
                            
                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                    }
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Expanded scrollable list of apps with optimized spacing
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(analyzedIPAs) { info in
                                HStack(spacing: 10) {
                                    // App icon (slightly smaller)
                                    if let icon = info.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 42, height: 42)
                                            .clipShape(RoundedRectangle(cornerRadius: 9))
                                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                                    } else {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 42, height: 42)
                                            .overlay {
                                                Image(systemName: "app.dashed")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                    }
                                    
                                    // App info (compact layout)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(info.appName)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 6) {
                                            // Install type badge
                                            Group {
                                                switch info.installType {
                                                case .newInstall:
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "sparkles")
                                                        Text("新規")
                                                    }
                                                    .foregroundStyle(.blue)
                                                case .upgrade:
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "arrow.up.circle.fill")
                                                        Text("更新")
                                                    }
                                                    .foregroundStyle(.green)
                                                case .downgrade:
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "arrow.down.circle.fill")
                                                        Text("ダウン")
                                                    }
                                                    .foregroundStyle(.orange)
                                                case .reinstall:
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "arrow.clockwise.circle.fill")
                                                        Text("上書き")
                                                    }
                                                    .foregroundStyle(.secondary)
                                                }
                                            }
                                            .font(.caption2)
                                            
                                            Text("・")
                                                .foregroundStyle(.tertiary)
                                                .font(.caption2)
                                            
                                            Text(ByteCountFormatter.string(fromByteCount: info.fileSize, countStyle: .file))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Remove from list button (compact)
                                    Button {
                                        removeIPAFromList(info)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("リストから外す")
                                }
                                .padding(10)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.top, 8)
                    }
                }
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
                
                // Overall progress bar (indeterminate animation)
                if let service = installerService {
                    let totalItems = analyzedIPAs.count
                    let completed = service.installedApps.count + service.failedApps.count
                    
                    VStack(spacing: 8) {
                        // Indeterminate progress bar (animated)
                        ProgressView()
                            .progressViewStyle(.linear)
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
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func installTypeIndicator(for info: IPAInstallerService.IPAInfo) -> some View {
        HStack(spacing: 8) {
            switch info.installType {
            case .newInstall:
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
                Text("新規インストール")
                    .font(.headline)
                    .foregroundStyle(.blue)
            case .upgrade:
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.green)
                Text("アップグレード")
                    .font(.headline)
                    .foregroundStyle(.green)
            case .downgrade:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)
                Text("ダウングレード")
                    .font(.headline)
                    .foregroundStyle(.orange)
            case .reinstall:
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.secondary)
                Text("再インストール")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func installTypeMessage(for info: IPAInstallerService.IPAInfo) -> String {
        switch info.installType {
        case .newInstall:
            return String(localized: "このアプリを新しくインストールします。")
        case .upgrade:
            return String(localized: "既存のアプリを新しいバージョンにアップグレードします。")
        case .downgrade:
            return String(localized: "既存のアプリを古いバージョンにダウングレードします。")
        case .reinstall:
            return String(localized: "同じバージョンで上書きインストールします。")
        }
    }
    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack {
            // Hide cancel button during installation - too complex to safely cancel
            if currentPhase != .installing && currentPhase != .analyzing {
                Button(currentPhase == .results ? "閉じる" : "キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            
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
        panel.message = String(localized: "インストールする IPA ファイルを選択してください")
        
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
                statusMessage = String(localized: "すべての IPA の解析に失敗しました")
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
    
    private func removeIPAFromList(_ info: IPAInstallerService.IPAInfo) {
        // Remove from analyzed list
        analyzedIPAs.removeAll { $0.id == info.id }
        
        // Remove from selected URLs
        selectedIPAs.removeAll { $0 == info.ipaURL }
        
        // If no IPAs left, go back to selection
        if analyzedIPAs.isEmpty {
            currentPhase = .selection
        }
    }
    
    private func startInstallation() async {
        guard let service = installerService, !analyzedIPAs.isEmpty else { return }
        
        // Mark as critical operation to prevent app termination
        CriticalOperationService.shared.beginOperation("IPA インストール")
        
        currentPhase = .installing
        isInstalling = true
        
        // Ensure results screen is always shown, even if unexpected error occurs
        defer {
            stopStatusUpdater()
            isInstalling = false
            currentPhase = .results
            showResults = true
            
            // End critical operation
            CriticalOperationService.shared.endOperation()
            
            // Refresh launcher to show newly installed apps (in background)
            Task {
                await launcherViewModel.refresh()
            }
        }
        
        do {
            try await service.installIPAs(analyzedIPAs)
        } catch {
            await MainActor.run {
                statusMessage = String(localized: "エラー: \(error.localizedDescription)")
                // Record fatal error in failedApps if not already recorded
                if service.failedApps.isEmpty && service.installedApps.isEmpty {
                    service.failedApps.append(String(localized: "致命的なエラー: \(error.localizedDescription)"))
                }
            }
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
    
    let preSelectedBundleID: String?
    
    enum UninstallPhase {
        case loading        // アプリ一覧読み込み中
        case confirmingSingle  // 個別アンインストール確認中
        case confirmingMultiple  // 複数アンインストール確認中
        case selection      // アプリ選択
        case uninstalling   // アンインストール中
        case results        // 結果表示
    }
    
    init(preSelectedBundleID: String? = nil) {
        self.preSelectedBundleID = preSelectedBundleID
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("アプリアンインストーラー")
                .font(.title3)
                .fontWeight(.semibold)
            
            switch currentPhase {
            case .loading:
                loadingView
            case .confirmingSingle, .confirmingMultiple:
                confirmingView
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
        .padding(20)
        .frame(width: 700, height: 600)
        .onAppear {
            Task {
                await loadApps()
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
    
    // MARK: - Confirming View (Single or Multiple)
    private var confirmingView: some View {
        VStack(spacing: 16) {
            let selectedAppInfos = apps.filter { selectedApps.contains($0.bundleID) }
            
            if selectedAppInfos.count == 1, let app = selectedAppInfos.first {
                // Single app confirmation
                
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
                        Text("ディスクイメージ(ラベル)")
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
                
            } else if selectedAppInfos.count > 1 {
                // Multiple apps confirmation with compact list
                VStack(spacing: 10) {
                    Text("\(selectedAppInfos.count) 個のアプリ")
                        .font(.headline)
                    
                    // Scrollable list of selected apps with optimized spacing
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(selectedAppInfos, id: \.bundleID) { app in
                                HStack(spacing: 10) {
                                    // App icon (slightly smaller)
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 42, height: 42)
                                            .clipShape(RoundedRectangle(cornerRadius: 9))
                                            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                                    } else {
                                        RoundedRectangle(cornerRadius: 9)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 42, height: 42)
                                            .overlay {
                                                Image(systemName: "app.dashed")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                    }
                                    
                                    // App info (compact layout)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(app.appName)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 4) {
                                            Text("アプリ:")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            
                                            Text("・")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            
                                            Text("イメージ:")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                            Text(ByteCountFormatter.string(fromByteCount: app.diskImageSize, countStyle: .file))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Remove from selection button (compact)
                                    Button {
                                        removeAppFromSelection(app.bundleID)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("選択を解除")
                                }
                                .padding(10)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                }
                
                Divider()
                
                // Confirmation message
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    
                    Text("\(selectedAppInfos.count) 個のアプリをアンインストールしますか？")
                        .font(.headline)
                    
                    Text("この操作は取り消せません。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Size info
                let totalAppSize = selectedAppInfos.reduce(0) { $0 + $1.appSize }
                let totalDiskImageSize = selectedAppInfos.reduce(0) { $0 + $1.diskImageSize }
                let totalSelectedSize = totalAppSize + totalDiskImageSize
                
                VStack(spacing: 8) {
                    HStack {
                        Text("アプリサイズ:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalAppSize, countStyle: .file))
                    }
                    HStack {
                        Text("ディスクイメージ(ラベル)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalDiskImageSize, countStyle: .file))
                    }
                    Divider()
                    HStack {
                        Text("合計:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
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
                        if !service.currentStatus.isEmpty && service.currentStatus != String(localized: "完了") && 
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
            if currentPhase == .confirmingMultiple {
                Button("戻る") {
                    currentPhase = .selection
                }
                .keyboardShortcut(.cancelAction)
            } else if currentPhase != .uninstalling {
                // Hide cancel button during uninstallation
                Button(currentPhase == .results ? "閉じる" : "キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            
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
            } else if currentPhase == .confirmingMultiple && !selectedApps.isEmpty {
                Button("アンインストール (\(selectedApps.count) 個)") {
                    Task {
                        await startUninstallation()
                    }
                }
                .tint(.red)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else if currentPhase == .selection && !selectedApps.isEmpty {
                Button("次へ") {
                    currentPhase = .confirmingMultiple
                }
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
    
    private func removeAppFromSelection(_ bundleID: String) {
        // Remove from selection
        selectedApps.remove(bundleID)
        
        // If no apps left selected, go back to selection screen
        if selectedApps.isEmpty {
            currentPhase = .selection
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
        
        // Mark as critical operation to prevent app termination
        CriticalOperationService.shared.beginOperation("アプリのアンインストール")
        
        currentPhase = .uninstalling
        
        // Ensure results screen is always shown, even if error occurs
        defer {
            currentPhase = .results
            stopStatusUpdater()
            
            // End critical operation
            CriticalOperationService.shared.endOperation()
            
            // Update quick launcher
            Task {
                if let launcher = appViewModel.launcherViewModel {
                    await launcher.refresh()
                }
            }
        }
        
        do {
            try await service.uninstallApps(appsToUninstall)
        } catch {
            // Error is already recorded in service.failedApps
        }
    }
}

// Appearance Settings View
private struct MaintenanceSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var showingResetConfirmation = false
    @State private var showingClearCacheConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Cache Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("キャッシュ", systemImage: "folder.badge.minus")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            showingClearCacheConfirmation = true
                        } label: {
                            Label("アイコンキャッシュをクリア", systemImage: "trash")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        
                        Text("アプリアイコンのキャッシュをクリアします。次回起動時に再読み込みされます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        LinearGradient(colors: [.blue.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 20)
                        RoundedRectangle(cornerRadius: 12).glassEffect(.regular.tint(.blue.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12))
                    }
                )
                .overlay { LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 12)) }
                .shadow(color: .blue.opacity(0.15), radius: 12, x: 0, y: 4)
                
                // PlayCover Shortcuts Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("PlayCover ショートカット", systemImage: "folder.badge.questionmark")
                        .font(.headline)
                        .foregroundStyle(.orange)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            removePlayCoverShortcuts()
                        } label: {
                            Label("~/Applications/PlayCover を削除", systemImage: "trash")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                        
                        Text("PlayCover が作成する不要なショートカットを削除します。PlayCover.app 起動時に再作成されます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        LinearGradient(colors: [.orange.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 20)
                        RoundedRectangle(cornerRadius: 12).glassEffect(.regular.tint(.orange.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12))
                    }
                )
                .overlay { LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 12)) }
                .shadow(color: .orange.opacity(0.15), radius: 12, x: 0, y: 4)
                
                // Reset Card
                VStack(alignment: .leading, spacing: 16) {
                    Label("リセット", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            showingResetConfirmation = true
                        } label: {
                            Label("設定をリセット", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Text("すべての設定を初期値に戻します（ディスクイメージとアプリは削除されません）。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                .background(
                    ZStack {
                        LinearGradient(colors: [.red.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 20)
                        RoundedRectangle(cornerRadius: 12).glassEffect(.regular.tint(.red.opacity(0.12)), in: RoundedRectangle(cornerRadius: 12))
                    }
                )
                .overlay { LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 12)) }
                .shadow(color: .red.opacity(0.15), radius: 12, x: 0, y: 4)
                
                Spacer()
            }
            .padding(20)
        }
        .keyboardNavigableAlert(
            isPresented: $showingResetConfirmation,
            title: String(localized: "設定をリセットしますか？"),
            message: String(localized: "アプリが再起動され、初期設定ウィザードが表示されます。"),
            buttons: [
                AlertButton("キャンセル", role: .cancel, style: .bordered, keyEquivalent: .cancel) {
                    showingResetConfirmation = false
                },
                AlertButton("リセット", role: .destructive, style: .destructive, keyEquivalent: .default) {
                    resetSettings()
                }
            ],
            icon: .warning
        )
        .keyboardNavigableAlert(
            isPresented: $showingClearCacheConfirmation,
            title: String(localized: "キャッシュをクリアしますか?"),
            message: String(localized: "アイコンキャッシュがクリアされ、次回起動時に再読み込みされます。"),
            buttons: [
                AlertButton("キャンセル", role: .cancel, style: .bordered, keyEquivalent: .cancel) {
                    showingClearCacheConfirmation = false
                },
                AlertButton("クリア", role: .destructive, style: .destructive, keyEquivalent: .default) {
                    clearIconCache()
                }
            ],
            icon: .warning
        )
    }
    
    private func clearIconCache() {
        // Icon cache is managed by LauncherService's NSCache
        // We'll need to add a method to clear it
        // For now, just show completion
        let alert = NSAlert()
        alert.messageText = String(localized: "キャッシュをクリアしました")
        alert.informativeText = String(localized: "アプリを再起動すると、アイコンが再読み込みされます。")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func removePlayCoverShortcuts() {
        let playCoverShortcutsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Applications/PlayCover", isDirectory: true)
        
        let alert = NSAlert()
        
        if FileManager.default.fileExists(atPath: playCoverShortcutsDir.path) {
            do {
                try FileManager.default.removeItem(at: playCoverShortcutsDir)
                Logger.debug("Removed PlayCover shortcuts directory: \(playCoverShortcutsDir.path)")
                
                alert.messageText = String(localized: "削除完了")
                alert.informativeText = String(localized: "~/Applications/PlayCover を削除しました。")
                alert.alertStyle = .informational
            } catch {
                Logger.error("Failed to remove PlayCover shortcuts: \(error)")
                
                alert.messageText = String(localized: "削除失敗")
                alert.informativeText = String(localized: "エラー: \(error.localizedDescription)")
                alert.alertStyle = .warning
            }
        } else {
            alert.messageText = String(localized: "ディレクトリが存在しません")
            alert.informativeText = String(localized: "~/Applications/PlayCover は既に削除されています。")
            alert.alertStyle = .informational
        }
        
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
            VStack(spacing: 20) {
                // App Icon and Name Card
                VStack(spacing: 16) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    
                    VStack(spacing: 6) {
                        Text("PlayCover Manager")
                            .font(.title.bold())
                        
                        Text("Version \(appVersion) (Build \(buildNumber))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                // Description Card
                VStack(alignment: .leading, spacing: 12) {
                    Label("概要", systemImage: "info.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    Divider()
                    
                    Text("PlayCover Manager は、PlayCover でインストールした iOS アプリを統合的に管理するための GUI ツールです。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("IPA インストール、アプリ起動、アンインストール、ストレージ管理などの機能を提供します。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                // System Requirements Card
                VStack(alignment: .leading, spacing: 12) {
                    Label("システム要件", systemImage: "checkmark.shield.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10) {
                        RequirementRow(icon: "desktopcomputer", text: String(localized: "macOS Tahoe 26.0 以降"))
                        RequirementRow(icon: "cpu", text: String(localized: "Apple Silicon Mac 専用"))
                        RequirementRow(icon: "square.stack.3d.down.right", text: String(localized: "ASIF ディスクイメージ形式対応"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                // Links Card
                VStack(alignment: .leading, spacing: 12) {
                    Label("リンク", systemImage: "link.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.purple)
                    
                    Divider()
                    
                    VStack(spacing: 8) {
                        LinkButton(icon: "link", text: String(localized: "GitHub リポジトリ"), url: "https://github.com/HEHEX8/PlayCoverManagerGUI")
                        LinkButton(icon: "exclamationmark.bubble", text: String(localized: "問題を報告"), url: "https://github.com/HEHEX8/PlayCoverManagerGUI/issues")
                        LinkButton(icon: "gamecontroller", text: String(localized: "PlayCover プロジェクト"), url: "https://github.com/PlayCover/PlayCover")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                // Copyright
                VStack(spacing: 4) {
                    Text("© 2025 HEHEX8")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("MIT ライセンスで提供")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper Views for About
private struct RequirementRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(text)
                .font(.callout)
        }
    }
}

private struct LinkButton: View {
    let icon: String
    let text: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 24)
                Text(text)
                    .font(.callout)
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
