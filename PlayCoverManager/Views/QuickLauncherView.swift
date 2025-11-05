import SwiftUI
import AppKit
import Observation

struct QuickLauncherView: View {
    @Bindable var viewModel: LauncherViewModel
    @Environment(SettingsStore.self) private var settingsStore
    @State private var selectedAppForDetail: PlayCoverApp?
    @State private var hasPerformedInitialAnimation = false
    @State private var showingSettings = false
    
    // iOS-style grid with fixed size icons
    private let gridColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 100), spacing: 24)
    ]
    
    // Get PlayCover.app icon (macOS app)
    private func getPlayCoverIcon() -> NSImage? {
        let playCoverPath = "/Applications/PlayCover.app"
        guard FileManager.default.fileExists(atPath: playCoverPath) else {
            return nil
        }
        // Use NSWorkspace to get the app icon (works for macOS apps)
        return NSWorkspace.shared.icon(forFile: playCoverPath)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Minimal toolbar
            HStack {
                TextField("検索", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                
                Spacer()
                
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("再読み込み")
                .keyboardShortcut("r", modifiers: [.command])
                
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/PlayCover.app"))
                } label: {
                    if let playCoverIcon = getPlayCoverIcon() {
                        Image(nsImage: playCoverIcon)
                            .resizable()
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "app.badge.checkmark")
                    }
                }
                .help("PlayCover を開く")
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Button {
                    viewModel.unmountAll(applyToPlayCoverContainer: true)
                } label: {
                    Image(systemName: "eject")
                }
                .help("すべてアンマウント")
                .keyboardShortcut(KeyEquivalent("u"), modifiers: [.command, .shift])
                
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gear")
                }
                .help("設定")
                .keyboardShortcut(",", modifiers: [.command])
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Recently launched app button (fixed at bottom)
            if let recentApp = viewModel.filteredApps.first(where: { $0.lastLaunchedFlag }) {
                let _ = print("🟣 [QuickLauncher] 前回起動アプリ検出: \(recentApp.displayName)")
                VStack(spacing: 0) {
                    // Main app grid
                    if viewModel.filteredApps.isEmpty {
                        EmptyAppListView {
                            Task { await viewModel.refresh() }
                        }
                    } else {
                        ScrollView {
                            LazyVGrid(columns: gridColumns, spacing: 32) {
                                ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element.id) { index, app in
                                    iOSAppIconView(
                                        app: app, 
                                        index: index,
                                        shouldAnimate: !hasPerformedInitialAnimation
                                    ) {
                                        // Single tap - launch
                                        viewModel.launch(app: app)
                                    } rightClickAction: {
                                        // Right click - show detail/settings
                                        selectedAppForDetail = app
                                    }
                                }
                            }
                            .padding(32)
                            .onAppear {
                                // Mark as performed after grid appears
                                // Use delay to ensure animation starts before flag is set
                                if !hasPerformedInitialAnimation {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                        hasPerformedInitialAnimation = true
                                    }
                                }
                            }
                        }
                        .background(Color(nsColor: .windowBackgroundColor))
                    }
                    
                    // Recently launched app quick launch button - Enhanced UI
                    Divider()
                    
                    Button {
                        viewModel.launch(app: recentApp)
                    } label: {
                        HStack(spacing: 16) {
                            // Icon with glow effect
                            ZStack {
                                if let icon = recentApp.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .shadow(color: .accentColor.opacity(0.3), radius: 8, x: 0, y: 2)
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.2))
                                        .frame(width: 48, height: 48)
                                        .overlay {
                                            Image(systemName: "app.fill")
                                                .font(.system(size: 24))
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            }
                            
                            // App name and action
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recentApp.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("前回起動したアプリ")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Enter key hint with accent color
                            HStack(spacing: 6) {
                                Image(systemName: "return")
                                    .font(.caption)
                                Text("Enter")
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .foregroundStyle(.accentColor)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.08),
                                Color.accentColor.opacity(0.04)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                            .frame(height: 1),
                        alignment: .top
                    )
                    .keyboardShortcut(.defaultAction)
                }
            } else {
                // No recent app - show regular grid
                if viewModel.filteredApps.isEmpty {
                    EmptyAppListView {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 32) {
                            ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element.id) { index, app in
                                iOSAppIconView(
                                    app: app, 
                                    index: index,
                                    shouldAnimate: !hasPerformedInitialAnimation
                                ) {
                                    // Single tap - launch
                                    viewModel.launch(app: app)
                                } rightClickAction: {
                                    // Right click - show detail/settings
                                    selectedAppForDetail = app
                                }
                            }
                        }
                        .padding(32)
                        .onAppear {
                            // Mark as performed after grid appears
                            // Use delay to ensure animation starts before flag is set
                            if !hasPerformedInitialAnimation {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    hasPerformedInitialAnimation = true
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: .windowBackgroundColor))
                }
            }
        }
        .sheet(item: $selectedAppForDetail) { app in
            AppDetailSheet(app: app, viewModel: viewModel)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsRootView()
        }
        .frame(minWidth: 960, minHeight: 640)
        .overlay(alignment: .center) {
            if viewModel.isBusy {
                VStack(spacing: 12) {
                    ProgressView()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(radius: 12)
            }
        }
        .alert(item: $viewModel.error) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .alert(item: $viewModel.pendingImageCreation) { app in
            Alert(title: Text("ディスクイメージが存在しません"),
                  message: Text("\(app.displayName) 用の ASIF ディスクイメージを作成しますか？"),
                  primaryButton: .default(Text("作成")) { viewModel.confirmImageCreation() },
                  secondaryButton: .cancel { viewModel.cancelImageCreation() })
        }
        .confirmationDialog("内部データが見つかりました", isPresented: Binding(
            get: { viewModel.pendingDataHandling != nil },
            set: { newValue in if !newValue { viewModel.pendingDataHandling = nil } }
        ), titleVisibility: .visible) {
            if viewModel.pendingDataHandling != nil {
                ForEach(SettingsStore.InternalDataStrategy.allCases) { strategy in
                    let title = strategy.localizedDescription + (strategy == settingsStore.defaultDataHandling ? "（既定）" : "")
                    Button(title) {
                        viewModel.applyDataHandling(strategy: strategy)
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        } message: {
            if let request = viewModel.pendingDataHandling {
                Text("\(request.app.displayName) の内部ストレージにデータが存在します。どのように処理しますか？")
            }
        }
        .task {
            if viewModel.filteredApps.isEmpty {
                await viewModel.refresh()
            }
            if viewModel.selectedApp == nil {
                viewModel.selectedApp = viewModel.filteredApps.first
            }
        }
    }
}

// iOS-style app icon with name below
private struct iOSAppIconView: View {
    let app: PlayCoverApp
    let index: Int
    let shouldAnimate: Bool
    let tapAction: () -> Void
    let rightClickAction: () -> Void
    
    @State private var isAnimating = false
    @State private var hasAppeared = false
    
    private func isAppRunning(bundleID: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == bundleID && !app.isTerminated
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // iOS-style app icon (rounded square)
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "app.dashed")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
            .overlay(alignment: .topTrailing) {
                if isAppRunning(bundleID: app.bundleIdentifier) {
                    Circle()
                        .fill(.green)
                        .frame(width: 16, height: 16)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                        .shadow(radius: 2)
                        .offset(x: 4, y: -4)
                }
            }
            .scaleEffect(isAnimating ? 0.85 : 1.0)
            .animation(
                isAnimating ? 
                    Animation.interpolatingSpring(stiffness: 300, damping: 10)
                        .repeatCount(3, autoreverses: true) :
                    .easeOut(duration: 0.2),
                value: isAnimating
            )
            
            // App name below icon
            Text(app.displayName)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 90, height: 28)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 100, height: 120)
        .contentShape(Rectangle())
        .opacity(shouldAnimate ? (hasAppeared ? 1 : 0) : 1)
        .scaleEffect(shouldAnimate ? (hasAppeared ? 1 : 0.3) : 1)
        .offset(y: shouldAnimate ? (hasAppeared ? 0 : 20) : 0)
        .onAppear {
            if shouldAnimate && !hasAppeared {
                // Staggered fade-in animation (Mac Dock style) - only on first load
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.05)) {
                    hasAppeared = true
                }
            } else {
                // No animation - just show immediately
                hasAppeared = true
            }
        }
        .onTapGesture {
            // Mac-style bounce animation on launch
            isAnimating = true
            
            // Trigger launch after brief animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                tapAction()
                
                // Stop animation after launch
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    isAnimating = false
                }
            }
        }
        .contextMenu {
            Button("起動") { 
                isAnimating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    tapAction()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        isAnimating = false
                    }
                }
            }
            Divider()
            Button("詳細と設定") { rightClickAction() }
            Divider()
            Button("Finder で表示") {
                NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
            }
            Button("アプリフォルダを開く") {
                NSWorkspace.shared.open(app.appURL.deletingLastPathComponent())
            }
        }
    }
}

// App detail and settings sheet
private struct AppDetailSheet: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with icon and info
            HStack(spacing: 16) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 80, height: 80)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let version = app.version {
                        Text("バージョン \(version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(24)
            
            Divider()
            
            // Actions
            Form {
                Section("操作") {
                    Button {
                        dismiss()
                        viewModel.launch(app: app)
                    } label: {
                        Label("アプリを起動", systemImage: "play.circle.fill")
                    }
                    
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
                    } label: {
                        Label("Finder で表示", systemImage: "folder")
                    }
                }
                
                Section("アプリ情報") {
                    LabeledContent("パス") {
                        Text(app.appURL.path)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
                
                // TODO: Add per-app settings here
                Section("設定") {
                    Text("アプリ毎の設定機能は今後実装予定")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            
            Spacer()
            
            // Footer
            HStack {
                Spacer()
                Button("閉じる") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
    }
}

private struct AppIconView: View {
    let icon: NSImage?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 40, height: 40)
        .cornerRadius(8)
    }
}

private struct EmptyAppListView: View {
    let refreshAction: () -> Void
    @State private var showingInstaller = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("インストール済みアプリがありません")
                .font(.title2)
                .foregroundStyle(.primary)
            
            VStack(spacing: 8) {
                Text("IPA ファイルをインストールすると、ここに表示されます。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("下のボタンから IPA をインストールしてください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 400)
            
            HStack(spacing: 12) {
                Button {
                    showingInstaller = true
                } label: {
                    Label("IPA をインストール", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                
                Button {
                    refreshAction()
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .sheet(isPresented: $showingInstaller) {
            IPAInstallerSheetWrapper()
        }
    }
}

// Wrapper to access Environment in sheet
private struct IPAInstallerSheetWrapper: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(LauncherViewModel.self) private var launcherViewModel
    
    var body: some View {
        IPAInstallerSheet()
            .environment(settingsStore)
            .environment(launcherViewModel)
    }
}



