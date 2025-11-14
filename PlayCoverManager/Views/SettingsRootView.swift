import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers

struct SettingsRootView: View {
    @Binding var isPresented: Bool
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @State private var windowSize: CGSize = CGSize(width: 700, height: 600)
    @State private var selectedTab: SettingsTab = .general
    @State private var showLanguageChangeAlert = false
    
    enum SettingsTab: String, CaseIterable, Identifiable, TabItemProtocol {
        case general
        case data
        case maintenance
        case about
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .general: return String(localized: "一般")
            case .data: return String(localized: "データ")
            case .maintenance: return String(localized: "メンテナンス")
            case .about: return String(localized: "情報")
            }
        }
        
        var icon: String {
            switch self {
            case .general: return "gear"
            case .data: return "internaldrive"
            case .maintenance: return "wrench.and.screwdriver"
            case .about: return "info.circle"
            }
        }
    }
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }
    
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
                    Text("PlayCover Manager 設定")
                        .font(.system(size: 24 * uiScale, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button {
                        isPresented = false
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
                
                // Custom Tab Content
                ScrollView {
                    VStack(spacing: 6 * uiScale) {
                        // Tab selector - using unified CompactTabBar
                        CompactTabBar(tabs: SettingsTab.allCases, selectedTab: $selectedTab, uiScale: uiScale)
                            .padding(.horizontal, 32 * uiScale)
                        
                        // Tab content
                        VStack(spacing: 0) {
                            switch selectedTab {
                            case .general:
                                GeneralSettingsView()
                            case .data:
                                DataSettingsView()
                            case .maintenance:
                                MaintenanceSettingsView()
                            case .about:
                                AboutView()
                            }
                        }
                    }
                    .padding(.vertical, 24 * uiScale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .uiScale(uiScale)  // Inject UI scale into environment for all tabs
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .frame(minWidth: 800, minHeight: 600)
        .clipShape(RoundedRectangle.standard(.large, scale: uiScale))
        .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)

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
}

private struct GeneralSettingsView: View {
    @Environment(\.uiScale) var uiScale
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var calculatingSize = false
    @State private var totalDiskUsage: Int64 = 0
    @State private var previousLanguage: SettingsStore.AppLanguage = .system

    var body: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // Storage Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "externaldrive.fill")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("ストレージ")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        // Storage path section
                        VStack(alignment: .leading, spacing: 8 * uiScale) {
                            Text("保存先")
                                .font(.system(size: 13 * uiScale, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            VStack(spacing: 8 * uiScale) {
                                HStack {
                                    Text(settingsStore.diskImageDirectory?.path ?? "未設定")
                                        .font(.system(size: 12 * uiScale, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .truncationMode(.middle)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(12 * uiScale)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle.standard(.small, scale: uiScale)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                )
                                
                                // Storage usage display
                                if calculatingSize || totalDiskUsage > 0 {
                                    HStack {
                                        if calculatingSize {
                                            ProgressView()
                                                .controlSize(.small)
                                            Text("容量を計算中...")
                                                .font(.system(size: 12 * uiScale))
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text(ByteCountFormatter.string(fromByteCount: totalDiskUsage, countStyle: .file))
                                                .font(.system(size: 15 * uiScale, weight: .bold))
                                                .foregroundStyle(.blue)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4 * uiScale)
                                }
                            }
                        }
                        
                        // Change storage button
                        CustomLargeButton(
                            title: "保存先を変更",
                            action: {
                                // Don't dismiss - let the storage change flow handle UI
                                appViewModel.requestStorageLocationChange()
                            },
                            isPrimary: true,
                            icon: "folder.badge.gearshape",
                            uiScale: uiScale
                        )
                        .help(String(localized: "すべてのコンテナをアンマウントしてから保存先を変更します"))
                        
                        // Info text
                        HStack(spacing: 6 * uiScale) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.blue)
                            Text("保存先を変更すると、マウント中のコンテナをすべてアンマウントしてから新しい保存先に環境を構築します。")
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12 * uiScale)
                        .background(
                            RoundedRectangle.standard(.small, scale: uiScale)
                                .fill(Color.blue.opacity(0.05))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
                
                // Mount Settings Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "internaldrive")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .pink],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("マウント設定")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 6 * uiScale) {
                        HStack(spacing: 6 * uiScale) {
                            VStack(alignment: .leading, spacing: 6 * uiScale) {
                                Text("Finder に表示しない (-nobrowse)")
                                    .font(.system(size: 14 * uiScale, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text("有効にすると、マウントされたディスクイメージが Finder のサイドバーに表示されなくなります。")
                                    .font(.system(size: 11 * uiScale))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            CustomToggle(
                                title: "",
                                subtitle: nil,
                                isOn: Binding(get: { settingsStore.nobrowseEnabled }, set: { settingsStore.nobrowseEnabled = $0 }),
                                uiScale: uiScale
                            )
                        }
                        .padding(16 * uiScale)
                        .background(
                            RoundedRectangle.standard(.regular, scale: uiScale)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
                

                // Language Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.green.opacity(0.2), Color.mint.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "globe")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("言語")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        VStack(alignment: .leading, spacing: 10 * uiScale) {
                            Text("アプリの言語")
                                .font(.system(size: 13 * uiScale, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: Binding(
                                get: { settingsStore.appLanguage },
                                set: { newValue in
                                    if newValue != previousLanguage {
                                        settingsStore.appLanguage = newValue
                                        // Trigger alert at QuickLauncherView level (not here!)
                                        settingsStore.showLanguageChangeAlert = true
                                    }
                                }
                            )) {
                                ForEach(SettingsStore.AppLanguage.allCases) { language in
                                    Text(language.localizedDescription).tag(language)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16 * uiScale)
                        .background(
                            RoundedRectangle.standard(.regular, scale: uiScale)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                        
                        // Info text
                        HStack(spacing: 6 * uiScale) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.green)
                            Text("言語を変更すると、アプリを再起動する必要があります。")
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12 * uiScale)
                        .background(
                            RoundedRectangle.standard(.small, scale: uiScale)
                                .fill(Color.green.opacity(0.05))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
                
                // Launch Limit Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "gauge.with.dots.needle.67percent")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("起動制限")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        VStack(alignment: .leading, spacing: 10 * uiScale) {
                            Text("最大同時起動数")
                                .font(.system(size: 13 * uiScale, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 12 * uiScale) {
                                TextField("0", value: Binding(
                                    get: { settingsStore.maxConcurrentApps },
                                    set: { newValue in
                                        settingsStore.maxConcurrentApps = max(0, newValue)
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80 * uiScale)
                                .font(.system(size: 14 * uiScale))
                                
                                Text(settingsStore.maxConcurrentApps == 0 ? "個（無制限）" : "個")
                                    .font(.system(size: 14 * uiScale))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack(spacing: 6 * uiScale) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.orange)
                            Text("同時に起動できるアプリの最大数を制限します。0を設定すると無制限になります。制限数を超える起動申請があった場合、ダイアログで通知されます。")
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12 * uiScale)
                        .background(
                            RoundedRectangle.standard(.small, scale: uiScale)
                                .fill(Color.orange.opacity(0.05))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
            }
            .padding(.horizontal, 24 * uiScale)
            .padding(.vertical, 20 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            previousLanguage = settingsStore.appLanguage
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
    @Environment(\.uiScale) var uiScale
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // Internal Data Handling Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("内部データ処理の既定値")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        VStack(alignment: .leading, spacing: 10 * uiScale) {
                            Text("既定の処理")
                                .font(.system(size: 13 * uiScale, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            Picker("", selection: Binding<SettingsStore.InternalDataStrategy>(
                                get: { settingsStore.defaultDataHandling },
                                set: { settingsStore.defaultDataHandling = $0 }
                            )) {
                                ForEach(SettingsStore.InternalDataStrategy.allCases) { strategy in
                                    Text(strategy.localizedDescription).tag(strategy)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(16 * uiScale)
                        .background(
                            RoundedRectangle.standard(.regular, scale: uiScale)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        )
                        
                        // Info text
                        HStack(spacing: 6 * uiScale) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.orange)
                            Text("アプリのコンテナに内部データが残っていた場合のデフォルト処理です。ランチャーから起動する際に変更できます。")
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12 * uiScale)
                        .background(
                            RoundedRectangle.standard(.small, scale: uiScale)
                                .fill(Color.orange.opacity(0.05))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
                
                Spacer()
            }
            .padding(.horizontal, 24 * uiScale)
            .padding(.vertical, 20 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// IPA Installer Sheet
struct IPAInstallerSheet: View {
    @Binding var isPresented: Bool
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
                    
                    // Hide close button during analyzing and installing phases
                    if currentPhase != .analyzing && currentPhase != .installing {
                        Button {
                            isPresented = false
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
                }
                .padding(.horizontal, 32 * uiScale)
                .padding(.top, 24 * uiScale)
                .padding(.bottom, 16 * uiScale)
                
                Divider()
                    .padding(.horizontal, 32 * uiScale)
                
                // Content area with phase views
                ScrollView {
                    VStack(spacing: 6 * uiScale) {
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
                    .padding(.horizontal, 24 * uiScale)
                    .padding(.vertical, 12 * uiScale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom buttons bar
                if currentPhase != .analyzing {
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.horizontal, 24 * uiScale)
                        
                        bottomButtons
                            .padding(.horizontal, 24 * uiScale)
                            .padding(.vertical, 12 * uiScale)
                    }
                    .background(
                        Color(nsColor: .controlBackgroundColor)
                            .opacity(0.8)
                            .blur(radius: 20)
                    )
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .frame(minWidth: 800, minHeight: 600)
        .clipShape(RoundedRectangle.standard(.large, scale: uiScale))
        .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        .onAppear {
            let diskImageService = DiskImageService(processRunner: ProcessRunner(), settings: settingsStore)
            let launcherService = LauncherService()
            installerService = IPAInstallerService(diskImageService: diskImageService, settingsStore: settingsStore, launcherService: launcherService)
        }
        .uiScale(uiScale)  // Inject UI scale into environment for all child views
    }
    
    // MARK: - Selection View
    private var selectionView: some View {
        VStack(spacing: 16 * uiScale) {
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
            
            VStack(spacing: 6 * uiScale) {
                Text("IPA ファイルを選択")
                    .font(.system(size: 28 * uiScale, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("インストールする IPA ファイルを選択してください")
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            CustomLargeButton(
                title: "IPA を選択",
                action: {
                    selectIPAFiles()
                },
                isPrimary: true,
                icon: "folder.badge.plus",
                uiScale: uiScale
            )
            .keyboardShortcut(.defaultAction)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 32 * uiScale)
    }
    
    // MARK: - Analyzing View
    private var analyzingView: some View {
        VStack(spacing: 16 * uiScale) {
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
            
            VStack(spacing: 6 * uiScale) {
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
        .padding(.horizontal, 32 * uiScale)
    }
    
    // MARK: - Confirmation View
    private var confirmationView: some View {
        ScrollView {
            VStack(spacing: 12 * uiScale) {
                // Single or multiple app confirmation
                if analyzedIPAs.count == 1, let info = analyzedIPAs.first {
                    // Single app confirmation with modern card
                    VStack(spacing: 12 * uiScale) {
                        // App icon with shadow
                        if let icon = info.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 100 * uiScale, height: 100 * uiScale)
                                .clipShape(RoundedRectangle.standard(.extraLarge, scale: uiScale))
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
                    .padding(.vertical, 12 * uiScale)
                    
                    // Install type card
                    VStack(spacing: 8 * uiScale) {
                        installTypeIndicator(for: info)
                        
                        Text(installTypeMessage(for: info))
                            .font(.system(size: 14 * uiScale))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(12 * uiScale)
                    .background(
                        RoundedRectangle.standard(.regular, scale: uiScale)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                    
                    // Details card
                    VStack(spacing: 6 * uiScale) {
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
                    .padding(12 * uiScale)
                    .background(
                        RoundedRectangle.standard(.regular, scale: uiScale)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                
            } else if analyzedIPAs.count > 1 {
                // Multiple apps confirmation with modern card layout
                VStack(spacing: 12 * uiScale) {
                    // Header card with summary
                    VStack(spacing: 8 * uiScale) {
                        HStack(spacing: 6 * uiScale) {
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
                        
                        HStack(spacing: 6 * uiScale) {
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
                    .padding(12 * uiScale)
                    .background(
                        RoundedRectangle.standard(.regular, scale: uiScale)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                    
                    // App list with modern card design
                    VStack(spacing: 8 * uiScale) {
                        ForEach(analyzedIPAs) { info in
                            HStack(spacing: 6 * uiScale) {
                                // App icon with shadow
                                if let icon = info.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 52 * uiScale, height: 52 * uiScale)
                                        .clipShape(RoundedRectangle.standard(.regular, scale: uiScale))
                                        .shadow(color: .black.opacity(0.2), radius: 4 * uiScale, x: 0, y: 2)
                                } else {
                                    RoundedRectangle.standard(.regular, scale: uiScale)
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
                            .padding(12 * uiScale)
                            .background(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            )
                        }
                    }
                }
            } else {
                Text("アプリ情報が見つかりません")
                    .font(.system(size: 16 * uiScale))
                    .foregroundStyle(.secondary)
            }
            }
            .padding(.horizontal, 20 * uiScale)
        }
    }
    
    // MARK: - Installing View
    private var installingView: some View {
        VStack(spacing: 6 * uiScale) {
            // Header with animated icon
            VStack(spacing: 8 * uiScale) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100 * uiScale, height: 100 * uiScale)
                    
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 48 * uiScale, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                
                VStack(spacing: 8 * uiScale) {
                    Text("インストール中")
                        .font(.system(size: 28 * uiScale, weight: .bold))
                    
                    if let service = installerService, !service.currentStatus.isEmpty {
                        Text(service.currentStatus)
                            .font(.system(size: 14 * uiScale))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Progress indicator
                if let service = installerService {
                    let totalItems = analyzedIPAs.count
                    let completed = service.installedApps.count + service.failedApps.count
                    
                    VStack(spacing: 6 * uiScale) {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(width: 400 * uiScale)
                        
                        Text("\(completed) / \(totalItems) 完了")
                            .font(.system(size: 13 * uiScale, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 12 * uiScale)
            
            // Installation log with cards
            ScrollView {
                VStack(spacing: 6 * uiScale) {
                    if let service = installerService {
                        // Completed installations
                        ForEach(service.installedAppDetails) { detail in
                            HStack(spacing: 14 * uiScale) {
                                // App icon with checkmark
                                ZStack(alignment: .bottomTrailing) {
                                    if let icon = detail.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 52 * uiScale, height: 52 * uiScale)
                                            .clipShape(RoundedRectangle.standard(.regular, scale: uiScale))
                                    } else {
                                        RoundedRectangle.standard(.regular, scale: uiScale)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 52 * uiScale, height: 52 * uiScale)
                                    }
                                    
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 22 * uiScale, height: 22 * uiScale)
                                        .overlay {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12 * uiScale, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                        .offset(x: 4, y: 4)
                                }
                                .frame(width: 52 * uiScale, height: 52 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(detail.appName)
                                        .font(.system(size: 15 * uiScale, weight: .medium))
                                        .lineLimit(1)
                                    Text("インストール完了")
                                        .font(.system(size: 13 * uiScale))
                                        .foregroundStyle(.green)
                                }
                                
                                Spacer()
                            }
                            .padding(12 * uiScale)
                            .background(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .fill(Color.green.opacity(0.1))
                            )
                        }
                        
                        // Currently installing
                        if !service.currentAppName.isEmpty && !service.installedAppDetails.contains(where: { $0.appName == service.currentAppName }) {
                            HStack(spacing: 14 * uiScale) {
                                ZStack {
                                    if let icon = service.currentAppIcon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 52 * uiScale, height: 52 * uiScale)
                                            .clipShape(RoundedRectangle.standard(.regular, scale: uiScale))
                                            .opacity(0.6)
                                    } else {
                                        RoundedRectangle.standard(.regular, scale: uiScale)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 52 * uiScale, height: 52 * uiScale)
                                    }
                                    
                                    ProgressView()
                                        .controlSize(.large)
                                }
                                .frame(width: 52 * uiScale, height: 52 * uiScale)
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(service.currentAppName)
                                        .font(.system(size: 15 * uiScale, weight: .medium))
                                        .lineLimit(1)
                                    Text(service.currentStatus)
                                        .font(.system(size: 13 * uiScale))
                                        .foregroundStyle(.blue)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding(12 * uiScale)
                            .background(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        
                        // Failed installations
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 14 * uiScale) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 52 * uiScale, height: 52 * uiScale)
                                    .overlay {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 24 * uiScale, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.system(size: 15 * uiScale, weight: .medium))
                                        .lineLimit(1)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 13 * uiScale))
                                        .foregroundStyle(.red)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(12 * uiScale)
                            .background(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                    }
                }
                .padding(.horizontal, 20 * uiScale)
            }
        }
        .onAppear {
            startStatusUpdater()
        }
        .onDisappear {
            stopStatusUpdater()
        }
    }
    
    // MARK: - Results View
    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 6 * uiScale) {
                // Success icon
                if let service = installerService {
                    let hasFailures = !service.failedApps.isEmpty
                    let hasSuccess = !service.installedAppDetails.isEmpty
                    
                    VStack(spacing: 8 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: hasFailures ? [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)] : [Color.green.opacity(0.2), Color.mint.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 100 * uiScale, height: 100 * uiScale)
                            
                            Image(systemName: hasFailures ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                                .font(.system(size: 48 * uiScale, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: hasFailures ? [.orange, .yellow] : [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        VStack(spacing: 8 * uiScale) {
                            Text(hasFailures ? "インストール完了（一部失敗）" : "インストール完了")
                                .font(.system(size: 28 * uiScale, weight: .bold))
                            
                            if hasSuccess && hasFailures {
                                Text("\(service.installedAppDetails.count) 個成功、\(service.failedApps.count) 個失敗")
                                    .font(.system(size: 14 * uiScale))
                                    .foregroundStyle(.secondary)
                            } else if hasSuccess {
                                Text("\(service.installedAppDetails.count) 個のアプリをインストールしました")
                                    .font(.system(size: 14 * uiScale))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 12 * uiScale)
                    
                    // Success list
                    if !service.installedAppDetails.isEmpty {
                        VStack(alignment: .leading, spacing: 6 * uiScale) {
                            Text("成功")
                                .font(.system(size: 18 * uiScale, weight: .semibold))
                                .foregroundStyle(.green)
                            
                            ForEach(service.installedAppDetails) { detail in
                                HStack(spacing: 14 * uiScale) {
                                    ZStack(alignment: .bottomTrailing) {
                                        if let icon = detail.icon {
                                            Image(nsImage: icon)
                                                .resizable()
                                                .frame(width: 52 * uiScale, height: 52 * uiScale)
                                                .clipShape(RoundedRectangle.standard(.regular, scale: uiScale))
                                        } else {
                                            RoundedRectangle.standard(.regular, scale: uiScale)
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 52 * uiScale, height: 52 * uiScale)
                                        }
                                        
                                        Circle()
                                            .fill(.green)
                                            .frame(width: 22 * uiScale, height: 22 * uiScale)
                                            .overlay {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 12 * uiScale, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                            .offset(x: 4, y: 4)
                                    }
                                    .frame(width: 52 * uiScale, height: 52 * uiScale)
                                    
                                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                                        Text(detail.appName)
                                            .font(.system(size: 15 * uiScale, weight: .medium))
                                            .lineLimit(1)
                                        Text("インストール完了")
                                            .font(.system(size: 13 * uiScale))
                                            .foregroundStyle(.green)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(12 * uiScale)
                                .background(
                                    RoundedRectangle.standard(.regular, scale: uiScale)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                )
                            }
                        }
                    }
                    
                    // Failure list
                    if !service.failedApps.isEmpty {
                        VStack(alignment: .leading, spacing: 6 * uiScale) {
                            Text("失敗")
                                .font(.system(size: 18 * uiScale, weight: .semibold))
                                .foregroundStyle(.red)
                            
                            ForEach(service.failedApps, id: \.self) { error in
                                HStack(spacing: 14 * uiScale) {
                                    Circle()
                                        .fill(.red)
                                        .frame(width: 52 * uiScale, height: 52 * uiScale)
                                        .overlay {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 24 * uiScale, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    
                                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                                        Text(error.components(separatedBy: ":").first ?? error)
                                            .font(.system(size: 15 * uiScale, weight: .medium))
                                            .lineLimit(1)
                                        Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                            .font(.system(size: 13 * uiScale))
                                            .foregroundStyle(.red)
                                            .lineLimit(2)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(12 * uiScale)
                                .background(
                                    RoundedRectangle.standard(.regular, scale: uiScale)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20 * uiScale)
        }
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
        HStack(spacing: 6 * uiScale) {
            // Hide cancel button during installation - too complex to safely cancel
            if currentPhase != .installing && currentPhase != .analyzing {
                CustomButton(
                    title: currentPhase == .results ? "閉じる" : "キャンセル",
                    action: { isPresented = false },
                    isPrimary: false,
                    isDestructive: false,
                    uiScale: uiScale
                )
                .keyboardShortcut(.cancelAction)
            }
            
            Spacer()
            
            switch currentPhase {
            case .confirmation:
                CustomButton(
                    title: "別の IPA を追加",
                    action: { selectIPAFiles() },
                    isPrimary: false,
                    icon: "plus.circle",
                    uiScale: uiScale
                )
                
                CustomButton(
                    title: "インストール開始",
                    action: {
                        Task {
                            await startInstallation()
                        }
                    },
                    isPrimary: true,
                    icon: "arrow.down.circle.fill",
                    uiScale: uiScale,
                    isEnabled: !analyzedIPAs.isEmpty
                )
                .keyboardShortcut(.defaultAction)
                
            case .results:
                CustomButton(
                    title: "完了",
                    action: { isPresented = false },
                    isPrimary: true,
                    uiScale: uiScale
                )
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
        
        // Optimize: Set default directory to Downloads for faster open
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        // Optimize: Disable animations and unnecessary features
        panel.animationBehavior = .none
        panel.showsHiddenFiles = false
        panel.treatsFilePackagesAsDirectories = false
        
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
    @Binding var isPresented: Bool
    let preSelectedBundleID: String?
    
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
    
    enum UninstallPhase {
        case loading        // アプリ一覧読み込み中
        case confirmingSingle  // 個別アンインストール確認中
        case confirmingMultiple  // 複数アンインストール確認中
        case selection      // アプリ選択
        case uninstalling   // アンインストール中
        case results        // 結果表示
    }
    
    init(isPresented: Binding<Bool>, preSelectedBundleID: String? = nil) {
        self._isPresented = isPresented
        self.preSelectedBundleID = preSelectedBundleID
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
                    Text("アプリアンインストーラー")
                        .font(.system(size: 24 * uiScale, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    // Hide close button during uninstalling phase
                    if currentPhase != .uninstalling {
                        Button {
                            isPresented = false
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
                }
                .padding(.horizontal, 32 * uiScale)
                .padding(.top, 24 * uiScale)
                .padding(.bottom, 16 * uiScale)
                
                Divider()
                    .padding(.horizontal, 32 * uiScale)
                
                // Content area with phase views
                ScrollView {
                    VStack(spacing: 6 * uiScale) {
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
                    }
                    .padding(.horizontal, 24 * uiScale)
                    .padding(.vertical, 12 * uiScale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom buttons bar
                if currentPhase != .loading {
                    VStack(spacing: 0) {
                        Divider()
                            .padding(.horizontal, 24 * uiScale)
                        
                        bottomButtons
                            .padding(.horizontal, 24 * uiScale)
                            .padding(.vertical, 12 * uiScale)
                    }
                    .background(
                        Color(nsColor: .controlBackgroundColor)
                            .opacity(0.8)
                            .blur(radius: 20)
                    )
                }
            }
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .frame(minWidth: 800, minHeight: 600)
        .clipShape(RoundedRectangle.standard(.large, scale: uiScale))
        .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
        .onAppear {
            Task {
                await loadApps()
            }
        }
        .uiScale(uiScale)  // Inject UI scale into environment for all child views
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 32 * uiScale) {
            Spacer()
            
            // Gradient circle with icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100 * uiScale, height: 100 * uiScale)
                
                ProgressView()
                    .controlSize(.large)
                    .tint(.blue)
            }
            
            VStack(spacing: 6 * uiScale) {
                Text("アプリ一覧を読み込み中...")
                    .font(.system(size: 24 * uiScale, weight: .bold))
                    .foregroundStyle(.primary)
                
                Text("インストール済みアプリを検索しています")
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 48 * uiScale)
    }
    
    // MARK: - Confirming View (Single or Multiple)
    private var confirmingView: some View {
        VStack(spacing: 6 * uiScale) {
            let selectedAppInfos = apps.filter { selectedApps.contains($0.bundleID) }
            
            if selectedAppInfos.count == 1, let app = selectedAppInfos.first {
                // Single app confirmation with modern card design
                Spacer()
                
                // App icon and info card
                VStack(spacing: 20 * uiScale) {
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 100 * uiScale, height: 100 * uiScale)
                            .clipShape(RoundedRectangle.standard(.extraLarge, scale: uiScale))
                            .shadow(color: .black.opacity(0.2), radius: 12 * uiScale, x: 0, y: 6 * uiScale)
                    }
                    
                    VStack(spacing: 8 * uiScale) {
                        Text(app.appName)
                            .font(.system(size: 28 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        Text(app.bundleID)
                            .font(.system(size: 13 * uiScale))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                // Warning card
                VStack(spacing: 8 * uiScale) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80 * uiScale, height: 80 * uiScale)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40 * uiScale, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    VStack(spacing: 8 * uiScale) {
                        Text("このアプリをアンインストールしますか？")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("この操作は取り消せません。")
                            .font(.system(size: 15 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24 * uiScale)
                .background(
                    RoundedRectangle.standard(.large, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle.standard(.large, scale: uiScale)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                
                // Size info card
                VStack(spacing: 6 * uiScale) {
                    HStack {
                        Text("アプリサイズ:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("ディスクイメージ:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.diskImageSize, countStyle: .file))
                            .fontWeight(.medium)
                    }
                    Divider()
                    HStack {
                        Text("削除される容量:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: app.appSize + app.diskImageSize, countStyle: .file))
                            .font(.system(size: 17 * uiScale, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(size: 15 * uiScale))
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle.standard(.regular, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .shadow(color: .black.opacity(0.05), radius: 8 * uiScale, x: 0, y: 2 * uiScale)
                
                Spacer()
                
            } else if selectedAppInfos.count > 1 {
                // Multiple apps confirmation with modern card design
                
                // Header card with summary
                VStack(spacing: 8 * uiScale) {
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.2), Color.orange.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 60 * uiScale, height: 60 * uiScale)
                            
                            Image(systemName: "trash.square.fill")
                                .font(.system(size: 28 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        VStack(alignment: .leading, spacing: 4 * uiScale) {
                            Text("\(selectedAppInfos.count) 個のアプリ")
                                .font(.system(size: 24 * uiScale, weight: .bold))
                                .foregroundStyle(.primary)
                            Text("アンインストール準備完了")
                                .font(.system(size: 14 * uiScale))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle.standard(.large, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .shadow(color: .black.opacity(0.05), radius: 8 * uiScale, x: 0, y: 2 * uiScale)
                
                // Apps list card
                VStack(alignment: .leading, spacing: 6 * uiScale) {
                    Text("選択されたアプリ")
                        .font(.system(size: 15 * uiScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4 * uiScale)
                    
                    ScrollView {
                        VStack(spacing: 8 * uiScale) {
                            ForEach(selectedAppInfos, id: \.bundleID) { app in
                                HStack(spacing: 6 * uiScale) {
                                    // App icon
                                    if let icon = app.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                            .clipShape(RoundedRectangle.standard(.medium, scale: uiScale))
                                            .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2 * uiScale)
                                    } else {
                                        RoundedRectangle.standard(.medium, scale: uiScale)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 48 * uiScale, height: 48 * uiScale)
                                            .overlay {
                                                Image(systemName: "app.dashed")
                                                    .font(.system(size: 20 * uiScale))
                                                    .foregroundStyle(.secondary)
                                            }
                                    }
                                    
                                    // App info
                                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                                        Text(app.appName)
                                            .font(.system(size: 15 * uiScale, weight: .medium))
                                            .lineLimit(1)
                                        
                                        Text(ByteCountFormatter.string(fromByteCount: app.appSize + app.diskImageSize, countStyle: .file))
                                            .font(.system(size: 13 * uiScale))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Remove button
                                    Button {
                                        removeAppFromSelection(app.bundleID)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20 * uiScale))
                                            .foregroundStyle(.secondary)
                                            .symbolRenderingMode(.hierarchical)
                                    }
                                    .buttonStyle(.plain)
                                    .help("選択を解除")
                                }
                                .padding(12 * uiScale)
                                .background(
                                    RoundedRectangle.standard(.medium, scale: uiScale)
                                        .fill(Color(nsColor: .windowBackgroundColor))
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 280 * uiScale)
                }
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle.standard(.large, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .shadow(color: .black.opacity(0.05), radius: 8 * uiScale, x: 0, y: 2 * uiScale)
                
                // Warning card
                VStack(spacing: 8 * uiScale) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 70 * uiScale, height: 70 * uiScale)
                        
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 36 * uiScale, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .symbolRenderingMode(.hierarchical)
                    }
                    
                    VStack(spacing: 8 * uiScale) {
                        Text("\(selectedAppInfos.count) 個のアプリをアンインストールしますか？")
                            .font(.system(size: 18 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                        
                        Text("この操作は取り消せません。")
                            .font(.system(size: 14 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24 * uiScale)
                .background(
                    RoundedRectangle.standard(.large, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle.standard(.large, scale: uiScale)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
                
                // Total size card
                let totalAppSize = selectedAppInfos.reduce(0) { $0 + $1.appSize }
                let totalDiskImageSize = selectedAppInfos.reduce(0) { $0 + $1.diskImageSize }
                let totalSelectedSize = totalAppSize + totalDiskImageSize
                
                VStack(spacing: 6 * uiScale) {
                    HStack {
                        Text("アプリサイズ:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalAppSize, countStyle: .file))
                            .fontWeight(.medium)
                    }
                    HStack {
                        Text("ディスクイメージ:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalDiskImageSize, countStyle: .file))
                            .fontWeight(.medium)
                    }
                    Divider()
                    HStack {
                        Text("削除される容量:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file))
                            .font(.system(size: 17 * uiScale, weight: .bold))
                            .foregroundStyle(.red)
                    }
                }
                .font(.system(size: 15 * uiScale))
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle.standard(.regular, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
                .shadow(color: .black.opacity(0.05), radius: 8 * uiScale, x: 0, y: 2 * uiScale)
                
            } else {
                Text("アプリ情報が見つかりません")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Selection View
    private var selectionView: some View {
        VStack(alignment: .leading, spacing: 6 * uiScale) {
            if apps.isEmpty {
                VStack(spacing: 6 * uiScale) {
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
                    HStack(spacing: 6 * uiScale) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 48 * uiScale, height: 48 * uiScale)
                                .clipShape(RoundedRectangle.standard(.medium, scale: uiScale))
                        } else {
                            RoundedRectangle.standard(.medium, scale: uiScale)
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
                    .padding(.vertical, 4 * uiScale)
                }
                .frame(minHeight: 350 * uiScale, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Uninstalling View
    private var uninstallingView: some View {
        VStack(spacing: 6 * uiScale) {
            // Header with gradient icon
            VStack(spacing: 20 * uiScale) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.2), Color.orange.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100 * uiScale, height: 100 * uiScale)
                    
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 48 * uiScale, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.red, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                }
                
                VStack(spacing: 8 * uiScale) {
                    Text("アンインストール中")
                        .font(.system(size: 28 * uiScale, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    if let service = uninstallerService, !service.currentStatus.isEmpty {
                        Text(service.currentStatus)
                            .font(.system(size: 15 * uiScale))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                }
                
                // Overall progress
                if let service = uninstallerService {
                    let totalItems = selectedApps.count
                    let completed = service.uninstalledApps.count + service.failedApps.count
                    let progressValue = totalItems > 0 ? Double(completed) / Double(totalItems) : 0
                    
                    VStack(spacing: 6 * uiScale) {
                        ProgressView(value: progressValue)
                            .frame(maxWidth: 500 * uiScale)
                            .tint(.red)
                        
                        HStack(spacing: 8 * uiScale) {
                            Text("\(completed) / \(totalItems) 完了")
                                .font(.system(size: 14 * uiScale, weight: .medium))
                                .foregroundStyle(.secondary)
                            
                            if progressValue == 1.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14 * uiScale))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                    .padding(20 * uiScale)
                    .background(
                        RoundedRectangle.standard(.regular, scale: uiScale)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    )
                }
            }
            
            // Uninstall log with modern cards
            ScrollView {
                VStack(spacing: 6 * uiScale) {
                    if let service = uninstallerService {
                        // Completed uninstalls
                        ForEach(service.uninstalledApps, id: \.self) { appName in
                            HStack(spacing: 6 * uiScale) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.15))
                                        .frame(width: 40 * uiScale, height: 40 * uiScale)
                                    
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20 * uiScale, weight: .semibold))
                                        .foregroundStyle(.green)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(appName)
                                        .font(.system(size: 15 * uiScale, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("アンインストール完了")
                                        .font(.system(size: 13 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16 * uiScale)
                            .background(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Currently uninstalling
                        if !service.currentStatus.isEmpty && service.currentStatus != String(localized: "完了") && 
                           !service.uninstalledApps.contains(where: { service.currentStatus.contains($0) }) {
                            HStack(spacing: 6 * uiScale) {
                                ZStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: 40 * uiScale, height: 40 * uiScale)
                                    
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.blue)
                                }
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(service.currentStatus)
                                        .font(.system(size: 15 * uiScale, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("処理中...")
                                        .font(.system(size: 13 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16 * uiScale)
                            .background(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                        }
                        
                        // Failed uninstalls
                        ForEach(service.failedApps, id: \.self) { error in
                            HStack(spacing: 6 * uiScale) {
                                ZStack {
                                    Circle()
                                        .fill(Color.red.opacity(0.15))
                                        .frame(width: 40 * uiScale, height: 40 * uiScale)
                                    
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20 * uiScale, weight: .semibold))
                                        .foregroundStyle(.red)
                                        .symbolRenderingMode(.hierarchical)
                                }
                                
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    Text(error.components(separatedBy: ":").first ?? error)
                                        .font(.system(size: 15 * uiScale, weight: .medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 13 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(16 * uiScale)
                            .background(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle.standard(.regular, scale: uiScale)
                                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
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
        ScrollView {
            VStack(spacing: 6 * uiScale) {
                resultsHeaderView
                resultsSuccessSection
                resultsFailureSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var resultsHeaderView: some View {
        let hasFailures = uninstallerService?.failedApps.isEmpty == false
        
        return VStack(spacing: 20 * uiScale) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: hasFailures ? 
                                [Color.orange.opacity(0.2), Color.yellow.opacity(0.1)] :
                                [Color.green.opacity(0.2), Color.mint.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100 * uiScale, height: 100 * uiScale)
                
                Image(systemName: hasFailures ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .font(.system(size: 48 * uiScale, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: hasFailures ? [.orange, .yellow] : [.green, .mint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .symbolRenderingMode(.hierarchical)
            }
            
            VStack(spacing: 8 * uiScale) {
                Text(hasFailures ? "一部のアプリで問題が発生しました" : "アンインストール完了")
                    .font(.system(size: 28 * uiScale, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                
                if let service = uninstallerService {
                    Text("\(service.uninstalledApps.count) 個成功" + (hasFailures ? " • \(service.failedApps.count) 個失敗" : ""))
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var resultsSuccessSection: some View {
        if let service = uninstallerService, !service.uninstalledApps.isEmpty {
            VStack(alignment: .leading, spacing: 6 * uiScale) {
                HStack(spacing: 8 * uiScale) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16 * uiScale))
                        .foregroundStyle(.green)
                    Text("アンインストール成功")
                        .font(.system(size: 16 * uiScale, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(service.uninstalledApps.count)")
                        .font(.system(size: 15 * uiScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                resultsSuccessAppsList(apps: service.uninstalledApps)
            }
            .padding(20 * uiScale)
            .background(
                RoundedRectangle.standard(.large, scale: uiScale)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle.standard(.large, scale: uiScale)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8 * uiScale, x: 0, y: 2 * uiScale)
        }
    }
    
    private func resultsSuccessAppsList(apps: [String]) -> some View {
        VStack(spacing: 8 * uiScale) {
            ForEach(apps, id: \.self) { appName in
                HStack(spacing: 6 * uiScale) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 36 * uiScale, height: 36 * uiScale)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 16 * uiScale, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2 * uiScale) {
                        Text(appName)
                            .font(.system(size: 15 * uiScale, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text("正常にアンインストールされました")
                            .font(.system(size: 12 * uiScale))
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(14 * uiScale)
                .background(
                    RoundedRectangle.standard(.medium, scale: uiScale)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
            }
        }
    }
    
    @ViewBuilder
    private var resultsFailureSection: some View {
        if let service = uninstallerService, !service.failedApps.isEmpty {
            VStack(alignment: .leading, spacing: 6 * uiScale) {
                HStack(spacing: 8 * uiScale) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16 * uiScale))
                        .foregroundStyle(.red)
                    Text("アンインストール失敗")
                        .font(.system(size: 16 * uiScale, weight: .semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(service.failedApps.count)")
                        .font(.system(size: 15 * uiScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                
                resultsFailureAppsList(errors: service.failedApps)
            }
            .padding(20 * uiScale)
            .background(
                RoundedRectangle.standard(.large, scale: uiScale)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle.standard(.large, scale: uiScale)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 8 * uiScale, x: 0, y: 2 * uiScale)
        }
    }
    
    private func resultsFailureAppsList(errors: [String]) -> some View {
        VStack(spacing: 8 * uiScale) {
            ForEach(errors, id: \.self) { error in
                HStack(spacing: 6 * uiScale) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.15))
                            .frame(width: 36 * uiScale, height: 36 * uiScale)
                        
                        Image(systemName: "xmark")
                            .font(.system(size: 16 * uiScale, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 2 * uiScale) {
                        Text(error.components(separatedBy: ":").first ?? error)
                            .font(.system(size: 15 * uiScale, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(error.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 12 * uiScale))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(14 * uiScale)
                .background(
                    RoundedRectangle.standard(.medium, scale: uiScale)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
            }
        }
    }

    
    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack {
            if currentPhase == .confirmingMultiple {
                CustomButton(
                    title: "戻る",
                    action: { currentPhase = .selection },
                    isPrimary: false,
                    uiScale: uiScale
                )
                .keyboardShortcut(.cancelAction)
            } else if currentPhase != .uninstalling {
                // Hide cancel button during uninstallation
                CustomButton(
                    title: currentPhase == .results ? "閉じる" : "キャンセル",
                    action: { isPresented = false },
                    isPrimary: false,
                    uiScale: uiScale
                )
                .keyboardShortcut(.cancelAction)
            }
            
            Spacer()
            
            if currentPhase == .confirmingSingle && !selectedApps.isEmpty {
                CustomButton(
                    title: "アンインストール",
                    action: {
                        Task {
                            await startUninstallation()
                        }
                    },
                    isPrimary: true,
                    isDestructive: true,
                    uiScale: uiScale
                )
                .keyboardShortcut(.defaultAction)
            } else if currentPhase == .confirmingMultiple && !selectedApps.isEmpty {
                CustomButton(
                    title: "アンインストール (\(selectedApps.count) 個)",
                    action: {
                        Task {
                            await startUninstallation()
                        }
                    },
                    isPrimary: true,
                    isDestructive: true,
                    uiScale: uiScale
                )
                .keyboardShortcut(.defaultAction)
            } else if currentPhase == .selection && !selectedApps.isEmpty {
                CustomButton(
                    title: "次へ",
                    action: { currentPhase = .confirmingMultiple },
                    isPrimary: true,
                    uiScale: uiScale
                )
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

    var body: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // Cache Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.2), Color.blue.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "folder.badge.minus")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("キャッシュ")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        CustomLargeButton(
                            title: "アイコンキャッシュをクリア",
                            action: {
                                settingsStore.showClearCacheConfirmation = true
                            },
                            isPrimary: false,
                            icon: "trash",
                            uiScale: uiScale
                        )
                        
                        HStack(spacing: 6 * uiScale) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.cyan)
                            Text("アプリアイコンのキャッシュをクリアします。次回起動時に再読み込みされます。")
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12 * uiScale)
                        .background(
                            RoundedRectangle.standard(.small, scale: uiScale)
                                .fill(Color.cyan.opacity(0.05))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
                
                // PlayCover Shortcuts Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.yellow.opacity(0.2), Color.orange.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("PlayCover ショートカット")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        CustomLargeButton(
                            title: "~/Applications/PlayCover を削除",
                            action: {
                                removePlayCoverShortcuts(settingsStore: settingsStore)
                            },
                            isPrimary: false,
                            icon: "trash",
                            uiScale: uiScale
                        )
                        
                        HStack(spacing: 6 * uiScale) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.yellow)
                            Text("PlayCover が作成する不要なショートカットを削除します。PlayCover.app 起動時に再作成されます。")
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12 * uiScale)
                        .background(
                            RoundedRectangle.standard(.small, scale: uiScale)
                                .fill(Color.yellow.opacity(0.05))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
                
                // Reset Card
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    // Header with icon gradient
                    HStack(spacing: 6 * uiScale) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.red.opacity(0.2), Color.orange.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40 * uiScale, height: 40 * uiScale)
                            
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 18 * uiScale, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.red, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .symbolRenderingMode(.hierarchical)
                        }
                        
                        Text("リセット")
                            .font(.system(size: 20 * uiScale, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        CustomLargeButton(
                            title: "設定をリセット",
                            action: {
                                settingsStore.showResetConfirmation = true
                            },
                            isPrimary: false,
                            isDestructive: true,
                            icon: "exclamationmark.triangle.fill",
                            uiScale: uiScale
                        )
                        
                        HStack(spacing: 6 * uiScale) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12 * uiScale))
                                .foregroundStyle(.red)
                            Text("すべての設定を初期値に戻します（ディスクイメージとアプリは削除されません）。")
                                .font(.system(size: 11 * uiScale))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12 * uiScale)
                        .background(
                            RoundedRectangle.standard(.small, scale: uiScale)
                                .fill(Color.red.opacity(0.05))
                        )
                    }
                }
                .padding(24 * uiScale)
                .liquidGlassCard(uiScale: uiScale)
                
                Spacer()
            }
            .padding(.horizontal, 24 * uiScale)
            .padding(.vertical, 20 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func clearIconCache() {
        // Icon cache is managed by LauncherService's NSCache
        // TODO: Add actual cache clearing logic here
        // For now, just show the result (handled by QuickLauncherView)
    }
    
    private func removePlayCoverShortcuts(settingsStore: SettingsStore) {
        let playCoverShortcutsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Applications/PlayCover", isDirectory: true)
        
        if FileManager.default.fileExists(atPath: playCoverShortcutsDir.path) {
            do {
                try FileManager.default.removeItem(at: playCoverShortcutsDir)
                Logger.debug("Removed PlayCover shortcuts directory: \(playCoverShortcutsDir.path)")
                settingsStore.shortcutRemovalResult = .success
            } catch {
                Logger.error("Failed to remove PlayCover shortcuts: \(error)")
                settingsStore.shortcutRemovalResult = .error(error.localizedDescription)
            }
        } else {
            settingsStore.shortcutRemovalResult = .notFound
        }
    }
}

// MARK: - About View
private struct AboutView: View {
    @Environment(\.uiScale) var uiScale
    
    private var appVersion: String {
        AppVersion.version
    }
    
    private var buildNumber: String {
        AppVersion.build
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20 * uiScale) {
                // App Icon and Name Card
                VStack(spacing: 8 * uiScale) {
                    if let icon = NSImage(named: "AppIcon") {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 100 * uiScale, height: 100 * uiScale)
                            .clipShape(RoundedRectangle.standard(.extraLarge, scale: uiScale))
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
                    RoundedRectangle.standard(.regular, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Description Card
                VStack(alignment: .leading, spacing: 6 * uiScale) {
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
                    RoundedRectangle.standard(.regular, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // System Requirements Card
                VStack(alignment: .leading, spacing: 6 * uiScale) {
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
                    RoundedRectangle.standard(.regular, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Version Details Card
                VStack(alignment: .leading, spacing: 6 * uiScale) {
                    Label("バージョン情報", systemImage: "info.circle.fill")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.cyan)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        InfoRow(label: "バージョン", value: AppVersion.version)
                        InfoRow(label: "ビルド番号", value: AppVersion.build)
                        InfoRow(label: "Swift", value: "6.2")
                        InfoRow(label: "macOS", value: "26.1 Tahoe")
                        InfoRow(label: "リリース日", value: "2025-11-13")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle.standard(.regular, scale: uiScale)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .shadow(color: .black.opacity(0.1), radius: 4 * uiScale, x: 0, y: 2)
                )
                
                // Links Card
                VStack(alignment: .leading, spacing: 6 * uiScale) {
                    Label("リンク", systemImage: "link.circle.fill")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.purple)
                    
                    Divider()
                    
                    VStack(spacing: 8 * uiScale) {
                        LinkButton(icon: "link", text: String(localized: "GitHub リポジトリ"), url: "https://github.com/HEHEX8/PlayCoverManagerGUI")
                        LinkButton(icon: "exclamationmark.bubble", text: String(localized: "問題を報告"), url: "https://github.com/HEHEX8/PlayCoverManagerGUI/issues")
                        LinkButton(icon: "doc.text", text: String(localized: "リリースノート"), url: "https://github.com/HEHEX8/PlayCoverManagerGUI/releases")
                        LinkButton(icon: "gamecontroller", text: String(localized: "PlayCover プロジェクト"), url: "https://github.com/PlayCover/PlayCover")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20 * uiScale)
                .background(
                    RoundedRectangle.standard(.regular, scale: uiScale)
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
        HStack(spacing: 6 * uiScale) {
            Image(systemName: icon)
                .font(.system(size: 20 * uiScale, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 24 * uiScale)
            Text(text)
                .font(.system(size: 15 * uiScale))
        }
    }
}

private struct InfoRow: View {
    @Environment(\.uiScale) var uiScale
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6 * uiScale) {
            Text(label)
                .font(.system(size: 14 * uiScale))
                .foregroundStyle(.secondary)
                .frame(width: 100 * uiScale, alignment: .leading)
            Text(value)
                .font(.system(size: 14 * uiScale, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
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
            HStack(spacing: 6 * uiScale) {
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
            .background(Color.blue.opacity(0.1), in: RoundedRectangle.standard(.small, scale: uiScale))
        }
        .buttonStyle(.plain)
    }
}
