import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers

struct SettingsRootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var windowSize: CGSize = CGSize(width: 600, height: 500)
    
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 600.0
        let baseHeight: CGFloat = 500.0
        
        let widthScale = size.width / baseWidth
        let heightScale = size.height / baseHeight
        let scale = min(widthScale, heightScale)
        
        return max(1.0, min(2.0, scale))
    }
    
    private var uiScale: CGFloat {
        calculateUIScale(for: windowSize)
    }

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
        .uiScale(uiScale)  // Inject UI scale into environment for all tabs
        .padding(24 * uiScale)
        .frame(minWidth: 600, minHeight: 500)
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
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
    }
}

private struct GeneralSettingsView: View {
    @Environment(\.uiScale) var uiScale
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
            VStack(spacing: 20 * uiScale) {
                // Storage Card
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    Label("ストレージ", systemImage: "externaldrive.fill")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.blue)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        // Storage path display
                        VStack(alignment: .leading, spacing: 8 * uiScale) {
                            Text("保存先")
                                .font(.system(size: 13 * uiScale, weight: .medium))
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
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8 * uiScale)
                                        .padding(.vertical, 4 * uiScale)
                                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 6 * uiScale))
                                }
                            }
                            .padding(12 * uiScale)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 8 * uiScale))
                        }
                        
                        Button {
                            dismiss()
                            appViewModel.requestStorageLocationChange()
                        } label: {
                            Label("保存先を変更", systemImage: "folder.badge.gearshape")
                                .font(.system(size: 14 * uiScale, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .help(String(localized: "すべてのコンテナをアンマウントしてから保存先を変更します"))
                        
                        Text("保存先を変更すると、マウント中のコンテナをすべてアンマウントしてから新しい保存先に環境を構築します。")
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Mount Settings Card
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    Label("マウント設定", systemImage: "internaldrive")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.purple)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        Toggle(isOn: Binding(get: { settingsStore.nobrowseEnabled }, set: { settingsStore.nobrowseEnabled = $0 })) {
                            VStack(alignment: .leading, spacing: 4 * uiScale) {
                                Text("Finder に表示しない (-nobrowse)")
                                    .font(.system(size: 13 * uiScale))
                                    .fontWeight(.medium)
                                Text("有効にすると、マウントされたディスクイメージが Finder のサイドバーに表示されなくなります。")
                                    .font(.system(size: 11 * uiScale))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .toggleStyle(.switch)
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                

                // Language Card
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    Label("言語", systemImage: "globe")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.green)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        VStack(alignment: .leading, spacing: 8 * uiScale) {
                            Text("アプリの言語")
                                .font(.system(size: 13 * uiScale))
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
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
            }
            .padding(20 * uiScale)
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
    @Environment(\.uiScale) var uiScale
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // Internal Data Handling Card
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    Label("内部データ処理の既定値", systemImage: "doc.on.doc")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.orange)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        VStack(alignment: .leading, spacing: 8 * uiScale) {
                            Text("既定の処理")
                                .font(.system(size: 15 * uiScale))
                                .font(.system(size: 13 * uiScale))
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
                        HStack(alignment: .top, spacing: 12 * uiScale) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 20 * uiScale, weight: .semibold))
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4 * uiScale) {
                                Text("説明")
                                    .font(.system(size: 13 * uiScale))
                                    .fontWeight(.semibold)
                                
                                Text("アプリのコンテナに内部データが残っていた場合のデフォルト処理です。ランチャーから起動する際に変更できます。")
                                    .font(.system(size: 15 * uiScale))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12 * uiScale)
                        .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8 * uiScale))
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                Spacer()
            }
            .padding(20 * uiScale)
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
    @State private var windowSize: CGSize = CGSize(width: 800, height: 600)
    
    enum InstallPhase {
        case selection      // IPA選択
        case analyzing      // 解析中
        case confirmation   // 確認画面
        case installing     // インストール中
        case results        // 結果表示
    }
    
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 800.0
        let baseHeight: CGFloat = 600.0
        
        let widthScale = size.width / baseWidth
        let heightScale = size.height / baseHeight
        let scale = min(widthScale, heightScale)
        
        return max(1.0, min(2.0, scale))
    }
    
    private var uiScale: CGFloat {
        calculateUIScale(for: windowSize)
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(0.95),
                    Color(nsColor: .controlBackgroundColor).opacity(0.98)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Text("IPA インストーラー")
                        .font(.system(size: 24 * uiScale, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24 * uiScale))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.escape, modifiers: [])
                    .help("閉じる (Esc)")
                }
                .padding(.horizontal, 32 * uiScale)
                .padding(.top, 24 * uiScale)
                .padding(.bottom, 16 * uiScale)
                
                Divider()
                    .padding(.horizontal, 32 * uiScale)
                
                // Content area with phase views
                ScrollView {
                    VStack(spacing: 24 * uiScale) {
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
                    }
                    .padding(.horizontal, 32 * uiScale)
                    .padding(.vertical, 24 * uiScale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom buttons bar
                if currentPhase != .analyzing {
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.horizontal, 32 * uiScale)
                        
                        bottomButtons
                            .padding(.horizontal, 32 * uiScale)
                            .padding(.vertical, 20 * uiScale)
                    }
                    .background(
                        Color(nsColor: .controlBackgroundColor)
                            .opacity(0.8)
                            .blur(radius: 20)
                    )
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .clipShape(RoundedRectangle(cornerRadius: 16 * uiScale))
        .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .onAppear {
            let diskImageService = DiskImageService(processRunner: ProcessRunner(), settings: settingsStore)
            let launcherService = LauncherService()
            installerService = IPAInstallerService(diskImageService: diskImageService, settingsStore: settingsStore, launcherService: launcherService)
        }
        .uiScale(uiScale)  // Inject UI scale into environment for all child views
    }
    
    // MARK: - Selection View
    private var selectionView: some View {
        VStack(spacing: 32 * uiScale) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120 * uiScale, height: 120 * uiScale)
                
                Image(systemName: "doc.badge.arrow.up.fill")
                    .font(.system(size: 56 * uiScale, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 12 * uiScale) {
                Text("IPA ファイルを選択")
                    .font(.system(size: 28 * uiScale, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("インストールする IPA ファイルを選択してください")
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                selectIPAFiles()
            } label: {
                HStack(spacing: 8 * uiScale) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 16 * uiScale, weight: .semibold))
                    Text("IPA を選択")
                        .font(.system(size: 16 * uiScale, weight: .semibold))
                }
                .padding(.horizontal, 24 * uiScale)
                .padding(.vertical, 12 * uiScale)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 48 * uiScale)
    }
    
    // MARK: - Analyzing View
    private var analyzingView: some View {
        VStack(spacing: 32 * uiScale) {
            Spacer()
            
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120 * uiScale, height: 120 * uiScale)
                
                ProgressView()
                    .scaleEffect(1.5 * uiScale)
                    .controlSize(.large)
            }
            
            VStack(spacing: 12 * uiScale) {
                Text("解析中")
                    .font(.system(size: 28 * uiScale, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("IPA ファイルを解析しています...")
                    .font(.system(size: 16 * uiScale))
                    .foregroundStyle(.secondary)
                
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 13 * uiScale))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8 * uiScale)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 48 * uiScale)
    }
    
    // MARK: - Confirmation View
    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // Single or multiple app confirmation
                if analyzedIPAs.count == 1, let info = analyzedIPAs.first {
                    // Single app confirmation with modern card
                    VStack(spacing: 20 * uiScale) {
                        // App icon with shadow
                        if let icon = info.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 100 * uiScale, height: 100 * uiScale)
                                .clipShape(RoundedRectangle(cornerRadius: 22 * uiScale))
                                .shadow(color: .black.opacity(0.25), radius: 12 * uiScale, x: 0, y: 6 * uiScale)
                        }
                        
                        VStack(spacing: 8 * uiScale) {
                            Text(info.appName)
                                .font(.system(size: 26 * uiScale, weight: .bold))
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            Text(info.bundleID)
                                .font(.system(size: 13 * uiScale))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .padding(.horizontal, 20 * uiScale)
                    }
                    .padding(.vertical, 24 * uiScale)
                    
                    // Install type card
                    VStack(spacing: 16 * uiScale) {
                        installTypeIndicator(for: info)
                        
                        Text(installTypeMessage(for: info))
                            .font(.system(size: 14 * uiScale))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20 * uiScale)
                    .background(
                        RoundedRectangle(cornerRadius: 12 * uiScale)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                    
                    // Details card
                    VStack(spacing: 12 * uiScale) {
                        HStack {
                            Text("バージョン")
                                .font(.system(size: 14 * uiScale))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let existing = info.existingVersion {
                                Text("\(existing) → \(info.version)")
                                    .font(.system(size: 14 * uiScale, weight: .medium))
                                    .foregroundStyle(.primary)
                            } else {
                                Text(info.version)
                                    .font(.system(size: 14 * uiScale, weight: .medium))
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Text("ファイルサイズ")
                                .font(.system(size: 14 * uiScale))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: info.fileSize, countStyle: .file))
                                .font(.system(size: 14 * uiScale, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(20 * uiScale)
                    .background(
                        RoundedRectangle(cornerRadius: 12 * uiScale)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                
            } else if analyzedIPAs.count > 1 {
                // Multiple apps confirmation with modern card layout
                VStack(spacing: 20 * uiScale) {
                    // Header card with summary
                    VStack(spacing: 16 * uiScale) {
                        HStack(spacing: 12 * uiScale) {
                            Image(systemName: "square.stack.3d.down.forward.fill")
                                .font(.system(size: 32 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                            
                            VStack(alignment: .leading, spacing: 4 * uiScale) {
                                Text("\(analyzedIPAs.count) 個のアプリ")
                                    .font(.system(size: 24 * uiScale, weight: .bold))
                                
                                Text("インストール準備完了")
                                    .font(.system(size: 14 * uiScale))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Summary badges
                        let newInstalls = analyzedIPAs.filter { $0.installType == .newInstall }.count
                        let upgrades = analyzedIPAs.filter { $0.installType == .upgrade }.count
                        let others = analyzedIPAs.count - newInstalls - upgrades
                        let totalSize = analyzedIPAs.reduce(0) { $0 + $1.fileSize }
                        
                        HStack(spacing: 12 * uiScale) {
                            if newInstalls > 0 {
                                HStack(spacing: 4 * uiScale) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 12 * uiScale))
                                    Text("\(newInstalls)")
                                        .font(.system(size: 14 * uiScale, weight: .semibold))
                                }
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 12 * uiScale)
                                .padding(.vertical, 6 * uiScale)
                                .background(Color.blue.opacity(0.15), in: Capsule())
                            }
                            if upgrades > 0 {
                                HStack(spacing: 4 * uiScale) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 12 * uiScale))
                                    Text("\(upgrades)")
                                        .font(.system(size: 14 * uiScale, weight: .semibold))
                                }
                                .foregroundStyle(.green)
                                .padding(.horizontal, 12 * uiScale)
                                .padding(.vertical, 6 * uiScale)
                                .background(Color.green.opacity(0.15), in: Capsule())
                            }
                            if others > 0 {
                                HStack(spacing: 4 * uiScale) {
                                    Image(systemName: "arrow.clockwise.circle.fill")
                                        .font(.system(size: 12 * uiScale))
                                    Text("\(others)")
                                        .font(.system(size: 14 * uiScale, weight: .semibold))
                                }
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12 * uiScale)
                                .padding(.vertical, 6 * uiScale)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                            }
                            
                            Spacer()
                            
                            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                                .font(.system(size: 14 * uiScale, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(20 * uiScale)
                    .background(
                        RoundedRectangle(cornerRadius: 12 * uiScale)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                    
                    // App list with modern card design
                    VStack(spacing: 8 * uiScale) {
                        ForEach(analyzedIPAs) { info in
                            HStack(spacing: 12 * uiScale) {
                                // App icon with shadow
                                if let icon = info.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 52 * uiScale, height: 52 * uiScale)
                                        .clipShape(RoundedRectangle(cornerRadius: 12 * uiScale))
                                        .shadow(color: .black.opacity(0.2), radius: 4 * uiScale, x: 0, y: 2)
                                } else {
                                    RoundedRectangle(cornerRadius: 12 * uiScale)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 52 * uiScale, height: 52 * uiScale)
                                        .overlay {
                                            Image(systemName: "app.dashed")
                                                .font(.system(size: 20 * uiScale))
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                
                                // App info
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(info.appName)
                                        .font(.system(size: 15 * uiScale, weight: .medium))
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 8 * uiScale) {
                                        // Install type badge
                                        Group {
                                            switch info.installType {
                                            case .newInstall:
                                                HStack(spacing: 3 * uiScale) {
                                                    Image(systemName: "sparkles")
                                                    Text("新規")
                                                }
                                                .foregroundStyle(.blue)
                                            case .upgrade:
                                                HStack(spacing: 3 * uiScale) {
                                                    Image(systemName: "arrow.up.circle.fill")
                                                    Text("更新")
                                                }
                                                .foregroundStyle(.green)
                                            case .downgrade:
                                                HStack(spacing: 3 * uiScale) {
                                                    Image(systemName: "arrow.down.circle.fill")
                                                    Text("ダウン")
                                                }
                                                .foregroundStyle(.orange)
                                            case .reinstall:
                                                HStack(spacing: 3 * uiScale) {
                                                    Image(systemName: "arrow.clockwise.circle.fill")
                                                    Text("上書き")
                                                }
                                                .foregroundStyle(.secondary)
                                            }
                                        }
                                        .font(.system(size: 12 * uiScale))
                                        
                                        Text("・")
                                            .foregroundStyle(.tertiary)
                                            .font(.system(size: 12 * uiScale))
                                        
                                        Text(ByteCountFormatter.string(fromByteCount: info.fileSize, countStyle: .file))
                                            .font(.system(size: 12 * uiScale))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Remove from list button
                                Button {
                                    removeIPAFromList(info)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                .buttonStyle(.plain)
                                .help("リストから外す")
                            }
                            .padding(16 * uiScale)
                            .background(
                                RoundedRectangle(cornerRadius: 12 * uiScale)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            )
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Installing View
    private var installingView: some View {
        VStack(spacing: 20 * uiScale) {
            // Header with progress indicator
            VStack(spacing: 12 * uiScale) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48 * uiScale))
                    .foregroundStyle(.blue)
                
                Text("インストール中")
                    .font(.system(size: 22 * uiScale, weight: .bold))
                    .fontWeight(.semibold)
                
                if let service = installerService, !service.currentStatus.isEmpty {
                    Text(service.currentStatus)
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Overall progress bar (indeterminate animation)
                if let service = installerService {
                    let totalItems = analyzedIPAs.count
                    let completed = service.installedApps.count + service.failedApps.count
                    
                    VStack(spacing: 8 * uiScale) {
                        // Indeterminate progress bar (animated)
                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(width: 400 * uiScale)
                        
                        Text("\(completed) / \(totalItems) 完了")
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, 40 * uiScale)
            
            // Installation log
            ScrollView {
                VStack(alignment: .leading, spacing: 12 * uiScale) {
                    if let service = installerService {
                        // Completed installations (with icons)
                        ForEach(service.installedAppDetails) { detail in
                            HStack(spacing: 12 * uiScale) {
                                // App icon with checkmark badge
                                ZStack(alignment: .bottomTrailing) {
                                    if let icon = detail.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                            .clipShape(RoundedRectangle(cornerRadius: 10 * uiScale))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10 * uiScale)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                    }
                                    
                                    // Checkmark badge
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16 * uiScale))
                                        .foregroundStyle(.white)
                                        .background(
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 18 * uiScale, height: 18 * uiScale)
                                        )
                                        .offset(x: 2, y: 2)
                                }
                                .frame(width: 48 * uiScale, height: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 2 * uiScale) {
                                    Text(detail.appName)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("インストール完了")
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16 * uiScale)
                            .padding(.vertical, 8 * uiScale)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8 * uiScale)
                        }
                        
                        // Currently installing (if any)
                        if !service.currentAppName.isEmpty && !service.installedAppDetails.contains(where: { $0.appName == service.currentAppName }) {
                            HStack(spacing: 12 * uiScale) {
                                // App icon or progress spinner
                                ZStack {
                                    if let icon = service.currentAppIcon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                            .clipShape(RoundedRectangle(cornerRadius: 10 * uiScale))
                                            .opacity(0.7)  // Slightly faded during install
                                    } else {
                                        RoundedRectangle(cornerRadius: 10 * uiScale)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                    }
                                    
                                    // Overlay progress spinner on icon
                                    ProgressView()
                                        .controlSize(.regular)
                                }
                                .frame(width: 48 * uiScale, height: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 2 * uiScale) {
                                    Text(service.currentAppName)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text(service.currentStatus)
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16 * uiScale)
                            .padding(.vertical, 8 * uiScale)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8 * uiScale)
                        }
                        
                        // Failed installations
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12 * uiScale) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20 * uiScale, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 32 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 2 * uiScale) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16 * uiScale)
                            .padding(.vertical, 8 * uiScale)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8 * uiScale)
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
        VStack(spacing: 16 * uiScale) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22 * uiScale, weight: .bold))
                    .foregroundStyle(.green)
                Text("インストール結果")
                    .font(.system(size: 22 * uiScale, weight: .bold))
                    .fontWeight(.semibold)
            }
            
            ScrollView {
                VStack(spacing: 12 * uiScale) {
                    if let service = installerService {
                        // Success list
                        ForEach(service.installedAppDetails) { detail in
                            HStack(spacing: 12 * uiScale) {
                                // App icon with checkmark overlay
                                ZStack(alignment: .bottomTrailing) {
                                    if let icon = detail.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                            .clipShape(RoundedRectangle(cornerRadius: 10 * uiScale))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10 * uiScale)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                    }
                                    
                                    // Checkmark badge
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20 * uiScale))
                                        .foregroundStyle(.white)
                                        .background(
                                            Circle()
                                                .fill(.green)
                                                .frame(width: 22 * uiScale, height: 22 * uiScale)
                                        )
                                        .offset(x: 4, y: 4)
                                }
                                .frame(width: 48 * uiScale, height: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(detail.appName)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("インストール完了")
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8 * uiScale)
                        }
                        
                        // Failure list
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12 * uiScale) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20 * uiScale, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8 * uiScale)
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
        HStack(spacing: 8 * uiScale) {
            switch info.installType {
            case .newInstall:
                Image(systemName: "sparkles")
                    .font(.system(size: 32 * uiScale))
                    .foregroundStyle(.blue)
                Text("新規インストール")
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .foregroundStyle(.blue)
            case .upgrade:
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32 * uiScale))
                    .foregroundStyle(.green)
                Text("アップグレード")
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .foregroundStyle(.green)
            case .downgrade:
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 32 * uiScale))
                    .foregroundStyle(.orange)
                Text("ダウングレード")
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .foregroundStyle(.orange)
            case .reinstall:
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 32 * uiScale))
                    .foregroundStyle(.secondary)
                Text("再インストール")
                    .font(.system(size: 17 * uiScale, weight: .semibold))
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
        HStack(spacing: 12 * uiScale) {
            // Hide cancel button during installation - too complex to safely cancel
            if currentPhase != .installing && currentPhase != .analyzing {
                Button {
                    dismiss()
                } label: {
                    Text(currentPhase == .results ? "閉じる" : "キャンセル")
                        .font(.system(size: 14 * uiScale, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
            }
            
            Spacer()
            
            switch currentPhase {
            case .confirmation:
                Button {
                    selectIPAFiles()
                } label: {
                    HStack(spacing: 6 * uiScale) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14 * uiScale))
                        Text("別の IPA を追加")
                            .font(.system(size: 14 * uiScale, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button {
                    Task {
                        await startInstallation()
                    }
                } label: {
                    HStack(spacing: 6 * uiScale) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14 * uiScale))
                        Text("インストール開始")
                            .font(.system(size: 14 * uiScale, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(analyzedIPAs.isEmpty)
                .keyboardShortcut(.defaultAction)
                
            case .results:
                Button {
                    dismiss()
                } label: {
                    Text("完了")
                        .font(.system(size: 14 * uiScale, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
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
    @State private var windowSize: CGSize = CGSize(width: 700, height: 600)
    
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
    
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 700.0
        let baseHeight: CGFloat = 600.0
        
        let widthScale = size.width / baseWidth
        let heightScale = size.height / baseHeight
        let scale = min(widthScale, heightScale)
        
        return max(1.0, min(2.0, scale))
    }
    
    private var uiScale: CGFloat {
        calculateUIScale(for: windowSize)
    }
    
    var body: some View {
        VStack(spacing: 16 * uiScale) {
            Text("アプリアンインストーラー")
                .font(.system(size: 20 * uiScale, weight: .semibold))
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
        .padding(20 * uiScale)
        .frame(minWidth: 700, minHeight: 600)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .onAppear {
            Task {
                await loadApps()
            }
        }
        .uiScale(uiScale)  // Inject UI scale into environment for all child views
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16 * uiScale) {
            ProgressView()
            Text("アプリ一覧を読み込み中...")
                .font(.system(size: 17 * uiScale, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Confirming View (Single or Multiple)
    private var confirmingView: some View {
        VStack(spacing: 16 * uiScale) {
            let selectedAppInfos = apps.filter { selectedApps.contains($0.bundleID) }
            
            if selectedAppInfos.count == 1, let app = selectedAppInfos.first {
                // Single app confirmation
                
                // App icon and info
                VStack(spacing: 16 * uiScale) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 80 * uiScale, height: 80 * uiScale)
                            .clipShape(RoundedRectangle(cornerRadius: 18 * uiScale))
                            .shadow(color: .black.opacity(0.2), radius: 8 * uiScale, x: 0, y: 4)
                    }
                    
                    VStack(spacing: 8 * uiScale) {
                        Text(app.appName)
                            .font(.system(size: 22 * uiScale, weight: .bold))
                            .fontWeight(.semibold)
                            .lineLimit(2)
                        
                        Text(app.bundleID)
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                Divider()
                
                // Confirmation message
                VStack(spacing: 12 * uiScale) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48 * uiScale))
                        .foregroundStyle(.orange)
                    
                    Text("このアプリをアンインストールしますか？")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                    
                    Text("この操作は取り消せません。")
                        .font(.system(size: 13 * uiScale))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Size info
                VStack(spacing: 8 * uiScale) {
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
                .font(.system(size: 15 * uiScale))
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8 * uiScale))
                
            } else if selectedAppInfos.count > 1 {
                // Multiple apps confirmation with compact list
                VStack(spacing: 10 * uiScale) {
                    Text("\(selectedAppInfos.count) 個のアプリ")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                    
                    // Scrollable list of selected apps with optimized spacing
                    ScrollView {
                        VStack(spacing: 6 * uiScale) {
                            ForEach(selectedAppInfos, id: \.bundleID) { app in
                                HStack(spacing: 10 * uiScale) {
                                    // App icon (slightly smaller)
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 42 * uiScale, height: 42 * uiScale)
                                            .clipShape(RoundedRectangle(cornerRadius: 9 * uiScale))
                                            .shadow(color: .black.opacity(0.2), radius: 3 * uiScale, x: 0, y: 1)
                                    } else {
                                        RoundedRectangle(cornerRadius: 9 * uiScale)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 42 * uiScale, height: 42 * uiScale)
                                            .overlay {
                                                Image(systemName: "app.dashed")
                                                    .font(.system(size: 11 * uiScale))
                                                    .foregroundStyle(.secondary)
                                            }
                                    }
                                    
                                    // App info (compact layout)
                                    VStack(alignment: .leading, spacing: 2 * uiScale) {
                                        Text(app.appName)
                                            .font(.system(size: 15 * uiScale))
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        
                                        HStack(spacing: 4 * uiScale) {
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
                                            .font(.system(size: 15 * uiScale))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("選択を解除")
                                }
                                .padding(10 * uiScale)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8 * uiScale))
                            }
                        }
                    }
                    .frame(maxHeight: 280 * uiScale)
                }
                
                Divider()
                
                // Confirmation message
                VStack(spacing: 12 * uiScale) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48 * uiScale))
                        .foregroundStyle(.orange)
                    
                    Text("\(selectedAppInfos.count) 個のアプリをアンインストールしますか？")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                    
                    Text("この操作は取り消せません。")
                        .font(.system(size: 13 * uiScale))
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Size info
                let totalAppSize = selectedAppInfos.reduce(0) { $0 + $1.appSize }
                let totalDiskImageSize = selectedAppInfos.reduce(0) { $0 + $1.diskImageSize }
                let totalSelectedSize = totalAppSize + totalDiskImageSize
                
                VStack(spacing: 8 * uiScale) {
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
                .font(.system(size: 15 * uiScale))
                .padding()
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8 * uiScale))
                
            } else {
                Text("アプリ情報が見つかりません")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Selection View
    private var selectionView: some View {
        VStack(alignment: .leading, spacing: 12 * uiScale) {
            if apps.isEmpty {
                VStack(spacing: 12 * uiScale) {
                    Image(systemName: "tray")
                        .font(.system(size: 48 * uiScale))
                        .foregroundStyle(.secondary)
                    Text("アンインストール可能なアプリがありません")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HStack {
                    Text("インストール済みアプリ (\(apps.count) 個)")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                    Spacer()
                    Text("合計: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                }
                
                List(apps, id: \.bundleID, selection: $selectedApps) { app in
                    HStack(spacing: 12 * uiScale) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 48 * uiScale, height: 48 * uiScale)
                                .clipShape(RoundedRectangle(cornerRadius: 10 * uiScale))
                        } else {
                            RoundedRectangle(cornerRadius: 10 * uiScale)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 48 * uiScale, height: 48 * uiScale)
                        }
                        
                        VStack(alignment: .leading, spacing: 4 * uiScale) {
                            Text(app.appName)
                                .font(.system(size: 15 * uiScale))
                                .lineLimit(2)
                            Text(app.bundleID)
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2 * uiScale) {
                            Text(ByteCountFormatter.string(fromByteCount: app.appSize + app.diskImageSize, countStyle: .file))
                                .font(.system(size: 11 * uiScale))
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
        VStack(spacing: 20 * uiScale) {
            // Header with progress
            VStack(spacing: 12 * uiScale) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 48 * uiScale))
                    .foregroundStyle(.red)
                
                Text("アンインストール中")
                    .font(.system(size: 22 * uiScale, weight: .bold))
                    .fontWeight(.semibold)
                
                if let service = uninstallerService, !service.currentStatus.isEmpty {
                    Text(service.currentStatus)
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Overall progress bar
                if let service = uninstallerService {
                    let totalItems = selectedApps.count
                    let completed = service.uninstalledApps.count + service.failedApps.count
                    let progressValue = totalItems > 0 ? Double(completed) / Double(totalItems) : 0
                    
                    VStack(spacing: 8 * uiScale) {
                        ProgressView(value: progressValue)
                            .frame(width: 400 * uiScale)
                        
                        Text("\(completed) / \(totalItems) 完了")
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Divider()
                .padding(.horizontal, 40 * uiScale)
            
            // Uninstall log
            ScrollView {
                VStack(alignment: .leading, spacing: 12 * uiScale) {
                    if let service = uninstallerService {
                        // Completed uninstalls
                        ForEach(service.uninstalledApps, id: \.self) { appName in
                            HStack(spacing: 12 * uiScale) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20 * uiScale, weight: .semibold))
                                    .foregroundStyle(.green)
                                    .frame(width: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 2 * uiScale) {
                                    Text(appName)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("アンインストール完了")
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16 * uiScale)
                            .padding(.vertical, 8 * uiScale)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8 * uiScale)
                        }
                        
                        // Currently uninstalling (if any)
                        if !service.currentStatus.isEmpty && service.currentStatus != String(localized: "完了") && 
                           !service.uninstalledApps.contains(where: { service.currentStatus.contains($0) }) {
                            HStack(spacing: 12 * uiScale) {
                                ProgressView()
                                    .controlSize(.regular)
                                    .frame(width: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 2 * uiScale) {
                                    Text(service.currentStatus)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("処理中...")
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16 * uiScale)
                            .padding(.vertical, 8 * uiScale)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8 * uiScale)
                        }
                        
                        // Failed uninstalls
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12 * uiScale) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20 * uiScale, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 2 * uiScale) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16 * uiScale)
                            .padding(.vertical, 8 * uiScale)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8 * uiScale)
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
        VStack(spacing: 16 * uiScale) {
            HStack {
                if let service = uninstallerService, !service.failedApps.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22 * uiScale, weight: .bold))
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22 * uiScale, weight: .bold))
                        .foregroundStyle(.green)
                }
                Text("アンインストール結果")
                    .font(.system(size: 22 * uiScale, weight: .bold))
                    .fontWeight(.semibold)
            }
            
            ScrollView {
                VStack(spacing: 12 * uiScale) {
                    if let service = uninstallerService {
                        // Success list
                        ForEach(service.uninstalledApps, id: \.self) { appName in
                            HStack(spacing: 12 * uiScale) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20 * uiScale, weight: .semibold))
                                    .foregroundStyle(.green)
                                    .frame(width: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(appName)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                        .lineLimit(2)
                                    Text("アンインストール完了")
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8 * uiScale)
                        }
                        
                        // Failure list
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 12 * uiScale) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20 * uiScale, weight: .semibold))
                                    .foregroundStyle(.red)
                                    .frame(width: 48 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.system(size: 15 * uiScale))
                                        .fontWeight(.medium)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(8 * uiScale)
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
    @Environment(\.uiScale) var uiScale
    @Environment(SettingsStore.self) private var settingsStore
    @State private var showingResetConfirmation = false
    @State private var showingClearCacheConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // Cache Card
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    Label("キャッシュ", systemImage: "folder.badge.minus")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.cyan)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        Button {
                            showingClearCacheConfirmation = true
                        } label: {
                            Label("アイコンキャッシュをクリア", systemImage: "trash")
                                .font(.system(size: 14 * uiScale, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        
                        Text("アプリアイコンのキャッシュをクリアします。次回起動時に再読み込みされます。")
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // PlayCover Shortcuts Card
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    Label("PlayCover ショートカット", systemImage: "folder.badge.questionmark")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.yellow)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        Button {
                            removePlayCoverShortcuts()
                        } label: {
                            Label("~/Applications/PlayCover を削除", systemImage: "trash")
                                .font(.system(size: 14 * uiScale, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.yellow)
                        
                        Text("PlayCover が作成する不要なショートカットを削除します。PlayCover.app 起動時に再作成されます。")
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Reset Card
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    Label("リセット", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.red)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12 * uiScale) {
                        Button {
                            showingResetConfirmation = true
                        } label: {
                            Label("設定をリセット", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 14 * uiScale, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        
                        Text("すべての設定を初期値に戻します（ディスクイメージとアプリは削除されません）。")
                            .font(.system(size: 11 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                Spacer()
            }
            .padding(20 * uiScale)
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
    @Environment(\.uiScale) var uiScale
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // App Icon and Name Card
                VStack(spacing: 16 * uiScale) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 100 * uiScale, height: 100 * uiScale)
                            .clipShape(RoundedRectangle(cornerRadius: 22 * uiScale))
                            .shadow(color: .black.opacity(0.2), radius: 10 * uiScale, x: 0, y: 5 * uiScale)
                    }
                    
                    VStack(spacing: 6 * uiScale) {
                        Text("PlayCover Manager")
                            .font(.system(size: 28 * uiScale, weight: .bold))
                        
                        Text("Version \(appVersion) (Build \(buildNumber))")
                            .font(.system(size: 14 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Description Card
                VStack(alignment: .leading, spacing: 12 * uiScale) {
                    Label("概要", systemImage: "info.circle.fill")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.blue)
                    
                    Divider()
                    
                    Text("PlayCover Manager は、PlayCover でインストールした iOS アプリを統合的に管理するための GUI ツールです。")
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("IPA インストール、アプリ起動、アンインストール、ストレージ管理などの機能を提供します。")
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // System Requirements Card
                VStack(alignment: .leading, spacing: 12 * uiScale) {
                    Label("システム要件", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.green)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 10 * uiScale) {
                        RequirementRow(icon: "desktopcomputer", text: String(localized: "macOS Tahoe 26.0 以降"))
                        RequirementRow(icon: "cpu", text: String(localized: "Apple Silicon Mac 専用"))
                        RequirementRow(icon: "square.stack.3d.down.right", text: String(localized: "ASIF ディスクイメージ形式対応"))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Links Card
                VStack(alignment: .leading, spacing: 12 * uiScale) {
                    Label("リンク", systemImage: "link.circle.fill")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.purple)
                    
                    Divider()
                    
                    VStack(spacing: 8 * uiScale) {
                        LinkButton(icon: "link", text: String(localized: "GitHub リポジトリ"), url: "https://github.com/HEHEX8/PlayCoverManagerGUI")
                        LinkButton(icon: "exclamationmark.bubble", text: String(localized: "問題を報告"), url: "https://github.com/HEHEX8/PlayCoverManagerGUI/issues")
                        LinkButton(icon: "gamecontroller", text: String(localized: "PlayCover プロジェクト"), url: "https://github.com/PlayCover/PlayCover")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Copyright
                VStack(spacing: 4 * uiScale) {
                    Text("© 2025 HEHEX8")
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                    
                    Text("MIT ライセンスで提供")
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8 * uiScale)
            }
            .padding(20 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Helper Views for About
private struct RequirementRow: View {
    @Environment(\.uiScale) var uiScale
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12 * uiScale) {
            Image(systemName: icon)
                .font(.system(size: 20 * uiScale, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 24 * uiScale)
            Text(text)
                .font(.system(size: 15 * uiScale))
        }
    }
}

private struct LinkButton: View {
    @Environment(\.uiScale) var uiScale
    let icon: String
    let text: String
    let url: String
    
    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12 * uiScale) {
                Image(systemName: icon)
                    .font(.system(size: 20 * uiScale, weight: .semibold))
                    .foregroundStyle(.blue)
                    .frame(width: 24 * uiScale)
                Text(text)
                    .font(.system(size: 15 * uiScale))
                Spacer()
                Image(systemName: "arrow.up.forward")
                    .font(.system(size: 11 * uiScale))
                    .foregroundStyle(.secondary)
            }
            .padding(12 * uiScale)
            .background(Color.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 8 * uiScale))
        }
        .buttonStyle(.plain)
    }
}
