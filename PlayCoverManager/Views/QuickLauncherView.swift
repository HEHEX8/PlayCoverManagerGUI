import SwiftUI
import AppKit
import Observation

// Wrapper to make String Identifiable for .sheet(item:) usage
struct IdentifiableString: Identifiable {
    let id: String
    
    init(_ string: String) {
        self.id = string
    }
}

struct QuickLauncherView: View {
    @Bindable var viewModel: LauncherViewModel
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedAppForDetail: PlayCoverApp?
    @State private var hasPerformedInitialAnimation = false
    @State private var showingSettings = false
    @State private var showingInstaller = false
    @State private var showingUninstaller = false  // For general uninstall (from drawer)
    @State private var selectedAppForUninstall: IdentifiableString? = nil  // For pre-selected uninstall (from context menu)
    @State private var isDrawerOpen = false
    @State private var previousUnmountFlowState: LauncherViewModel.UnmountFlowState = .idle
    
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
                // Simplified toolbar with only search and main actions
                HStack(spacing: 16) {
                    // Hamburger menu button to toggle drawer
                    Button {
                        print("[QuickLauncher] Hamburger button tapped, current state: \(isDrawerOpen)")
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isDrawerOpen.toggle()
                        }
                        print("[QuickLauncher] After toggle, new state: \(isDrawerOpen)")
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .help("メニュー")
                    
                    // Search field - left aligned
                    // Disable when drawer is open to prevent interference
                    TextField("検索", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                        .disabled(isDrawerOpen)
                    
                    Spacer()
                    
                    // Large refresh button - subtle style
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label("再読み込み", systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("アプリ一覧を更新 (⌘R)")
                    .keyboardShortcut("r", modifiers: [.command])
                    
                    // Large unmount button - subtle style
                    Button {
                        viewModel.unmountAll(applyToPlayCoverContainer: true)
                    } label: {
                        Label("すべてアンマウント", systemImage: "eject.fill")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .help("すべてアンマウント (⌘⇧U)")
                    .keyboardShortcut(KeyEquivalent("u"), modifiers: [.command, .shift])
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
                        EmptyAppListView(searchText: viewModel.searchText) {
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
                                    } uninstallAction: {
                                        // Uninstall action - open uninstaller with pre-selected app
                                        selectedAppForUninstall = IdentifiableString(app.bundleIdentifier)
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
                    EmptyAppListView(searchText: viewModel.searchText) {
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
                                } uninstallAction: {
                                    // Uninstall action - open uninstaller with pre-selected app
                                    selectedAppForUninstall = IdentifiableString(app.bundleIdentifier)
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
            .interactiveDismissDisabled(false)
            .onAppear { print("[QuickLauncher] Settings sheet appeared") }
            .onDisappear { print("[QuickLauncher] Settings sheet disappeared") }
    }
    .sheet(isPresented: $showingInstaller) {
        IPAInstallerSheet()
            .onAppear { print("[QuickLauncher] Installer sheet appeared") }
            .onDisappear { print("[QuickLauncher] Installer sheet disappeared") }
    }
    .sheet(item: $selectedAppForUninstall) { identifiableString in
        AppUninstallerSheet(preSelectedBundleID: identifiableString.id)
            .onAppear { print("[QuickLauncher] Uninstaller sheet (preselected) appeared") }
            .onDisappear { print("[QuickLauncher] Uninstaller sheet (preselected) disappeared") }
    }
    .sheet(isPresented: $showingUninstaller) {
        AppUninstallerSheet(preSelectedBundleID: nil)
            .onAppear { print("[QuickLauncher] Uninstaller sheet (general) appeared") }
            .onDisappear { print("[QuickLauncher] Uninstaller sheet (general) disappeared") }
    }
    .frame(minWidth: 960, minHeight: 640)
    .overlay(alignment: .center) {
        // Unmount flow overlay (confirmation, progress, result, error)
        if viewModel.unmountFlowState != .idle {
            ZStack {
                // Background overlay - blocks interaction but doesn't close on tap
                // User must use buttons in the dialog
                Color.black.opacity(0.3)
                    .contentShape(Rectangle())  // Capture all tap events
                    .ignoresSafeArea()
                
                UnmountOverlayView(viewModel: viewModel)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .zIndex(998)  // Just below drawer (999), above regular content
        }
        // Regular status overlay for other time-consuming operations
        else if viewModel.isBusy && viewModel.isShowingStatus {
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
        
        // Set up storage change completion callback
        viewModel.onStorageChangeCompleted = { [weak appViewModel] in
            print("[QuickLauncher] Storage change completed, showing wizard")
            appViewModel?.completeStorageLocationChange()
        }
    }
    .onChange(of: isDrawerOpen) { oldValue, newValue in
        print("[QuickLauncher] Drawer state changed: \(oldValue) -> \(newValue)")
    }
    .onChange(of: showingSettings) { oldValue, newValue in
        print("[QuickLauncher] showingSettings changed: \(oldValue) -> \(newValue)")
    }
    .onChange(of: showingInstaller) { oldValue, newValue in
        print("[QuickLauncher] showingInstaller changed: \(oldValue) -> \(newValue)")
    }
    .onChange(of: showingUninstaller) { oldValue, newValue in
        print("[QuickLauncher] showingUninstaller changed: \(oldValue) -> \(newValue)")
    }
    .onChange(of: viewModel.unmountFlowState) { oldValue, newValue in
        print("[QuickLauncher] unmountFlowState changed: \(oldValue) -> \(newValue)")
        
        // Handle storage change flow completion
        // When unmount completes successfully during storage change, trigger wizard
        if case .storageChangeConfirming = previousUnmountFlowState,
           case .success = newValue {
            // User completed unmount for storage change
            // Dismiss success overlay and show storage wizard
            print("[QuickLauncher] Storage change unmount completed, showing wizard after delay")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                viewModel.unmountFlowState = .idle
                appViewModel.completeStorageLocationChange()
            }
        }
        
        previousUnmountFlowState = newValue
    }
    .overlay {
        // Left drawer overlay - full screen when open
        if isDrawerOpen {
            ZStack(alignment: .leading) {
                // Background overlay - tap to close
                // Use contentShape to ensure entire area is tappable
                Color.black.opacity(0.3)
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        print("[QuickLauncher] Background tapped, closing drawer")
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isDrawerOpen = false
                        }
                    }
                
                // Drawer content
                DrawerPanel(
                    showingSettings: $showingSettings,
                    showingInstaller: $showingInstaller,
                    showingUninstaller: $showingUninstaller,
                    getPlayCoverIcon: getPlayCoverIcon,
                    isOpen: $isDrawerOpen
                )
                .transition(.move(edge: .leading))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(999)  // Ensure drawer overlay is above all other content
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
    let uninstallAction: () -> Void
    
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
                    guard !isAnimating && !isCancelled else { return }
                    
                    // Press down animation (only once per drag)
                    if !isPressed && !isDragging {
                        isPressed = true
                        isDragging = true
                    }
                }
                .onEnded { gesture in
                    // Must have started a drag to process end
                    guard isDragging else { return }
                    
                    // Reset drag state immediately
                    isDragging = false
                    
                    // Ignore if currently animating or already cancelled
                    guard !isAnimating && !isCancelled else {
                        isPressed = false
                        return
                    }
                    
                    // Calculate drag distance
                    let iconSize: CGFloat = 80
                    let tolerance: CGFloat = 20
                    let distance = max(abs(gesture.translation.width), abs(gesture.translation.height))
                    
                    // Reset press state
                    isPressed = false
                    
                    if distance > iconSize / 2 + tolerance {
                        // Released outside bounds - perform shake animation
                        performShakeAnimation()
                    } else {
                        // Released within bounds - normal launch
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
            Divider()
            Button("アンインストール", role: .destructive) {
                uninstallAction()
            }
            .foregroundStyle(.red)
        }
    }
    
    // "Nani yanen!" shake animation function
    private func performShakeAnimation() {
        // Prevent re-entry if already shaking
        guard !isCancelled else { return }
        
        // Set cancelled state to block new gestures
        isCancelled = true
        
        // Quick shake sequence: left → right → left → right → center
        let shakeSequence: [CGFloat] = [-6, 6, -4, 4, -2, 2, 0]
        
        // Apply shake offsets sequentially
        for (index, offset) in shakeSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                self.shakeOffset = offset
            }
        }
        
        // Reset all states after animation completes
        let totalDuration = Double(shakeSequence.count) * 0.05 + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) {
            self.isCancelled = false
            self.shakeOffset = 0
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
                        .lineLimit(2)
                    
                    if let version = app.version {
                        Text("バージョン \(version)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(app.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
    let searchText: String
    let refreshAction: () -> Void
    @State private var showingInstaller = false
    
    // Check if this is a search result empty state or truly no apps
    private var isSearchEmpty: Bool {
        !searchText.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isSearchEmpty ? "magnifyingglass" : "tray")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text(isSearchEmpty ? "検索結果が見つかりません" : "インストール済みアプリがありません")
                .font(.title2)
                .foregroundStyle(.primary)
            
            if isSearchEmpty {
                // Search empty state
                VStack(spacing: 8) {
                    Text("\"\(searchText)\" に一致するアプリが見つかりませんでした。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("別のキーワードで検索してみてください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 400)
            } else {
                // No apps installed state
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

// Recent app launch button with rich animations
private struct RecentAppLaunchButton: View {
    let app: PlayCoverApp
    let onLaunch: () -> Void
    
    @State private var rippleTrigger = 0
    
    // Current icon states
    @State private var iconOffsetY: CGFloat = 0
    @State private var iconOffsetX: CGFloat = 0
    @State private var iconScale: CGFloat = 1.0
    
    // Old icon states (for transition)
    @State private var oldIcon: NSImage? = nil
    @State private var oldIconOffsetY: CGFloat = 0
    @State private var oldIconOffsetX: CGFloat = 0
    @State private var oldIconScale: CGFloat = 1.0
    @State private var oldIconOpacity: Double = 0.0
    
    @State private var textOpacity: Double = 1.0
    @State private var previousAppID: String = ""
    @State private var currentIcon: NSImage? = nil  // Track current icon to detect changes
    @State private var displayedTitle: String = ""  // Title being displayed (may differ from app.displayName during transition)
    
    var body: some View {
        Button {
            // Bounce up and drop animation for existing icon
            performIconBounce()
            
            onLaunch()
        } label: {
            HStack(spacing: 0) {
                Spacer()
                
                HStack(spacing: 16) {
                    // Icon with animations - ZStack layers old icon, ripple, and new icon
                    ZStack {
                        // Old icon (during transition) - bottom layer
                        if let oldIcon = oldIcon {
                            Image(nsImage: oldIcon)
                                .resizable()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                                .offset(x: oldIconOffsetX, y: oldIconOffsetY)
                                .scaleEffect(oldIconScale)
                                .opacity(oldIconOpacity)
                        }
                        
                        // Ripple effect - middle layer, centered on icon
                        RippleEffect(trigger: rippleTrigger)
                            .frame(width: 52, height: 52)
                        
                        // Current icon - top layer
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 52, height: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 11))
                                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
                                .offset(x: iconOffsetX, y: iconOffsetY)
                                .scaleEffect(iconScale)
                        } else {
                            RoundedRectangle(cornerRadius: 11)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .frame(width: 52, height: 52)
                                .overlay {
                                    Image(systemName: "app.fill")
                                        .font(.system(size: 26))
                                        .foregroundStyle(.tertiary)
                                }
                                .offset(x: iconOffsetX, y: iconOffsetY)
                                .scaleEffect(iconScale)
                        }
                    }
                    .frame(width: 52, height: 52)
                    
                    // App info with fade transition
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayedTitle)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Text("前回起動したアプリ")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .opacity(textOpacity)
                    .animation(.easeInOut(duration: 0.3), value: displayedTitle)  // Animate layout when title length changes
                    
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
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipped() // Clip all content (icon motion + ripple) to button bounds
        .overlay(
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1),
            alignment: .top
        )
        .keyboardShortcut(.defaultAction)
        .onChange(of: app.bundleIdentifier) { oldValue, newValue in
            // Detect app change and trigger rich transition
            if !oldValue.isEmpty && oldValue != newValue {
                // Save CURRENT displayed icon as old icon (before it updates)
                oldIcon = currentIcon
                performAppSwitchAnimation()
            }
            previousAppID = newValue
            // Update current icon after animation starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                currentIcon = app.icon
            }
        }
        .onAppear {
            previousAppID = app.bundleIdentifier
            currentIcon = app.icon
            displayedTitle = app.displayName
        }
    }
    
    // Bounce up and drop animation for button press
    private func performIconBounce() {
        // Jump up
        withAnimation(.easeOut(duration: 0.15)) {
            iconOffsetY = -60
            iconScale = 1.1
        }
        
        // Fall down with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 12)) {
                iconOffsetY = 0
                iconScale = 1.0
            }
        }
        
        // Trigger ripple on landing at icon position
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            rippleTrigger += 1
        }
    }
    
    // App switch animation - new icon drops and collides with old one
    private func performAppSwitchAnimation() {
        // Reset old icon state (oldIcon already saved in onChange)
        oldIconOffsetX = 0
        oldIconOffsetY = 0
        oldIconScale = 1.0
        oldIconOpacity = 1.0  // Old icon is visible and stays in place
        
        // New icon starts from above
        iconOffsetY = -150
        iconOffsetX = 0
        iconScale = 1.2
        
        // Text stays visible (shows OLD title during animation)
        textOpacity = 1.0
        
        // Drop new icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.3)) {
                iconOffsetY = 0  // Falls to collision point
            }
            
            // COLLISION! Both icons react
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // New icon squashes
                withAnimation(.easeOut(duration: 0.1)) {
                    iconScale = 0.95
                }
                
                // Old icon gets pushed down and flies away
                withAnimation(.easeOut(duration: 0.35)) {
                    oldIconOffsetY = 120  // Pushed down
                    oldIconScale = 0.6
                    oldIconOpacity = 0.0
                }
                
                // New icon bounces back
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                        iconScale = 1.0
                    }
                }
                
                // After new icon lands (0.45s), update title
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    // Fade out old title
                    withAnimation(.easeOut(duration: 0.2)) {
                        textOpacity = 0.0
                    }
                    
                    // Update displayed title while faded out (triggers layout animation)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            displayedTitle = app.displayName
                        }
                        
                        // Fade in new title after layout settles
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeIn(duration: 0.25)) {
                                textOpacity = 1.0
                            }
                        }
                    }
                    
                    // Clean up old icon
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        oldIcon = nil
                    }
                }
            }
        }
    }
}

// 3D-style ripple effect animation
private struct RippleEffect: View {
    let trigger: Int
    @State private var ripples: [Ripple] = []
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            ForEach(ripples) { ripple in
                RippleLayer(ripple: ripple, colorScheme: colorScheme)
            }
        }
        .onChange(of: trigger) { _, _ in
            createNewRipple()
        }
    }
    
    private func createNewRipple() {
        let newRipple = Ripple(id: UUID())
        ripples.append(newRipple)
        
        // Animate the ripple
        withAnimation(.easeOut(duration: 1.0)) {
            if let index = ripples.firstIndex(where: { $0.id == newRipple.id }) {
                ripples[index].scale = 10.0
                ripples[index].opacity = 0.0
            }
        }
        
        // Remove after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ripples.removeAll(where: { $0.id == newRipple.id })
        }
    }
    
    fileprivate struct Ripple: Identifiable {
        let id: UUID
        var scale: CGFloat = 0.0
        var opacity: Double = 1.0
    }
}

// Individual ripple layer view
private struct RippleLayer: View {
    let ripple: RippleEffect.Ripple
    let colorScheme: ColorScheme
    
    // Color based on theme: white for dark, blue for light
    private var rippleColor: Color {
        colorScheme == .dark ? .white : .blue
    }
    
    var body: some View {
        ZStack {
            // Outer glow layer (largest, most blurred)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            rippleColor.opacity(ripple.opacity * 0.3),
                            rippleColor.opacity(ripple.opacity * 0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .scaleEffect(ripple.scale * 1.05)
                .blur(radius: 8)
                .opacity(ripple.opacity)
            
            // Middle layer with stronger color
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            rippleColor.opacity(ripple.opacity * 0.5),
                            rippleColor.opacity(ripple.opacity * 0.25),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 80
                    )
                )
                .scaleEffect(ripple.scale)
                .blur(radius: 4)
                .opacity(ripple.opacity)
            
            // Sharp ring layer (main visible ring)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            rippleColor.opacity(ripple.opacity * 0.8),
                            rippleColor.opacity(ripple.opacity * 0.6),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .scaleEffect(ripple.scale)
                .opacity(ripple.opacity)
                .shadow(color: rippleColor.opacity(ripple.opacity * 0.5), radius: 6, x: 0, y: 2)
            
            // Inner glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            rippleColor.opacity(ripple.opacity * 0.6),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .scaleEffect(ripple.scale * 0.3)
                .blur(radius: 10)
                .opacity(ripple.opacity)
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
                        .lineLimit(3)
                        .truncationMode(.middle)
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
                        .lineLimit(3)
                        .truncationMode(.middle)
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

// MARK: - Drawer Panel

private struct DrawerPanel: View {
    @Binding var showingSettings: Bool
    @Binding var showingInstaller: Bool
    @Binding var showingUninstaller: Bool
    let getPlayCoverIcon: () -> NSImage?
    @Binding var isOpen: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("メニュー")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 20)
            
                // PlayCover.app button
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/PlayCover.app"))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        if let playCoverIcon = getPlayCoverIcon() {
                            Image(nsImage: playCoverIcon)
                                .resizable()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                        } else {
                            Image(systemName: "app.badge.checkmark")
                                .font(.system(size: 20))
                                .foregroundStyle(.secondary)
                                .frame(width: 32, height: 32)
                        }
                        Text("PlayCover.app")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("PlayCover を開く (⌘⇧P)")
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Divider()
                    .padding(.leading, 16)
                
                // Install button
                Button {
                    print("[DrawerPanel] Install button tapped")
                    showingInstaller = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                    print("[DrawerPanel] Drawer closed, showingInstaller: \(showingInstaller)")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                            .frame(width: 32, height: 32)
                        Text("IPA をインストール")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("IPA をインストール (⌘I)")
                .keyboardShortcut("i", modifiers: [.command])
                
                // Uninstall button
                Button {
                    print("[DrawerPanel] Uninstall button tapped")
                    showingUninstaller = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                    print("[DrawerPanel] Drawer closed, showingUninstaller: \(showingUninstaller)")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                        Text("アプリをアンインストール")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("アプリをアンインストール (⌘D)")
                .keyboardShortcut("d", modifiers: [.command])
                
                Divider()
                    .padding(.leading, 16)
                
                // Settings button
                Button {
                    print("[DrawerPanel] Settings button tapped")
                    showingSettings = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                    print("[DrawerPanel] Drawer closed, showingSettings: \(showingSettings)")
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                        Text("設定")
                            .font(.body)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("設定 (⌘,)")
                .keyboardShortcut(",", modifiers: [.command])
            
                Spacer()
            }
        }
        .frame(width: 260)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 10, x: 2, y: 0)
    }
}
