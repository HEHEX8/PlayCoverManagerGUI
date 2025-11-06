import SwiftUI
import AppKit
import Observation

struct QuickLauncherView: View {
    @Bindable var viewModel: LauncherViewModel
    @Environment(SettingsStore.self) private var settingsStore
    @State private var selectedAppForDetail: PlayCoverApp?
    @State private var hasPerformedInitialAnimation = false
    @State private var showingSettings = false
    @State private var showingInstaller = false
    @State private var showingUninstaller = false
    
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
            // Enhanced toolbar with logical grouping
            HStack(spacing: 12) {
                // Search field - left aligned
                TextField("検索", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                
                Spacer()
                
                // === Frequent Actions Group ===
                // Refresh button
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("更新", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("アプリ一覧を更新 (⌘R)")
                .keyboardShortcut("r", modifiers: [.command])
                
                Divider()
                    .frame(height: 20)
                
                // === App Management Group ===
                // Install button - prominent style
                Button {
                    showingInstaller = true
                } label: {
                    Label("インストール", systemImage: "square.and.arrow.down.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderedProminent)
                .help("IPA をインストール (⌘I)")
                .keyboardShortcut("i", modifiers: [.command])
                
                // PlayCover button
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/PlayCover.app"))
                } label: {
                    if let playCoverIcon = getPlayCoverIcon() {
                        Image(nsImage: playCoverIcon)
                            .resizable()
                            .frame(width: 18, height: 18)
                    } else {
                        Image(systemName: "app.badge.checkmark")
                            .imageScale(.medium)
                    }
                }
                .buttonStyle(.borderless)
                .help("PlayCover を開く (⌘⇧P)")
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Divider()
                    .frame(height: 20)
                
                // === Destructive Actions Group ===
                // Uninstall button - warning style
                Button {
                    showingUninstaller = true
                } label: {
                    Label("削除", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .help("アプリをアンインストール (⌘D)")
                .keyboardShortcut("d", modifiers: [.command])
                
                // Unmount all button
                Button {
                    viewModel.unmountAll(applyToPlayCoverContainer: true)
                } label: {
                    Label("アンマウント", systemImage: "eject.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("すべてアンマウント (⌘⇧U)")
                .keyboardShortcut(KeyEquivalent("u"), modifiers: [.command, .shift])
                
                Divider()
                    .frame(height: 20)
                
                // === Settings ===
                // Settings button
                Button {
                    showingSettings = true
                } label: {
                    Label("設定", systemImage: "gear")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("設定 (⌘,)")
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
                                ForEach(viewModel.filteredApps) { app in
                                    let index = viewModel.filteredApps.firstIndex(of: app) ?? 0
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
                            ForEach(viewModel.filteredApps) { app in
                                let index = viewModel.filteredApps.firstIndex(of: app) ?? 0
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
        .sheet(isPresented: $showingInstaller) {
            IPAInstallerSheet()
        }
        .sheet(isPresented: $showingUninstaller) {
            AppUninstallerSheet()
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
    @State private var isPressed = false
    @State private var isCancelled = false
    @State private var shakeOffset: CGFloat = 0
    @State private var isDragging = false
    
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
            // Combined animations: press + bounce + shake
            // Use max() to ensure scale never goes below minimum threshold
            .scaleEffect(max(0.1, isPressed ? 0.92 : (isAnimating ? 0.85 : 1.0)))
            .brightness(isPressed ? -0.1 : 0)
            .offset(x: shakeOffset)
            .rotationEffect(.degrees(isCancelled ? (shakeOffset * 0.3) : 0))
            .frame(minWidth: 1, minHeight: 1) // Prevent negative geometry
            .animation(.easeOut(duration: 0.1), value: isPressed)
            .animation(
                isAnimating ? 
                    Animation.interpolatingSpring(stiffness: 300, damping: 10)
                        .repeatCount(3, autoreverses: true) :
                    .easeOut(duration: 0.2),
                value: isAnimating
            )
            .animation(.linear(duration: 0.05), value: shakeOffset)
            
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
        .scaleEffect(max(0.3, shouldAnimate ? (hasAppeared ? 1 : 0.3) : 1))
        .offset(y: shouldAnimate ? (hasAppeared ? 0 : 20) : 0)
        .frame(minWidth: 1, minHeight: 1) // Prevent negative geometry during initial animation
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
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Completely ignore all gestures during any animation
                    guard !isAnimating && !isCancelled && !isDragging else { return }
                    
                    // Mark as dragging to prevent retriggering
                    isDragging = true
                    
                    // Press down animation
                    if !isPressed {
                        isPressed = true
                    }
                }
                .onEnded { gesture in
                    // If already animating/cancelled, just reset states and ignore
                    guard isDragging else { return }
                    
                    // Mark drag as complete
                    isDragging = false
                    
                    // Ignore if currently animating or already cancelled
                    if isAnimating || isCancelled {
                        isPressed = false
                        return
                    }
                    
                    // Only check on release
                    let iconSize: CGFloat = 80
                    let tolerance: CGFloat = 20
                    let distance = max(abs(gesture.translation.width), abs(gesture.translation.height))
                    
                    // Reset press state first
                    isPressed = false
                    
                    if distance > iconSize / 2 + tolerance {
                        // Released outside bounds - "Nani yanen!" shake once
                        isCancelled = true
                        performShakeAnimation()
                    } else {
                        // Released within bounds - normal launch
                        // Smooth transition from press to bounce
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isAnimating = true
                            
                            // Trigger launch during bounce animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                tapAction()
                            }
                            
                            // Stop bounce animation after completion
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                                isAnimating = false
                            }
                        }
                    }
                }
        )
        .contextMenu {
            Button("起動") { 
                // Smooth press + bounce animation sequence
                isPressed = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isPressed = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isAnimating = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            tapAction()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                                isAnimating = false
                            }
                        }
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
    
    // "Nani yanen!" shake animation function
    private func performShakeAnimation() {
        // Ensure we're not already shaking
        guard !isCancelled else { return }
        
        // Quick shake sequence: left → right → left → right → center
        // Creates a "What the heck?!" feeling
        let shakeSequence: [CGFloat] = [-6, 6, -4, 4, -2, 2, 0]
        
        // Apply shake offsets sequentially
        for (index, offset) in shakeSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                // Only update if still in cancelled state (prevents interruption)
                guard self.isCancelled else { return }
                self.shakeOffset = offset
            }
        }
        
        // Reset cancelled state after animation completes
        let totalDuration = Double(shakeSequence.count) * 0.05 + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            // Final cleanup
            self.isCancelled = false
            self.shakeOffset = 0
            self.isDragging = false
        }
    }
}

// App detail and settings sheet with tabbed interface
private struct AppDetailSheet: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .basic
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case basic = "基本"
        case graphics = "グラフィックス"
        case controls = "コントロール"
        case advanced = "詳細"
        case info = "情報"
        
        var id: String { rawValue }
    }
    
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
                
                // Quick launch button
                Button {
                    dismiss()
                    viewModel.launch(app: app)
                } label: {
                    Label("起動", systemImage: "play.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            
            Divider()
            
            // Tab selector
            Picker("", selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            
            Divider()
            
            // Tab content
            ScrollView {
                Group {
                    switch selectedTab {
                    case .basic:
                        BasicSettingsView(app: app, viewModel: viewModel)
                    case .graphics:
                        GraphicsSettingsView(app: app)
                    case .controls:
                        ControlsSettingsView(app: app)
                    case .advanced:
                        AdvancedSettingsView(app: app)
                    case .info:
                        InfoView(app: app)
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // Footer
            HStack {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
                } label: {
                    Label("Finder で表示", systemImage: "folder")
                }
                
                Spacer()
                
                Button("閉じる") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 700, height: 600)
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

// MARK: - Basic Settings Tab

private struct BasicSettingsView: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @Environment(SettingsStore.self) private var settingsStore
    
    @State private var nobrowseOverride: NobrowseOverride = .useGlobal
    @State private var dataHandlingOverride: DataHandlingOverride = .useGlobal
    
    enum NobrowseOverride: String, CaseIterable, Identifiable {
        case useGlobal = "グローバル設定を使用"
        case enabled = "有効"
        case disabled = "無効"
        
        var id: String { rawValue }
    }
    
    enum DataHandlingOverride: String, CaseIterable, Identifiable {
        case useGlobal = "グローバル設定を使用"
        case discard = "内部データを破棄"
        case mergeThenDelete = "内部データを統合"
        case leave = "何もしない"
        
        var id: String { rawValue }
        
        var strategy: SettingsStore.InternalDataStrategy? {
            switch self {
            case .useGlobal: return nil
            case .discard: return .discard
            case .mergeThenDelete: return .mergeThenDelete
            case .leave: return .leave
            }
        }
        
        static func from(strategy: SettingsStore.InternalDataStrategy?) -> DataHandlingOverride {
            guard let strategy = strategy else { return .useGlobal }
            switch strategy {
            case .discard: return .discard
            case .mergeThenDelete: return .mergeThenDelete
            case .leave: return .leave
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("基本設定")
                .font(.headline)
            
            // Nobrowse setting
            VStack(alignment: .leading, spacing: 8) {
                Text("Finder に表示しない (nobrowse)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $nobrowseOverride) {
                    ForEach(NobrowseOverride.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: nobrowseOverride) { _, newValue in
                    saveNobrowseSetting(newValue)
                }
                
                Text("このアプリのディスクイメージを Finder で非表示にするかどうかを設定します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if nobrowseOverride == .useGlobal {
                    Text("現在のグローバル設定: \(settingsStore.nobrowseEnabled ? "有効" : "無効")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Data handling strategy
            VStack(alignment: .leading, spacing: 8) {
                Text("内部データ処理方法")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $dataHandlingOverride) {
                    ForEach(DataHandlingOverride.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: dataHandlingOverride) { _, newValue in
                    saveDataHandlingSetting(newValue)
                }
                
                Text("起動時に内部データが見つかった場合の処理方法を設定します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if dataHandlingOverride == .useGlobal {
                    Text("現在のグローバル設定: \(settingsStore.defaultDataHandling.localizedDescription)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Reset button
            Button(role: .destructive) {
                resetToGlobalDefaults()
            } label: {
                Label("グローバル設定に戻す", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        let perAppSettings = viewModel.getPerAppSettings()
        let settings = perAppSettings.getSettings(for: app.bundleIdentifier)
        
        // Load nobrowse setting
        if let nobrowse = settings.nobrowseEnabled {
            nobrowseOverride = nobrowse ? .enabled : .disabled
        } else {
            nobrowseOverride = .useGlobal
        }
        
        // Load data handling strategy
        if let strategyRaw = settings.dataHandlingStrategy,
           let strategy = SettingsStore.InternalDataStrategy(rawValue: strategyRaw) {
            dataHandlingOverride = DataHandlingOverride.from(strategy: strategy)
        } else {
            dataHandlingOverride = .useGlobal
        }
    }
    
    private func saveNobrowseSetting(_ override: NobrowseOverride) {
        let perAppSettings = viewModel.getPerAppSettings()
        switch override {
        case .useGlobal:
            perAppSettings.setNobrowse(nil, for: app.bundleIdentifier)
        case .enabled:
            perAppSettings.setNobrowse(true, for: app.bundleIdentifier)
        case .disabled:
            perAppSettings.setNobrowse(false, for: app.bundleIdentifier)
        }
    }
    
    private func saveDataHandlingSetting(_ override: DataHandlingOverride) {
        let perAppSettings = viewModel.getPerAppSettings()
        perAppSettings.setDataHandlingStrategy(override.strategy, for: app.bundleIdentifier)
    }
    
    private func resetToGlobalDefaults() {
        let perAppSettings = viewModel.getPerAppSettings()
        perAppSettings.removeSettings(for: app.bundleIdentifier)
        nobrowseOverride = .useGlobal
        dataHandlingOverride = .useGlobal
    }
}

// MARK: - Graphics Settings Tab

private struct GraphicsSettingsView: View {
    let app: PlayCoverApp
    @State private var settings: PlayCoverAppSettings
    
    init(app: PlayCoverApp) {
        self.app = app
        self._settings = State(initialValue: PlayCoverAppSettingsStore.load(for: app.bundleIdentifier))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("グラフィックス設定")
                .font(.headline)
            
            // iOS Device Model
            VStack(alignment: .leading, spacing: 8) {
                Text("iOS デバイスモデル")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $settings.iosDeviceModel) {
                    ForEach(PlayCoverAppSettings.IOSDeviceModel.allCases) { model in
                        VStack(alignment: .leading) {
                            Text(model.displayName)
                            Text(model.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(model.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.iosDeviceModel) { _, _ in saveSettings() }
                
                if let model = PlayCoverAppSettings.IOSDeviceModel(rawValue: settings.iosDeviceModel) {
                    Text(model.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Resolution
            VStack(alignment: .leading, spacing: 8) {
                Text("解像度")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $settings.resolution) {
                    ForEach(PlayCoverAppSettings.Resolution.allCases) { resolution in
                        Text(resolution.displayName).tag(resolution.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: settings.resolution) { _, _ in saveSettings() }
                
                // Custom resolution fields
                if settings.resolution == PlayCoverAppSettings.Resolution.custom.rawValue {
                    HStack {
                        TextField("幅", value: $settings.windowWidth, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: settings.windowWidth) { _, _ in saveSettings() }
                        
                        Text("×")
                        
                        TextField("高さ", value: $settings.windowHeight, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                            .onChange(of: settings.windowHeight) { _, _ in saveSettings() }
                    }
                }
            }
            
            Divider()
            
            // Aspect Ratio
            VStack(alignment: .leading, spacing: 8) {
                Text("アスペクト比")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $settings.aspectRatio) {
                    ForEach(PlayCoverAppSettings.AspectRatio.allCases) { ratio in
                        Text(ratio.displayName).tag(ratio.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.aspectRatio) { _, _ in saveSettings() }
            }
            
            Divider()
            
            // Display Options
            VStack(alignment: .leading, spacing: 8) {
                Text("表示オプション")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Toggle("ノッチを表示", isOn: $settings.notch)
                    .onChange(of: settings.notch) { _, _ in saveSettings() }
                
                Toggle("タイトルバーを非表示", isOn: $settings.hideTitleBar)
                    .onChange(of: settings.hideTitleBar) { _, _ in saveSettings() }
                
                Toggle("フローティングウィンドウ", isOn: $settings.floatingWindow)
                    .onChange(of: settings.floatingWindow) { _, _ in saveSettings() }
                
                Toggle("Metal HUD を表示", isOn: $settings.metalHUD)
                    .onChange(of: settings.metalHUD) { _, _ in saveSettings() }
            }
            
            Divider()
            
            // Display Sleep
            Toggle("ディスプレイスリープを無効化", isOn: $settings.disableTimeout)
                .onChange(of: settings.disableTimeout) { _, _ in saveSettings() }
            
            Text("アプリ実行中にディスプレイが自動的にスリープするのを防ぎます。")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func saveSettings() {
        try? PlayCoverAppSettingsStore.save(settings, for: app.bundleIdentifier)
    }
}

// MARK: - Controls Settings Tab

private struct ControlsSettingsView: View {
    let app: PlayCoverApp
    @State private var settings: PlayCoverAppSettings
    
    init(app: PlayCoverApp) {
        self.app = app
        self._settings = State(initialValue: PlayCoverAppSettingsStore.load(for: app.bundleIdentifier))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("コントロール設定")
                .font(.headline)
            
            // Keymapping
            VStack(alignment: .leading, spacing: 8) {
                Toggle("キーマッピングを有効化", isOn: $settings.keymapping)
                    .onChange(of: settings.keymapping) { _, _ in saveSettings() }
                
                Text("画面上のタッチ操作をキーボード/マウスに割り当てます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Mouse Sensitivity
            VStack(alignment: .leading, spacing: 8) {
                Text("マウス感度: \(Int(settings.sensitivity))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Slider(value: $settings.sensitivity, in: 0...100, step: 1)
                    .onChange(of: settings.sensitivity) { _, _ in saveSettings() }
                
                Text("マウスカーソルの移動速度を調整します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Input Options
            VStack(alignment: .leading, spacing: 8) {
                Text("入力オプション")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Toggle("テキスト入力時にキーマッピングを無効化", isOn: $settings.noKMOnInput)
                    .onChange(of: settings.noKMOnInput) { _, _ in saveSettings() }
                
                Toggle("スクロールホイールを有効化", isOn: $settings.enableScrollWheel)
                    .onChange(of: settings.enableScrollWheel) { _, _ in saveSettings() }
                
                Toggle("内蔵マウスを無効化", isOn: $settings.disableBuiltinMouse)
                    .onChange(of: settings.disableBuiltinMouse) { _, _ in saveSettings() }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func saveSettings() {
        try? PlayCoverAppSettingsStore.save(settings, for: app.bundleIdentifier)
    }
}

// MARK: - Advanced Settings Tab

private struct AdvancedSettingsView: View {
    let app: PlayCoverApp
    @State private var settings: PlayCoverAppSettings
    
    init(app: PlayCoverApp) {
        self.app = app
        self._settings = State(initialValue: PlayCoverAppSettingsStore.load(for: app.bundleIdentifier))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("詳細設定")
                .font(.headline)
            
            // PlayChain
            VStack(alignment: .leading, spacing: 8) {
                Toggle("PlayChain を有効化", isOn: $settings.playChain)
                    .onChange(of: settings.playChain) { _, _ in saveSettings() }
                
                Text("PlayCover の実行時パッチ機能を有効にします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if settings.playChain {
                    Toggle("PlayChain デバッグモード", isOn: $settings.playChainDebugging)
                        .onChange(of: settings.playChainDebugging) { _, _ in saveSettings() }
                        .padding(.leading)
                }
            }
            
            Divider()
            
            // Bypass
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Jailbreak 検出回避", isOn: $settings.bypass)
                    .onChange(of: settings.bypass) { _, _ in saveSettings() }
                
                Text("一部のアプリで必要な jailbreak 検出を回避します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Window Fix Method
            VStack(alignment: .leading, spacing: 8) {
                Text("ウィンドウ修正方法")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $settings.windowFixMethod) {
                    ForEach(PlayCoverAppSettings.WindowFixMethod.allCases) { method in
                        Text(method.displayName).tag(method.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.windowFixMethod) { _, _ in saveSettings() }
                
                Text("ウィンドウ表示の問題を修正します。動作しない場合は別の方法を試してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Other Advanced Options
            VStack(alignment: .leading, spacing: 8) {
                Text("その他のオプション")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Toggle("作業ディレクトリをルートに設定", isOn: $settings.rootWorkDir)
                    .onChange(of: settings.rootWorkDir) { _, _ in saveSettings() }
                
                Toggle("画面値を反転", isOn: $settings.inverseScreenValues)
                    .onChange(of: settings.inverseScreenValues) { _, _ in saveSettings() }
                
                Toggle("Introspection を注入", isOn: $settings.injectIntrospection)
                    .onChange(of: settings.injectIntrospection) { _, _ in saveSettings() }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func saveSettings() {
        try? PlayCoverAppSettingsStore.save(settings, for: app.bundleIdentifier)
    }
}

// MARK: - Info Tab

private struct InfoView: View {
    let app: PlayCoverApp
    @State private var settings: PlayCoverAppSettings
    
    init(app: PlayCoverApp) {
        self.app = app
        self._settings = State(initialValue: PlayCoverAppSettingsStore.load(for: app.bundleIdentifier))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("アプリ情報")
                .font(.headline)
            
            Form {
                LabeledContent("Bundle ID") {
                    Text(app.bundleIdentifier)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                if let version = app.version {
                    LabeledContent("バージョン") {
                        Text(version)
                            .textSelection(.enabled)
                    }
                }
                
                LabeledContent("パス") {
                    Text(app.appURL.path)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                
                Divider()
                
                LabeledContent("設定バージョン") {
                    Text(settings.version)
                        .textSelection(.enabled)
                }
                
                if PlayCoverAppSettingsStore.exists(for: app.bundleIdentifier) {
                    LabeledContent("設定ファイル") {
                        Button("Finder で表示") {
                            let url = PlayCoverAppSettingsStore.settingsURL(for: app.bundleIdentifier)
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        }
                        .buttonStyle(.link)
                    }
                } else {
                    LabeledContent("設定ファイル") {
                        Text("未作成（デフォルト値を使用中）")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
