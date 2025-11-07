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
    @State private var refreshRotation: Double = 0  // For refresh button rotation animation
    @State private var focusedAppIndex: Int?  // For keyboard navigation
    @FocusState private var isSearchFieldFocused: Bool  // Track if search field has focus
    @State private var eventMonitor: Any?  // For monitoring keyboard events
    @State private var showingShortcutGuide = false  // For keyboard shortcut cheat sheet
    
    // iOS-style grid with fixed size icons
    private let gridColumns = [
        GridItem(.adaptive(minimum: 100, maximum: 100), spacing: 24)
    ]
    
    // Calculate columns per row based on window width
    private var columnsPerRow: Int {
        // Assuming minimum window width of 960, icon width of 100, spacing of 24, padding of 32 each side
        // Available width: 960 - 64 (padding) = 896
        // Per item: 100 (icon) + 24 (spacing) = 124
        // Columns: 896 / 124 ≈ 7
        return 7
    }
    
    // Handle keyboard event directly from NSEvent
    private func handleKeyCode(_ keyCode: UInt16) -> Bool {
        print("🎹 Key code: \(keyCode), searchFocused: \(isSearchFieldFocused), focusedApp: \(focusedAppIndex ?? -1)")
        
        // Don't handle keyboard if search field is focused
        if isSearchFieldFocused {
            print("🔍 Search field is focused, ignoring key")
            return false
        }
        
        let apps = viewModel.filteredApps
        guard !apps.isEmpty else { 
            print("📭 No apps available")
            return false
        }
        
        // Handle Escape key (53)
        if keyCode == 53 {
            if isDrawerOpen {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDrawerOpen = false
                }
                return true
            }
            // Clear focus
            focusedAppIndex = nil
            return true
        }
        
        // If no app is focused, focus the first one on any arrow key
        if focusedAppIndex == nil {
            if keyCode == 123 || keyCode == 124 || keyCode == 125 || keyCode == 126 {
                print("⬆️ Arrow key pressed, focusing first app")
                focusedAppIndex = 0
                return true
            }
            print("❓ No app focused and not an arrow key")
            return false
        }
        
        guard let currentIndex = focusedAppIndex else { return false }
        
        switch keyCode {
        case 36, 49:  // Return (36) or Space (49)
            // Launch focused app
            print("🚀 Launch app at index \(currentIndex)")
            if currentIndex < apps.count {
                viewModel.launch(app: apps[currentIndex])
            }
            return true
            
        case 124:  // Right arrow
            // Move focus right
            print("➡️ Right arrow: \(currentIndex) -> \(currentIndex + 1)")
            if currentIndex < apps.count - 1 {
                focusedAppIndex = currentIndex + 1
            }
            return true
            
        case 123:  // Left arrow
            // Move focus left
            print("⬅️ Left arrow: \(currentIndex) -> \(currentIndex - 1)")
            if currentIndex > 0 {
                focusedAppIndex = currentIndex - 1
            }
            return true
            
        case 125:  // Down arrow
            // Move focus down (next row)
            let nextIndex = currentIndex + columnsPerRow
            print("⬇️ Down arrow: \(currentIndex) -> \(nextIndex)")
            if nextIndex < apps.count {
                focusedAppIndex = nextIndex
            }
            return true
            
        case 126:  // Up arrow
            // Move focus up (previous row)
            let prevIndex = currentIndex - columnsPerRow
            print("⬆️ Up arrow: \(currentIndex) -> \(prevIndex)")
            if prevIndex >= 0 {
                focusedAppIndex = prevIndex
            }
            return true
            
        default:
            return false
        }
    }
    
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
        ZStack {
            // Hidden focusable view to capture keyboard events
            // This ensures the view can receive keyboard input
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focusable()
                .opacity(0.01)  // Nearly invisible but still present
            
            // Modern gradient background
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern toolbar with glassmorphism
                HStack(spacing: 16) {
                    // Hamburger menu button
                    ModernToolbarButton(
                        icon: "line.3.horizontal",
                        color: .primary,
                        help: "メニュー (⌘M)"
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isDrawerOpen.toggle()
                        }
                    }
                    .keyboardShortcut("m", modifiers: [.command])
                    
                    // Modern search field with icon
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                        
                        TextField("アプリを検索", text: $viewModel.searchText)
                            .textFieldStyle(.plain)
                            .disabled(isDrawerOpen)
                            .focused($isSearchFieldFocused)
                            .onSubmit {
                                // When Enter is pressed in search, focus first app
                                isSearchFieldFocused = false
                                if !viewModel.filteredApps.isEmpty {
                                    focusedAppIndex = 0
                                }
                            }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: 280)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                    .onTapGesture {
                        // Focus search field when clicked
                        isSearchFieldFocused = true
                        // Clear app focus
                        focusedAppIndex = nil
                    }
                    
                    Spacer()
                    
                    // Refresh button - modern style with engine rev animation 🏎️
                    ModernToolbarButton(
                        icon: "arrow.clockwise",
                        color: .primary,
                        help: "アプリ一覧を更新 (⌘R)",
                        rotation: refreshRotation
                    ) {
                        // Trigger sharp rotation animation - snappy engine rev! 🏎️
                        // Higher stiffness = sharper acceleration (more responsive)
                        // Lower damping = more aggressive snap with slight overshoot
                        withAnimation(.interpolatingSpring(stiffness: 120, damping: 12)) {
                            refreshRotation += 360  // Single sharp rotation
                        }
                        Task { await viewModel.refresh() }
                    }
                    .keyboardShortcut("r", modifiers: [.command])
                    
                    // Unmount button - modern style
                    ModernToolbarButton(
                        icon: "eject.fill",
                        color: .red,
                        help: "すべてアンマウント (⌘⇧U)"
                    ) {
                        viewModel.unmountAll(applyToPlayCoverContainer: true)
                    }
                    .keyboardShortcut(KeyEquivalent("u"), modifiers: [.command, .shift])
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            
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
                                ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element.id) { index, app in
                                    iOSAppIconView(
                                        app: app, 
                                        index: index,
                                        shouldAnimate: !hasPerformedInitialAnimation,
                                        isFocused: focusedAppIndex == index
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
                                    .onTapGesture {
                                        // Clear search focus and focus this app
                                        isSearchFieldFocused = false
                                        focusedAppIndex = index
                                        viewModel.launch(app: app)
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
                    }
                    
                    // Modern recently launched app button
                    VStack(spacing: 0) {
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
                        .background(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
                    }
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
                            ForEach(Array(viewModel.filteredApps.enumerated()), id: \.element.id) { index, app in
                                iOSAppIconView(
                                    app: app, 
                                    index: index,
                                    shouldAnimate: !hasPerformedInitialAnimation,
                                    isFocused: focusedAppIndex == index
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
                                .onTapGesture {
                                    // Clear search focus and focus this app
                                    isSearchFieldFocused = false
                                    focusedAppIndex = index
                                    viewModel.launch(app: app)
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
                }
            }
            }
        }
        .sheet(item: $selectedAppForDetail) { app in
        AppDetailSheet(app: app, viewModel: viewModel)
    }
    .sheet(isPresented: $showingSettings) {
        SettingsRootView()
            .interactiveDismissDisabled(false)
    }
    .sheet(isPresented: $showingInstaller) {
        IPAInstallerSheet()
    }
    .sheet(item: $selectedAppForUninstall) { identifiableString in
        AppUninstallerSheet(preSelectedBundleID: identifiableString.id)
    }
    .sheet(isPresented: $showingUninstaller) {
        AppUninstallerSheet(preSelectedBundleID: nil)
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
    .keyboardNavigableAlert(
        isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        ),
        title: viewModel.error?.title ?? "",
        message: viewModel.error?.message ?? "",
        buttons: [
            AlertButton("OK", role: .cancel, style: .borderedProminent, keyEquivalent: .default) {
                viewModel.error = nil
            }
        ],
        icon: .error
    )
    .keyboardNavigableAlert(
        isPresented: Binding(
            get: { viewModel.pendingImageCreation != nil },
            set: { if !$0 { viewModel.cancelImageCreation() } }
        ),
        title: "ディスクイメージが存在しません",
        message: "\(viewModel.pendingImageCreation?.displayName ?? "") 用の ASIF ディスクイメージを作成しますか？",
        buttons: [
            AlertButton("キャンセル", role: .cancel, style: .bordered, keyEquivalent: .cancel) {
                viewModel.cancelImageCreation()
            },
            AlertButton("作成", style: .borderedProminent, keyEquivalent: .default) {
                viewModel.confirmImageCreation()
            }
        ],
        icon: .question
    )
    .overlay {
        if viewModel.pendingDataHandling != nil {
            DataHandlingAlertView(
                request: viewModel.pendingDataHandling!,
                defaultStrategy: settingsStore.defaultDataHandling,
                onSelect: { strategy in
                    viewModel.applyDataHandling(strategy: strategy)
                },
                onCancel: {
                    viewModel.pendingDataHandling = nil
                }
            )
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
            appViewModel?.completeStorageLocationChange()
        }
    }
    .onAppear {
        // Set up local keyboard event monitor for arrow keys
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            print("🎹 NSEvent Key: \(event.keyCode), chars: \(event.characters ?? "none")")
            
            // Don't intercept keys if any modal/sheet is showing
            if showingSettings || showingInstaller || showingUninstaller || 
               selectedAppForDetail != nil || selectedAppForUninstall != nil ||
               showingShortcutGuide || viewModel.unmountFlowState != .idle {
                print("🪟 Modal/sheet active, passing through")
                return event
            }
            
            // Check if search field is focused
            if isSearchFieldFocused {
                print("🔍 Search field focused, passing through")
                return event
            }
            
            // Handle arrow keys (keyCode: 123=left, 124=right, 125=down, 126=up)
            // Handle space (49), return (36), and escape (53)
            switch event.keyCode {
            case 123, 124, 125, 126, 36, 49, 53:
                let handled = handleKeyCode(event.keyCode)
                if handled {
                    print("✅ Event handled, suppressing system beep")
                    return nil  // Suppress the event (no beep)
                }
                return event
            default:
                return event
            }
        }
    }
    .onDisappear {
        // Clean up event monitor
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSettings"))) { _ in
        showingSettings = true
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowInstaller"))) { _ in
        showingInstaller = true
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowUninstaller"))) { _ in
        showingUninstaller = true
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleDrawer"))) { _ in
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDrawerOpen.toggle()
        }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshApps"))) { _ in
        // Trigger sharp rotation animation
        withAnimation(.interpolatingSpring(stiffness: 120, damping: 12)) {
            refreshRotation += 360
        }
        Task { await viewModel.refresh() }
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UnmountAll"))) { _ in
        viewModel.unmountAll(applyToPlayCoverContainer: true)
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowShortcutGuide"))) { _ in
        showingShortcutGuide = true
    }
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPlayCover"))) { _ in
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/PlayCover.app"))
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
        
        // Keyboard shortcut guide overlay
        if showingShortcutGuide {
            ZStack {
                // Background overlay - tap to close
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showingShortcutGuide = false
                        }
                    }
                
                KeyboardShortcutGuide(isShowing: $showingShortcutGuide)
                    .transition(.scale.combined(with: .opacity))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .zIndex(1000)  // Above drawer
        }
    }
    }
}

// MARK: - Modern Toolbar Button with Hover Effect
private struct ModernToolbarButton: View {
    let icon: String
    let color: Color
    let help: String
    var rotation: Double = 0  // Optional rotation angle for animations
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .rotationEffect(.degrees(rotation))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .brightness(isHovered ? 0.05 : 0)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// iOS-style app icon with name below
private struct iOSAppIconView: View {
    let app: PlayCoverApp
    let index: Int
    let shouldAnimate: Bool
    let isFocused: Bool  // Keyboard focus state
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
            .overlay {
                // Keyboard focus ring only
                if isFocused {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.accentColor, lineWidth: 3)
                }
            }
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
        
        var icon: String {
            switch self {
            case .basic: return "slider.horizontal.3"
            case .graphics: return "display"
            case .controls: return "gamecontroller.fill"
            case .advanced: return "gearshape.2.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern header card
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        // App icon with shadow
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        } else {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "app.dashed")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.secondary)
                                }
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(app.displayName)
                                .font(.title2.bold())
                                .lineLimit(2)
                            
                            if let version = app.version {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption2)
                                    Text("バージョン \(version)")
                                        .font(.subheadline)
                                }
                                .foregroundStyle(.secondary)
                            }
                            
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
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
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(24)
                .background(.ultraThinMaterial)
                
                Divider()
                
                // Modern tab selector with icons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SettingsTab.allCases) { tab in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = tab
                                }
                            } label: {
                                Label(tab.rawValue, systemImage: tab.icon)
                                    .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedTab == tab ?
                                            AnyView(RoundedRectangle(cornerRadius: 8).fill(.blue)) :
                                            AnyView(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor).opacity(0.5)))
                                    )
                                    .foregroundStyle(selectedTab == tab ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                
                Divider()
                
                // Tab content with transition
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
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("閉じる") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .help("アプリ設定を閉じる (Esc)")
                }
                .padding(16)
                .background(.ultraThinMaterial)
            }
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
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Icon and title card
                VStack(spacing: 24) {
                    Image(systemName: isSearchEmpty ? "magnifyingglass" : "tray")
                        .font(.system(size: 80))
                        .foregroundStyle(isSearchEmpty ? .blue : .secondary)
                    
                    VStack(spacing: 12) {
                        Text(isSearchEmpty ? "検索結果が見つかりません" : "インストール済みアプリがありません")
                            .font(.title.bold())
                        
                        if isSearchEmpty {
                            // Search empty state
                            VStack(spacing: 8) {
                                Text("\"\(searchText)\" に一致するアプリが見つかりませんでした。")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("別のキーワードで検索してみてください。")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: 450)
                        } else {
                            // No apps installed state
                            VStack(spacing: 8) {
                                Text("IPA ファイルをインストールすると、ここに表示されます。")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("下のボタンから IPA をインストールしてください。")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: 450)
                        }
                    }
                }
                .padding(40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 10)
                
                // Action buttons (only for non-search empty state)
                if !isSearchEmpty {
                    VStack(spacing: 16) {
                        Button {
                            showingInstaller = true
                        } label: {
                            Label("IPA をインストール", systemImage: "square.and.arrow.down")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                        
                        Button {
                            refreshAction()
                        } label: {
                            Label("再読み込み", systemImage: "arrow.clockwise")
                                .font(.system(size: 15, weight: .medium))
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut("r", modifiers: [.command])
                    }
                }
            }
            .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @State private var isHovered = false
    
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
    @State private var oldIconRotation: Double = 0.0  // Spinning effect when blasted away
    
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
            HStack(spacing: 20) {
                // Icon with animations - ZStack layers old icon, ripple, and new icon
                ZStack {
                    // Old icon (during transition) - bottom layer
                    if let oldIcon = oldIcon {
                        Image(nsImage: oldIcon)
                            .resizable()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            .rotationEffect(.degrees(oldIconRotation))
                            .offset(x: oldIconOffsetX, y: oldIconOffsetY)
                            .scaleEffect(oldIconScale)
                            .opacity(oldIconOpacity)
                    }
                    
                    // Ripple effect - middle layer, centered on icon
                    RippleEffect(trigger: rippleTrigger)
                        .frame(width: 56, height: 56)
                    
                    // Current icon - top layer with modern shadow
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                            .offset(x: iconOffsetX, y: iconOffsetY)
                            .scaleEffect(iconScale)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.tertiary)
                            }
                            .offset(x: iconOffsetX, y: iconOffsetY)
                            .scaleEffect(iconScale)
                    }
                }
                .frame(width: 56, height: 56)
                
                // App info with modern styling
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayedTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 11, weight: .medium))
                        Text("前回起動したアプリ")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .opacity(textOpacity)
                .animation(.easeInOut(duration: 0.3), value: displayedTitle)
                
                Spacer()
                
                // Modern Enter key hint with glassmorphism
                HStack(spacing: 6) {
                    Image(systemName: "return")
                        .font(.system(size: 11, weight: .bold))
                    Text("Enter")
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .foregroundStyle(.secondary)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.accentColor.opacity(isHovered ? 0.08 : 0))
            )
            .brightness(isHovered ? 0.02 : 0)
        }
        .buttonStyle(.plain)
        .clipped()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
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
    
    // App switch animation - icon flies from drawer and crashes into old one
    private func performAppSwitchAnimation() {
        // Reset old icon state (oldIcon already saved in onChange)
        oldIconOffsetX = 0
        oldIconOffsetY = 0
        oldIconScale = 1.0
        oldIconOpacity = 1.0  // Old icon is visible and stays in place
        oldIconRotation = 0.0  // Reset rotation
        
        // New icon starts from drawer position (bottom-left, approximation)
        // In reality, drawer is to the left and below, so we start there
        iconOffsetY = 350  // Below current position (drawer is at bottom)
        iconOffsetX = -600  // To the left (drawer is on left side)
        iconScale = 0.5  // Starts small (far away effect)
        
        // Text stays visible (shows OLD title during animation)
        textOpacity = 1.0
        
        // Phase 1: Lift off from drawer with rotation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: 0.2)) {
                iconOffsetY = 300  // Lift up a bit
                iconScale = 0.7  // Get slightly bigger
            }
        }
        
        // Phase 2: Fly towards target with speed increase
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeIn(duration: 0.35)) {
                iconOffsetY = 0  // Arrive at target position
                iconOffsetX = 0
                iconScale = 1.3  // Overshoot scale for impact
            }
            
            // CRASH! Both icons react
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // Impact effect - new icon squashes
                withAnimation(.easeOut(duration: 0.08)) {
                    iconScale = 0.9
                }
                
                // Old icon gets BLASTED away (rotates and flies out)
                withAnimation(.easeOut(duration: 0.4)) {
                    oldIconOffsetY = -100  // Flies upward
                    oldIconOffsetX = 150  // Flies to the right
                    oldIconScale = 0.4  // Shrinks as it flies away
                    oldIconOpacity = 0.0  // Fades out
                    oldIconRotation = 720  // Spins twice while flying away
                }
                
                // New icon settles with elastic bounce
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.interpolatingSpring(stiffness: 350, damping: 18)) {
                        iconScale = 1.0
                    }
                }
                
                // Shockwave ripple effect on impact
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    rippleTrigger += 1
                }
                
                // After impact settles (0.5s), update title
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Fade out old title
                    withAnimation(.easeOut(duration: 0.2)) {
                        textOpacity = 0.0
                    }
                    
                    // Update displayed title while faded out
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            displayedTitle = app.displayName
                        }
                        
                        // Fade in new title
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
                DrawerMenuItem(
                    icon: AnyView(
                        Group {
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
                        }
                    ),
                    title: "PlayCover.app",
                    help: "PlayCover を開く (⌘⇧P)"
                ) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/PlayCover.app"))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Divider()
                    .padding(.leading, 16)
                
                // Install button
                DrawerMenuItem(
                    icon: AnyView(
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                            .frame(width: 32, height: 32)
                    ),
                    title: "IPA をインストール",
                    help: "IPA をインストール (⌘I)"
                ) {
                    showingInstaller = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                }
                .keyboardShortcut("i", modifiers: [.command])
                
                // Uninstall button
                DrawerMenuItem(
                    icon: AnyView(
                        Image(systemName: "trash")
                            .font(.system(size: 20))
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                    ),
                    title: "アプリをアンインストール",
                    help: "アプリをアンインストール (⌘D)"
                ) {
                    showingUninstaller = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                }
                .keyboardShortcut("d", modifiers: [.command])
                
                Divider()
                    .padding(.leading, 16)
                
                // Settings button
                DrawerMenuItem(
                    icon: AnyView(
                        Image(systemName: "gear")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                    ),
                    title: "設定",
                    help: "設定 (⌘,)"
                ) {
                    showingSettings = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                }
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

// MARK: - Drawer Menu Item with Hover Effect
private struct DrawerMenuItem: View {
    let icon: AnyView
    let title: String
    let help: String
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon
                Text(title)
                    .font(.body)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.accentColor.opacity(isHovered ? 0.1 : 0))
            )
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Keyboard Shortcut Guide
private struct KeyboardShortcutGuide: View {
    @Binding var isShowing: Bool
    
    struct ShortcutItem {
        let keys: String
        let description: String
        let category: String
    }
    
    let shortcuts: [ShortcutItem] = [
        // Global commands
        ShortcutItem(keys: "⌘,", description: "設定を開く", category: "グローバル"),
        ShortcutItem(keys: "⌘I", description: "IPA をインストール", category: "グローバル"),
        ShortcutItem(keys: "⌘D", description: "アプリをアンインストール", category: "グローバル"),
        ShortcutItem(keys: "⌘M", description: "メニューを開く/閉じる", category: "グローバル"),
        ShortcutItem(keys: "⌘R", description: "アプリ一覧を更新", category: "グローバル"),
        ShortcutItem(keys: "⌘⇧U", description: "すべてマウント解除", category: "グローバル"),
        ShortcutItem(keys: "⌘⇧P", description: "PlayCover.app を開く", category: "グローバル"),
        ShortcutItem(keys: "⌘/", description: "このヘルプを表示", category: "グローバル"),
        
        // Navigation
        ShortcutItem(keys: "↑↓←→", description: "アプリ間を移動", category: "ナビゲーション"),
        ShortcutItem(keys: "Enter / Space", description: "フォーカスされたアプリを起動", category: "ナビゲーション"),
        ShortcutItem(keys: "Escape", description: "フォーカスをクリア", category: "ナビゲーション"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
                
                Text("キーボードショートカット")
                    .font(.title2.bold())
                
                Spacer()
                
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("閉じる (Esc)")
            }
            .padding(24)
            .background(.ultraThinMaterial)
            
            Divider()
            
            // Shortcuts list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(["グローバル", "ナビゲーション"], id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            Text(category)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                            
                            VStack(spacing: 0) {
                                ForEach(shortcuts.filter { $0.category == category }, id: \.keys) { shortcut in
                                    HStack(spacing: 16) {
                                        // Key combination
                                        Text(shortcut.keys)
                                            .font(.system(.body, design: .monospaced).weight(.semibold))
                                            .foregroundStyle(.primary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                                            .frame(minWidth: 100, alignment: .leading)
                                        
                                        // Description
                                        Text(shortcut.description)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 10)
                                    .background(Color.clear)
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 12)
            }
            
            Divider()
            
            // Footer
            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Escキーまたは背景をクリックして閉じる")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("閉じる") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(16)
            .background(.ultraThinMaterial)
        }
        .frame(width: 600, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
    }
}

// MARK: - Data Handling Alert View

private struct DataHandlingAlertView: View {
    let request: LauncherViewModel.DataHandlingRequest
    let defaultStrategy: SettingsStore.InternalDataStrategy
    let onSelect: (SettingsStore.InternalDataStrategy) -> Void
    let onCancel: () -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var eventMonitor: Any?
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // Alert content
            VStack(spacing: 20) {
                Image(systemName: "folder.fill.badge.questionmark")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text("内部データが見つかりました")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("\(request.app.displayName) の内部ストレージにデータが存在します。どのように処理しますか？")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                
                // Strategy selection buttons
                VStack(spacing: 12) {
                    ForEach(Array(SettingsStore.InternalDataStrategy.allCases.enumerated()), id: \.offset) { index, strategy in
                        Button {
                            onSelect(strategy)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(strategy.localizedDescription)
                                            .font(.body)
                                            .fontWeight(.medium)
                                        
                                        if strategy == defaultStrategy {
                                            Text("（既定）")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    // Add description for each strategy
                                    Text(strategyDescription(for: strategy))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                if selectedIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIndex == index ? Color.blue.opacity(0.1) : Color.clear)
                            )
                            .overlay {
                                if selectedIndex == index {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.blue, lineWidth: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 500)
                
                // Cancel button
                Button("キャンセル") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
            .padding(32)
            .frame(maxWidth: 600)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { cleanupKeyboardMonitor() }
    }
    
    private func strategyDescription(for strategy: SettingsStore.InternalDataStrategy) -> String {
        switch strategy {
        case .discard:
            return "内部データを破棄してから新しくマウントします"
        case .mergeThenDelete:
            return "内部データをコンテナに統合してから削除してマウントします"
        case .leave:
            return "内部データはそのまま残してマウントします"
        }
    }
    
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            switch event.keyCode {
            case 53:  // Escape
                self.onCancel()
                return nil
            case 36:  // Return
                let strategies = SettingsStore.InternalDataStrategy.allCases
                if self.selectedIndex < strategies.count {
                    self.onSelect(strategies[self.selectedIndex])
                }
                return nil
            case 125:  // Down arrow
                if self.selectedIndex < SettingsStore.InternalDataStrategy.allCases.count - 1 {
                    self.selectedIndex += 1
                }
                return nil
            case 126:  // Up arrow
                if self.selectedIndex > 0 {
                    self.selectedIndex -= 1
                }
                return nil
            default:
                return event
            }
        }
    }
    
    private func cleanupKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
