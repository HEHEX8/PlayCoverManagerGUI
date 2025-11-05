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
                    
                    // Recently launched app quick launch button with ripple effect
                    Divider()
                    
                    RecentAppLaunchButton(
                        app: recentApp,
                        onLaunch: {
                            // Launch app first
                            viewModel.launch(app: recentApp)
                            
                            // Trigger animation on the grid icon after a brief delay
                            // to ensure the observer is set up
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("TriggerAppIconAnimation"),
                                    object: nil,
                                    userInfo: ["bundleID": recentApp.bundleIdentifier]
                                )
                            }
                        }
                    )
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
            // Only show status overlay for time-consuming operations (disk image creation, data handling, unmount)
            if viewModel.isBusy && viewModel.isShowingStatus {
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
                if app.isRunning {
                    // Running indicator - adaptive for light/dark mode
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                        Circle()
                            .strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2.5)
                            .frame(width: 14, height: 14)
                    }
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                    .offset(x: 6, y: -6)
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerAppIconAnimation"))) { notification in
            // Trigger animation when receiving notification for this app
            if let bundleID = notification.userInfo?["bundleID"] as? String,
               bundleID == app.bundleIdentifier {
                // Delay animation slightly to sync with button animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isAnimating = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        isAnimating = false
                    }
                }
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

// Recent app launch button with ripple effect
private struct RecentAppLaunchButton: View {
    let app: PlayCoverApp
    let onLaunch: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        Button {
            // Start animation and launch immediately in parallel
            isAnimating = true
            onLaunch()
            
            // Stop animation after completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                isAnimating = false
            }
        } label: {
            HStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 16) {
                    // Icon (no animation here)
                    ZStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                        } else {
                            RoundedRectangle(cornerRadius: 11)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.tertiary)
                                }
                        }
                    }
                    
                    // App info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("前回起動したアプリ")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Enter key hint
                    HStack(spacing: 5) {
                        Image(systemName: "return")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Enter")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            ZStack {
                // Base background
                Color(nsColor: .controlBackgroundColor).opacity(0.5)
                
                // Ripple effect
                if isAnimating {
                    RippleEffect()
                }
            }
        )
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
        .keyboardShortcut(.defaultAction)
    }
}

// Ripple effect animation
private struct RippleEffect: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.6
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.primary.opacity(opacity),
                        Color.primary.opacity(opacity * 0.5),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    scale = 3.0
                    opacity = 0.0
                }
            }
    }
}



