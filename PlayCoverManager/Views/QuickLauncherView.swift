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
    
    // Workaround for macOS focus loss bug after dismissing sheets/overlays
    // Forces the window to regain focus and become key window
    private func restoreWindowFocus() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            if let window = NSApp.keyWindow ?? NSApp.windows.first {
                window.makeKey()
                window.makeFirstResponder(window.contentView)
            }
        }
    }
    
    // Handle keyboard event directly from NSEvent
    private func handleKeyCode(_ keyCode: UInt16) -> Bool {
        // Don't handle keyboard if search field is focused
        if isSearchFieldFocused {
            return false
        }
        
        let apps = viewModel.filteredApps
        guard !apps.isEmpty else { 
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
                focusedAppIndex = 0
                return true
            }
            return false
        }
        
        guard let currentIndex = focusedAppIndex else { return false }
        
        switch keyCode {
        case 36, 49:  // Return (36) or Space (49)
            // Launch focused app with animation
            if currentIndex < apps.count {
                let app = apps[currentIndex]
                
                // Trigger icon animation
                NotificationCenter.default.post(
                    name: NSNotification.Name("TriggerAppIconAnimation"),
                    object: nil,
                    userInfo: ["bundleID": app.bundleIdentifier]
                )
                
                // Launch app
                viewModel.launch(app: app)
                
                // If this is the recent app, trigger bounce animation on recent button
                if app.lastLaunchedFlag {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TriggerRecentAppBounce"),
                        object: nil
                    )
                }
            }
            return true
            
        case 124:  // Right arrow
            // Move focus right
            if currentIndex < apps.count - 1 {
                focusedAppIndex = currentIndex + 1
            }
            return true
            
        case 123:  // Left arrow
            // Move focus left
            if currentIndex > 0 {
                focusedAppIndex = currentIndex - 1
            }
            return true
            
        case 125:  // Down arrow
            // Move focus down (next row)
            let nextIndex = currentIndex + columnsPerRow
            if nextIndex < apps.count {
                focusedAppIndex = nextIndex
            }
            return true
            
        case 126:  // Up arrow
            // Move focus up (previous row)
            let prevIndex = currentIndex - columnsPerRow
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
                .focusEffectDisabled()  // Disable blue focus ring
                .opacity(0.01)  // Nearly invisible but still present
            
            // Rich multi-layer gradient background with depth
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .controlBackgroundColor).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Radial glow from center
                RadialGradient(
                    colors: [
                        .accentColor.opacity(0.03),
                        .purple.opacity(0.02),
                        .clear
                    ],
                    center: .center,
                    startRadius: 100,
                    endRadius: 600
                )
                
                // Ambient corner glows
                VStack {
                    HStack {
                        Circle()
                            .fill(RadialGradient(
                                colors: [.blue.opacity(0.08), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            ))
                            .frame(width: 400, height: 400)
                            .blur(radius: 60)
                        
                        Spacer()
                        
                        Circle()
                            .fill(RadialGradient(
                                colors: [.purple.opacity(0.06), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 180
                            ))
                            .frame(width: 350, height: 350)
                            .blur(radius: 50)
                    }
                    Spacer()
                }
            }
            .allowsHitTesting(false)  // Allow clicks to pass through background
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Modern toolbar with glassmorphism
                HStack(spacing: 16) {
                    // Hamburger menu button
                    ModernToolbarButton(
                        icon: "line.3.horizontal",
                        color: .primary,
                        help: String(localized: "メニュー (⌘M)")
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
                        
                        TextField(String(localized: "アプリを検索"), text: $viewModel.searchText)
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
                    .glassEffect(
                        isSearchFieldFocused 
                        ? .regular.tint(.accentColor.opacity(0.4))
                        : .regular.tint(.accentColor.opacity(0.2)), 
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchFieldFocused)
                    .shadow(color: isSearchFieldFocused ? .accentColor.opacity(0.3) : .black.opacity(0.1), radius: isSearchFieldFocused ? 8 : 4, x: 0, y: 2)
                    .scaleEffect(isSearchFieldFocused ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSearchFieldFocused)
                    .onTapGesture {
                        // Focus search field when clicked
                        isSearchFieldFocused = true
                        // Clear app focus
                        focusedAppIndex = nil
                    }
                    
                    Spacer()
                    
                    // Unmount button - modern style
                    ModernToolbarButton(
                        icon: "eject.fill",
                        color: .red,
                        help: String(localized: "すべてアンマウント (⌘⇧U)")
                    ) {
                        viewModel.unmountAll(applyToPlayCoverContainer: true)
                    }
                    .keyboardShortcut(KeyEquivalent("u"), modifiers: [.command, .shift])
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(
                    // Multi-layer glass effect for depth
                    ZStack {
                        // Bottom layer - subtle glow
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.accentColor.opacity(0.03), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .blur(radius: 20)
                        
                        // Top layer - main glass
                        Rectangle()
                            .glassEffect(.regular.tint(.primary.opacity(0.05)), in: .rect)
                    }
                    .allowsHitTesting(false)  // Allow clicks to pass through to buttons
                )
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                .overlay(alignment: .bottom) {
                    // Subtle separator line
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [.clear, .primary.opacity(0.1), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        ))
                        .frame(height: 0.5)
                        .allowsHitTesting(false)  // Allow clicks through separator
                }
            
            // Recently launched app button (fixed at bottom)
            if let recentApp = viewModel.filteredApps.first(where: { $0.lastLaunchedFlag }) {
                VStack(spacing: 0) {
                    // Main app grid
                    if viewModel.filteredApps.isEmpty {
                        EmptyAppListView(searchText: viewModel.searchText)
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
                                        // Tap action - called by DragGesture on valid release
                                        // Clear search focus and focus this app
                                        isSearchFieldFocused = false
                                        focusedAppIndex = index
                                        viewModel.launch(app: app)
                                        
                                        // Trigger icon animation
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("TriggerAppIconAnimation"),
                                            object: nil,
                                            userInfo: ["bundleID": app.bundleIdentifier]
                                        )
                                        
                                        // If this is the recent app, trigger bounce animation on recent button
                                        if app.lastLaunchedFlag {
                                            NotificationCenter.default.post(
                                                name: NSNotification.Name("TriggerRecentAppBounce"),
                                                object: nil
                                            )
                                        }
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
                                    Task { @MainActor in
                                        try? await Task.sleep(for: .milliseconds(50))
                                        hasPerformedInitialAnimation = true
                                    }
                                }
                            }
                        }
                    }
                    
                    // Modern recently launched app button with rich glass effect
                    VStack(spacing: 0) {
                        // Glowing separator
                        Rectangle()
                            .fill(LinearGradient(
                                colors: [.clear, .accentColor.opacity(0.3), .purple.opacity(0.2), .accentColor.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(height: 1)
                            .blur(radius: 2)
                        
                        RecentAppLaunchButton(
                            app: recentApp,
                            onLaunch: {
                                // Launch app first
                                viewModel.launch(app: recentApp)
                                
                                // Trigger animation on the grid icon after a brief delay
                                // to ensure the observer is set up
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(50))
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("TriggerAppIconAnimation"),
                                        object: nil,
                                        userInfo: ["bundleID": recentApp.bundleIdentifier]
                                    )
                                }
                            }
                        )
                        .background(
                            // Multi-layer glass for depth
                            ZStack {
                                // Animated gradient glow
                                LinearGradient(
                                    colors: [.accentColor.opacity(0.08), .purple.opacity(0.05), .blue.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .blur(radius: 20)
                                
                                // Main glass layer
                                Rectangle()
                                    .glassEffect(.regular.tint(.accentColor.opacity(0.12)), in: .rect)
                            }
                            .allowsHitTesting(false)  // Allow clicks through to button
                        )
                        .shadow(color: .accentColor.opacity(0.15), radius: 12, x: 0, y: -4)
                        .overlay(alignment: .top) {
                            // Shine effect
                            LinearGradient(
                                colors: [.white.opacity(0.15), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 60)
                            .blur(radius: 10)
                            .allowsHitTesting(false)  // Allow clicks through shine
                        }
                    }
                }
            } else {
                // No recent app - show regular grid
                if viewModel.filteredApps.isEmpty {
                    EmptyAppListView(searchText: viewModel.searchText)
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
                                    // Tap action - called by DragGesture on valid release
                                    // Clear search focus and focus this app
                                    isSearchFieldFocused = false
                                    focusedAppIndex = index
                                    viewModel.launch(app: app)
                                    
                                    // Trigger icon animation
                                    NotificationCenter.default.post(
                                        name: NSNotification.Name("TriggerAppIconAnimation"),
                                        object: nil,
                                        userInfo: ["bundleID": app.bundleIdentifier]
                                    )
                                    
                                    // If this is the recent app, trigger bounce animation on recent button
                                    if app.lastLaunchedFlag {
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("TriggerRecentAppBounce"),
                                            object: nil
                                        )
                                    }
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
                                Task { @MainActor in
                                    try? await Task.sleep(for: .milliseconds(50))
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
            .interactiveDismissDisabled(false)
            .onDisappear {
                restoreWindowFocus()
            }
    }
    .sheet(isPresented: $showingSettings) {
        SettingsRootView()
            .interactiveDismissDisabled(false)
            .onDisappear {
                restoreWindowFocus()
            }
    }
    .sheet(isPresented: $showingInstaller) {
        IPAInstallerSheet()
            .interactiveDismissDisabled(false)
            .onDisappear {
                restoreWindowFocus()
            }
    }
    .sheet(item: $selectedAppForUninstall) { identifiableString in
        AppUninstallerSheet(preSelectedBundleID: identifiableString.id)
            .interactiveDismissDisabled(false)
            .onDisappear {
                restoreWindowFocus()
            }
    }
    .sheet(isPresented: $showingUninstaller) {
        AppUninstallerSheet(preSelectedBundleID: nil)
            .interactiveDismissDisabled(false)
            .onDisappear {
                restoreWindowFocus()
            }
    }
    .frame(minWidth: 960, minHeight: 640)
    .onGeometryChange(for: CGSize.self) { proxy in
        proxy.size
    } action: { newSize in
        // Track window size for responsive grid layout
        // Uses macOS 26 onGeometryChange API
    }
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
            .glassEffect(.regular.tint(.blue.opacity(0.2)), in: RoundedRectangle(cornerRadius: 12))
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
        title: String(localized: "ディスクイメージが存在しません"),
        message: String(localized: "\(viewModel.pendingImageCreation?.displayName ?? "") 用の ASIF ディスクイメージを作成しますか？"),
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
        
        // Set up storage change completion callback
        viewModel.onStorageChangeCompleted = { [weak appViewModel] in
            appViewModel?.completeStorageLocationChange()
        }
    }
    .onAppear {
        // Set up local keyboard event monitor for arrow keys
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Don't intercept keys if any modal/sheet is showing
            if showingSettings || showingInstaller || showingUninstaller || 
               selectedAppForDetail != nil || selectedAppForUninstall != nil ||
               showingShortcutGuide || viewModel.unmountFlowState != .idle {
                return event
            }
            
            // Check if search field is focused
            if isSearchFieldFocused {
                return event
            }
            
            // Handle arrow keys (keyCode: 123=left, 124=right, 125=down, 126=up)
            // Handle space (49), return (36), and escape (53)
            switch event.keyCode {
            case 123, 124, 125, 126, 36, 49, 53:
                let handled = handleKeyCode(event.keyCode)
                if handled {
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
                .foregroundStyle(isHovered ? color.opacity(0.9) : color)
                .rotationEffect(.degrees(rotation))
                .frame(width: 44, height: 44)
                .background(
                    ZStack {
                        // Glow effect when hovered
                        if isHovered {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(color.opacity(0.15))
                                .blur(radius: 8)
                        }
                        
                        // Main glass button
                        RoundedRectangle(cornerRadius: 12)
                            .glassEffect(
                                isHovered 
                                ? .regular.tint(color.opacity(0.15))
                                : .regular, 
                                in: RoundedRectangle(cornerRadius: 12)
                            )
                    }
                    .allowsHitTesting(false)  // Allow clicks through to button
                )
                .shadow(
                    color: isHovered ? color.opacity(0.3) : .black.opacity(0.1), 
                    radius: isHovered ? 8 : 4, 
                    x: 0, 
                    y: 2
                )
                .overlay {
                    // Shine effect on hover
                    if isHovered {
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .allowsHitTesting(false)  // Allow clicks through shine
                    }
                }
                .contentShape(Rectangle())  // Ensure entire area is tappable
                .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
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
    // Press & bounce animation states
    @State private var isPressing = false
    @State private var isBouncing = false
    @State private var pressLocation: CGPoint?
    // Hover effect state
    @State private var isHovering = false
    @State private var gradientOffset: CGFloat = 0
    @State private var focusGlowPhase: CGFloat = 0
    
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
            .background {
                // Hover glow effect behind the icon (doesn't cover image)
                if isHovering {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            RadialGradient(
                                colors: [
                                    .accentColor.opacity(0.3),
                                    .purple.opacity(0.2),
                                    .blue.opacity(0.15),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                        .frame(width: 96, height: 96)
                        .blur(radius: 8)
                }
            }
            .shadow(
                color: isHovering ? .accentColor.opacity(0.5) : .black.opacity(0.2), 
                radius: isHovering ? 16 : 3, 
                x: 0, 
                y: isHovering ? 6 : 2
            )
            .overlay {
                // Rich keyboard focus ring with animated glow
                if isFocused {
                    ZStack {
                        // Outer glow layer (pulsing)
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .accentColor.opacity(0.3),
                                        .purple.opacity(0.2),
                                        .blue.opacity(0.2),
                                        .accentColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 8
                            )
                            .blur(radius: 4)
                            .opacity(0.6 + CGFloat(sin(Double(focusGlowPhase))) * 0.3)
                        
                        // Middle glow layer (seamless rotation)
                        RoundedRectangle(cornerRadius: 19)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .accentColor.opacity(0.5),
                                        .purple.opacity(0.4),
                                        .blue.opacity(0.4),
                                        .cyan.opacity(0.4),
                                        .accentColor.opacity(0.5),
                                        .purple.opacity(0.4),
                                        .blue.opacity(0.4),
                                        .cyan.opacity(0.4),
                                        .accentColor.opacity(0.5)
                                    ],
                                    startPoint: UnitPoint(x: focusGlowPhase / (.pi * 2), y: 0),
                                    endPoint: UnitPoint(x: focusGlowPhase / (.pi * 2) + 0.5, y: 0)
                                ),
                                lineWidth: 4
                            )
                            .blur(radius: 2)
                        
                        // Inner sharp border (seamless rotation)
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        .accentColor,
                                        .purple,
                                        .blue,
                                        .cyan,
                                        .accentColor,
                                        .purple,
                                        .blue,
                                        .cyan,
                                        .accentColor
                                    ],
                                    startPoint: UnitPoint(x: focusGlowPhase / (.pi * 2), y: 0),
                                    endPoint: UnitPoint(x: focusGlowPhase / (.pi * 2) + 0.5, y: 0)
                                ),
                                lineWidth: 3
                            )
                    }
                }
            }
            .overlay {
                // Hover border glow outside the icon
                if isHovering {
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    .accentColor.opacity(0.6),
                                    .purple.opacity(0.5),
                                    .blue.opacity(0.5),
                                    .cyan.opacity(0.5),
                                    .accentColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                }
            }
            .overlay(alignment: .topTrailing) {
                // Status indicator:
                // 🟢 Green: App is running
                // 🟠 Orange: App not running but container mounted (needs unmount)
                // 🔴 Red: App stopped and container unmounted
                Group {
                    if app.isRunning {
                        // Green: Running
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
                    } else if app.isMounted {
                        // Orange: Not running but mounted
                        ZStack {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 14, height: 14)
                            Circle()
                                .strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2.5)
                                .frame(width: 14, height: 14)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .offset(x: 6, y: -6)
                    } else {
                        // Red: Stopped and unmounted
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 14, height: 14)
                            Circle()
                                .strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2.5)
                                .frame(width: 14, height: 14)
                        }
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 1)
                        .offset(x: 6, y: -6)
                    }
                }
            }
            // Press & bounce & hover animation
            .scaleEffect(
                isPressing ? 0.85 : 
                isBouncing ? 1.15 : 
                isAnimating ? 0.85 : 
                isHovering ? 1.05 : 1.0
            )
            .animation(
                isPressing ? .easeOut(duration: 0.15) :
                isBouncing ? .interpolatingSpring(stiffness: 400, damping: 8) :
                isAnimating ? Animation.interpolatingSpring(stiffness: 300, damping: 10)
                    .repeatCount(3, autoreverses: true) :
                .easeOut(duration: 0.2),
                value: isPressing
            )
            .animation(
                isBouncing ? .interpolatingSpring(stiffness: 400, damping: 8) : .easeOut(duration: 0.2),
                value: isBouncing
            )
            .animation(
                isAnimating ? 
                    Animation.interpolatingSpring(stiffness: 300, damping: 10)
                        .repeatCount(3, autoreverses: true) :
                    .easeOut(duration: 0.2),
                value: isAnimating
            )
            .animation(
                .interpolatingSpring(stiffness: 350, damping: 12),
                value: isHovering
            )
            .onHover { hovering in
                isHovering = hovering
                
                if hovering {
                    // Start seamless gradient animation (0 to 1 loop with duplicated colors)
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        gradientOffset = 1.0
                    }
                } else {
                    // Stop gradient animation smoothly
                    withAnimation(.linear(duration: 0.5)) {
                        gradientOffset = 0
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isPressing {
                            isPressing = true
                            pressLocation = value.location
                        }
                    }
                    .onEnded { value in
                        isPressing = false
                        
                        // Check if release location is within icon bounds (100x100 frame)
                        let isWithinBounds = value.location.x >= 0 && value.location.x <= 100 &&
                                           value.location.y >= 0 && value.location.y <= 120
                        
                        if isWithinBounds {
                            // Valid release - trigger bounce and launch
                            withAnimation(.interpolatingSpring(stiffness: 400, damping: 8)) {
                                isBouncing = true
                            }
                            
                            // Trigger launch action
                            tapAction()
                            
                            // Reset bounce after animation
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(400))
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isBouncing = false
                                }
                            }
                        } else {
                            // Invalid release - just return to normal without bounce
                            // No action triggered
                        }
                        
                        pressLocation = nil
                    }
            )
            
            // App name below icon with animated gradient on hover
            ZStack {
                // Base text (always visible)
                Text(app.displayName)
                    .font(.system(size: 11, weight: .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 90, height: 28)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.primary)
                    .opacity(isHovering ? 0 : 1)
                
                // Gradient text (fades in on hover with animated gradient)
                Text(app.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 90, height: 28)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                .accentColor,
                                .purple,
                                .blue,
                                .cyan,
                                .accentColor,
                                .purple,
                                .blue,
                                .cyan,
                                .accentColor
                            ],
                            startPoint: UnitPoint(x: gradientOffset, y: 0),
                            endPoint: UnitPoint(x: gradientOffset + 0.5, y: 0)
                        )
                    )
                    .opacity(isHovering ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.4), value: isHovering)
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
            
            // Start focus glow animation if focused
            if isFocused {
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    focusGlowPhase = .pi * 2
                }
            }
        }
        .onChange(of: isFocused) { oldValue, newValue in
            if newValue {
                // Start focus ring glow animation
                withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                    focusGlowPhase = .pi * 2
                }
            } else {
                // Stop focus ring animation
                withAnimation(.linear(duration: 0.3)) {
                    focusGlowPhase = 0
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerAppIconAnimation"))) { notification in
            // Trigger animation when receiving notification for this app
            if let bundleID = notification.userInfo?["bundleID"] as? String,
               bundleID == app.bundleIdentifier {
                // Delay animation slightly to sync with button animation
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    isAnimating = true
                    try? await Task.sleep(for: .milliseconds(550))
                    isAnimating = false
                }
            }
        }
        .contextMenu {
            Button("起動") {
                // Trigger bounce animation
                Task { @MainActor in
                    isAnimating = true
                    try? await Task.sleep(for: .milliseconds(100))
                    tapAction()
                    try? await Task.sleep(for: .milliseconds(550))
                    isAnimating = false
                }
            }
            Button("デバッグコンソールで起動") {
                launchInDebugConsole(app: app)
            }
            Divider()
            Button("詳細と設定") { rightClickAction() }
            Divider()
            Button("アプリ本体を Finder で表示") {
                NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
            }
            Button("コンテナを Finder で表示") {
                let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
                if FileManager.default.fileExists(atPath: containerURL.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([containerURL])
                }
            }
            Divider()
            Button("アンインストール", role: .destructive) {
                uninstallAction()
            }
            .foregroundStyle(.red)
        }
    }
    
    private func launchInDebugConsole(app: PlayCoverApp) {
        Task {
            do {
                // Use same mount process as normal launch
                let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
                let settingsStore = SettingsStore()
                let diskImageService = DiskImageService(settings: settingsStore)
                let perAppSettings = PerAppSettingsStore()
                
                // Check disk image state
                Logger.debug("Debug console: Checking disk image state for \(app.bundleIdentifier)")
                let state = try DiskImageHelper.checkDiskImageState(
                    for: app.bundleIdentifier,
                    containerURL: containerURL,
                    diskImageService: diskImageService
                )
                
                guard state.imageExists else {
                    Logger.error("Debug console: Disk image not found for \(app.bundleIdentifier)")
                    return
                }
                
                // Check for internal data if not mounted
                // Note: We can't use viewModel.detectInternalData here since it's in a contextMenu
                // which doesn't have access to the viewModel. We'll skip this check for debug console.
                // Users can launch normally first if they have internal data to migrate.
                
                // Mount if needed (same as normal launch)
                if !state.isMounted {
                    Logger.debug("Debug console: Mounting disk image for \(app.bundleIdentifier)")
                    try await DiskImageHelper.mountDiskImageIfNeeded(
                        for: app.bundleIdentifier,
                        containerURL: containerURL,
                        diskImageService: diskImageService,
                        perAppSettings: perAppSettings,
                        globalSettings: settingsStore
                    )
                    Logger.debug("Debug console: Successfully mounted disk image")
                } else {
                    Logger.debug("Debug console: Disk image already mounted")
                }
                
                // NOTE: We intentionally do NOT acquire lock for debug console
                // because Terminal.app runs the process independently, and we can't
                // reliably release the lock when Terminal closes.
                // The debug console is for development/troubleshooting only.
                Logger.debug("Debug console: Skipping lock acquisition (debug mode)")
                
                // Find the executable in the app bundle
                guard let bundle = Bundle(url: app.appURL),
                      let executableName = bundle.infoDictionary?["CFBundleExecutable"] as? String else {
                    Logger.error("Failed to find executable name for \(app.bundleIdentifier)")
                    return
                }
                
                let executablePath = app.appURL.appendingPathComponent(executableName).path
                
                // Check if executable exists
                guard FileManager.default.fileExists(atPath: executablePath) else {
                    Logger.error("Executable not found at: \(executablePath)")
                    return
                }
                
                // Create a temporary shell script to launch in Terminal
                let tempDir = FileManager.default.temporaryDirectory
                let scriptURL = tempDir.appendingPathComponent("launch_debug_\(UUID().uuidString).command")
                
                // Escape paths properly for shell
                let escapedAppPath = app.appURL.path.replacingOccurrences(of: "'", with: "'\\''")
                let escapedExecPath = executablePath.replacingOccurrences(of: "'", with: "'\\''")
                
                // Localized strings need to be evaluated in Swift, not in bash
                let headerText = String(localized: "=== デバッグコンソール ===")
                let appText = String(localized: "アプリ: \(app.displayName)")
                let executableText = String(localized: "実行ファイル: \(executableName)")
                let containerText = String(localized: "コンテナ: マウント済み")
                let exitText = String(localized: "プロセス終了 (終了コード:")
                let promptText = String(localized: "任意のキーを押してウィンドウを閉じる...")
                
                let scriptContent = """
                #!/bin/bash
                cd '\(escapedAppPath)'
                echo "\(headerText)"
                echo "\(appText)"
                echo "\(executableText)"
                echo "\(containerText)"
                echo "========================"
                echo ""
                
                '\(escapedExecPath)'
                
                EXIT_CODE=$?
                echo ""
                echo "========================"
                echo "\(exitText) $EXIT_CODE)"
                echo "========================"
                echo ""
                read -p "\(promptText)" -n1 -s
                
                # Clean up the script file
                rm -f '\(scriptURL.path.replacingOccurrences(of: "'", with: "'\\''"))'
                """
                
                try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
                
                // Make script executable
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
                
                // Open the script with Terminal (this doesn't require AppleScript permissions)
                NSWorkspace.shared.open(scriptURL)
            } catch {
                Logger.error("Failed to launch debug console: \(error)")
            }
        }
    }
    
}

// App detail and settings sheet with tabbed interface
private struct AppDetailSheet: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .overview
    
    enum SettingsTab: String, CaseIterable, Identifiable {
        case overview
        case settings
        case details
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .overview: return String(localized: "概要")
            case .settings: return String(localized: "設定")
            case .details: return String(localized: "詳細")
            }
        }
        
        var icon: String {
            switch self {
            case .overview: return "info.circle.fill"
            case .settings: return "gearshape.fill"
            case .details: return "doc.text.magnifyingglass"
            }
        }
        
        var description: String {
            switch self {
            case .overview: return String(localized: "アプリの基本情報とストレージ")
            case .settings: return String(localized: "アプリ固有の設定")
            case .details: return String(localized: "技術情報と解析")
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
                .glassEffect(.regular, in: .rect)
                
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
                                Label(tab.localizedTitle, systemImage: tab.icon)
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
                    VStack {
                        switch selectedTab {
                        case .overview:
                            OverviewView(app: app, viewModel: viewModel)
                        case .settings:
                            SettingsView(app: app, viewModel: viewModel)
                        case .details:
                            DetailsView(app: app, viewModel: viewModel)
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
                        Label("アプリ本体を表示", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("閉じる") {
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .help(String(localized: "アプリ設定を閉じる (Esc)"))
                }
                .padding(16)
                .glassEffect(.regular, in: .rect)
            }
        }
        .frame(width: 700, height: 600)
    }
}

private struct EmptyAppListView: View {
    let searchText: String
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
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 10)
                
                // Action buttons (only for non-search empty state)
                if !isSearchEmpty {
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
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
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
            // Using Swift 6.2 structured concurrency
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                currentIcon = app.icon
            }
        }
        .onAppear {
            previousAppID = app.bundleIdentifier
            currentIcon = app.icon
            displayedTitle = app.displayName
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerRecentAppBounce"))) { _ in
            performIconBounce()
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
        // Using Swift 6.2 structured concurrency for animation timing
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 12)) {
                iconOffsetY = 0
                iconScale = 1.0
            }
        }
        
        // Trigger ripple on landing at icon position
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
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
        
        // Drop new icon - Using Swift 6.2 structured concurrency for animation sequencing
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            
            withAnimation(.easeIn(duration: 0.3)) {
                iconOffsetY = 0  // Falls to collision point
            }
            
            // COLLISION! Both icons react
            try? await Task.sleep(for: .milliseconds(300))
            
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
            
            // New icon bounces back (parallel task)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(100))
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                    iconScale = 1.0
                }
            }
            
            // After new icon lands (0.45s), update title
            try? await Task.sleep(for: .milliseconds(450))
            
            // Fade out old title
            withAnimation(.easeOut(duration: 0.2)) {
                textOpacity = 0.0
            }
            
            // Update displayed title while faded out (triggers layout animation)
            try? await Task.sleep(for: .milliseconds(200))
            
            withAnimation(.easeInOut(duration: 0.3)) {
                displayedTitle = app.displayName
            }
            
            // Fade in new title after layout settles
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeIn(duration: 0.25)) {
                textOpacity = 1.0
            }
            
            // Clean up old icon
            try? await Task.sleep(for: .milliseconds(500))
            oldIcon = nil
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
        // Using Swift 6.2 structured concurrency
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
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

// MARK: - Overview Tab

private struct OverviewView: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @State private var infoPlist: [String: Any]?
    @State private var storageInfo: StorageInfo?
    
    init(app: PlayCoverApp, viewModel: LauncherViewModel) {
        self.app = app
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("アプリ概要")
                .font(.headline)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // App Card
                    HStack(spacing: 16) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 18))
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if let version = app.version {
                                Text("バージョン \(version)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let minOS = infoPlist?["MinimumOSVersion"] as? String {
                                HStack(spacing: 4) {
                                    Image(systemName: "iphone")
                                        .font(.caption)
                                    Text("iOS \(minOS)+")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12)
                    
                    // Quick Stats
                    HStack(spacing: 12) {
                        // Storage stat
                        StatCard(
                            icon: "internaldrive",
                            title: String(localized: "合計容量"),
                            value: storageInfo?.totalSize ?? String(localized: "計算中..."),
                            color: .blue
                        )
                        
                        // Device compatibility
                        if let deviceFamily = getDeviceFamily() {
                            StatCard(
                                icon: "apps.iphone",
                                title: String(localized: "対応デバイス"),
                                value: deviceFamily,
                                color: .green
                            )
                        }
                    }
                    
                    // Storage Breakdown
                    if let storage = storageInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ストレージ内訳")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 8) {
                                StorageRow(label: String(localized: "アプリ本体"), size: storage.appSize, color: .blue)
                                StorageRow(
                                    label: storage.isMounted ? String(localized: "ディスクイメージ (マウント中)") : "ディスクイメージ",
                                    size: storage.containerSize,
                                    color: .orange
                                )
                                if let internalSize = storage.internalDataSize {
                                    Divider()
                                    StorageRow(label: String(localized: "内部データ使用量 (参考)"), size: internalSize, color: .gray)
                                        .opacity(0.7)
                                }
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("※ 合計 = アプリ本体 + ディスクイメージファイル")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if storage.internalDataSize != nil {
                                    Text("※ 内部データ使用量は合計に含まれません")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Quick Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("基本情報")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            QuickInfoRow(icon: "checkmark.seal.fill", label: "Bundle ID", value: app.bundleIdentifier)
                            
                            if let executableName = infoPlist?["CFBundleExecutable"] as? String {
                                QuickInfoRow(icon: "gearshape.fill", label: String(localized: "実行ファイル"), value: executableName)
                            }
                            
                            if let capabilities = getCapabilitiesCount() {
                                QuickInfoRow(icon: "lock.shield.fill", label: String(localized: "権限要求"), value: "\(capabilities) 個")
                            }
                        }
                        .padding(12)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                    }
                    
                    // Quick Actions
                    VStack(spacing: 8) {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
                        } label: {
                            HStack {
                                Image(systemName: "folder")
                                Text("アプリ本体を Finder で表示")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        Button {
                            let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
                            if FileManager.default.fileExists(atPath: containerURL.path) {
                                NSWorkspace.shared.activateFileViewerSelecting([containerURL])
                            }
                        } label: {
                            HStack {
                                Image(systemName: "externaldrive")
                                Text("コンテナを Finder で表示")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadData()
        }
    }
    
    private func loadData() {
        // Load Info.plist
        if let bundle = Bundle(url: app.appURL),
           let info = bundle.infoDictionary {
            infoPlist = info
        }
        
        // Calculate storage
        storageInfo = getStorageInfo()
    }
    
    private func getDeviceFamily() -> String? {
        guard let deviceFamily = infoPlist?["UIDeviceFamily"] as? [Int] else { return nil }
        
        let devices = deviceFamily.compactMap { family -> String? in
            switch family {
            case 1: return "iPhone"
            case 2: return "iPad"
            default: return nil
            }
        }
        
        return devices.isEmpty ? nil : devices.joined(separator: " / ")
    }
    
    private func getCapabilitiesCount() -> Int? {
        let permissionKeys = [
            "NSCameraUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSMicrophoneUsageDescription",
            "NSLocationWhenInUseUsageDescription",
            "NSLocationAlwaysUsageDescription",
            "NSContactsUsageDescription",
            "NSCalendarsUsageDescription",
            "NSRemindersUsageDescription",
            "NSMotionUsageDescription",
            "NSBluetoothAlwaysUsageDescription",
            "NSSiriUsageDescription",
            "NSFaceIDUsageDescription"
        ]
        
        var count = 0
        for key in permissionKeys {
            if infoPlist?[key] != nil {
                count += 1
            }
        }
        
        if let backgroundModes = infoPlist?["UIBackgroundModes"] as? [String] {
            count += backgroundModes.count
        }
        
        return count > 0 ? count : nil
    }
    
    private func getStorageInfo() -> StorageInfo? {
        let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
        
        guard let appSize = calculateDirectorySize(at: app.appURL) else {
            return nil
        }
        
        // All apps use disk images - get disk image state
        guard let diskImageState = try? DiskImageHelper.checkDiskImageState(
            for: app.bundleIdentifier,
            containerURL: containerURL,
            diskImageService: viewModel.diskImageService
        ) else {
            return nil
        }
        
        let diskImagePath = diskImageState.descriptor.imageURL.path
        let diskImageSize: String
        if let sizeOnDisk = diskImageState.descriptor.sizeOnDisk {
            diskImageSize = ByteCountFormatter.string(fromByteCount: Int64(sizeOnDisk), countStyle: .file)
        } else if diskImageState.imageExists {
            diskImageSize = calculateDirectorySize(at: diskImageState.descriptor.imageURL) ?? String(localized: "不明")
        } else {
            diskImageSize = String(localized: "未作成")
        }
        
        // Calculate internal data size only when not mounted
        let internalDataSize: String?
        if !diskImageState.isMounted, let volumePath = diskImageState.descriptor.volumePath {
            internalDataSize = calculateDirectorySize(at: volumePath)
        } else if !diskImageState.isMounted {
            internalDataSize = calculateDirectorySize(at: containerURL)
        } else {
            internalDataSize = nil
        }
        
        // Total = app + disk image file size
        let totalSize: String
        if diskImageSize != String(localized: "未作成"),
           let appBytes = parseByteCount(appSize),
           let imageBytes = parseByteCount(diskImageSize) {
            let total = appBytes + imageBytes
            totalSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        } else {
            totalSize = appSize
        }
        
        return StorageInfo(
            appPath: app.appURL.path,
            appSize: appSize,
            containerPath: diskImagePath,
            containerSize: diskImageSize,
            totalSize: totalSize,
            internalDataSize: internalDataSize,
            isMounted: diskImageState.isMounted
        )
    }
    
    private func calculateDirectorySize(at url: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private func parseByteCount(_ sizeString: String) -> Int64? {
        let components = sizeString.components(separatedBy: " ")
        guard components.count == 2,
              let value = Double(components[0].replacingOccurrences(of: ",", with: "")) else {
            return nil
        }
        
        let multiplier: Int64
        switch components[1].uppercased() {
        case "BYTES", "バイト": multiplier = 1
        case "KB": multiplier = 1000
        case "MB": multiplier = 1000 * 1000
        case "GB": multiplier = 1000 * 1000 * 1000
        case "TB": multiplier = 1000 * 1000 * 1000 * 1000
        default: return nil
        }
        
        return Int64(value * Double(multiplier))
    }
}

// MARK: - Overview Supporting Views

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

private struct StorageRow: View {
    let label: String
    let size: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(size)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

private struct QuickInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Basic Settings Tab

private struct SettingsView: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @Environment(SettingsStore.self) private var settingsStore
    
    @State private var nobrowseOverride: NobrowseOverride = .useGlobal
    @State private var dataHandlingOverride: DataHandlingOverride = .useGlobal
    @State private var languageOverride: String? = nil  // nil = system default, or language code like "ja", "en"
    @State private var supportedLanguages: [String] = []
    
    enum NobrowseOverride: String, CaseIterable, Identifiable {
        case useGlobal
        case enabled
        case disabled
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .useGlobal: return String(localized: "グローバル設定を使用")
            case .enabled: return String(localized: "Finderに表示しない")
            case .disabled: return String(localized: "Finderに表示する")
            }
        }
    }
    
    enum DataHandlingOverride: String, CaseIterable, Identifiable {
        case useGlobal
        case discard
        case mergeThenDelete
        case leave
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .useGlobal: return String(localized: "グローバル設定を使用")
            case .discard: return String(localized: "内部データを破棄")
            case .mergeThenDelete: return String(localized: "内部データを統合")
            case .leave: return String(localized: "何もしない")
            }
        }
        
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
            Text("アプリ設定")
                .font(.headline)
            
            // Nobrowse setting
            VStack(alignment: .leading, spacing: 8) {
                Text("Finder での表示設定")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("", selection: $nobrowseOverride) {
                    ForEach(NobrowseOverride.allCases) { option in
                        Text(option.localizedTitle).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: nobrowseOverride) { _, newValue in
                    saveNobrowseSetting(newValue)
                }
                
                Text("このアプリのディスクイメージを Finder に表示するかどうかを設定します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if nobrowseOverride == .useGlobal {
                    Text("現在のグローバル設定: \(settingsStore.nobrowseEnabled ? "Finderに表示しない" : "Finderに表示する")")
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
                        Text(option.localizedTitle).tag(option)
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
            
            // Language setting
            if !supportedLanguages.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("アプリの言語設定")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("", selection: $languageOverride) {
                        Text("システムデフォルト").tag(nil as String?)
                        ForEach(supportedLanguages, id: \.self) { lang in
                            Text(getLanguageDisplayName(lang)).tag(lang as String?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: languageOverride) { _, newValue in
                        saveLanguageSetting(newValue)
                    }
                    
                    Text("このアプリで使用する言語を設定します。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if languageOverride == nil {
                        let systemLangs = Locale.preferredLanguages
                        if let primaryLang = systemLangs.first {
                            // Extract language code from locale identifier (e.g., "ja-JP" -> "ja")
                            let langCode = primaryLang.components(separatedBy: "-").first ?? primaryLang
                            Text("現在のシステム言語: \(getLanguageDisplayName(langCode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
            }
            
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
            // Load supported languages first, then current settings
            loadSupportedLanguages()
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
        
        // Load language setting
        if let savedLanguage = settings.preferredLanguage {
            // Normalize saved language code to match current picker options
            let normalized = normalizeLanguageCode(savedLanguage)
            
            // Check if normalized code exists in current supported languages
            if supportedLanguages.contains(normalized) {
                languageOverride = normalized
            } else {
                // Saved language not available, reset to default
                languageOverride = nil
                Logger.debug("Saved language '\(savedLanguage)' (normalized: '\(normalized)') not in current supported languages, resetting to default")
            }
        } else {
            languageOverride = nil
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
    
    private func saveLanguageSetting(_ language: String?) {
        let perAppSettings = viewModel.getPerAppSettings()
        perAppSettings.setPreferredLanguage(language, for: app.bundleIdentifier)
    }
    
    private func loadSupportedLanguages() {
        guard let bundle = Bundle(url: app.appURL),
              let infoPlist = bundle.infoDictionary else {
            Logger.debug("Failed to load bundle or infoPlist for \(app.displayName)")
            return
        }
        
        var languages: [String] = []
        
        // Get CFBundleLocalizations
        if let localizations = infoPlist["CFBundleLocalizations"] as? [String] {
            languages.append(contentsOf: localizations)
            Logger.debug("Found CFBundleLocalizations: \(localizations)")
        } else {
            Logger.debug("No CFBundleLocalizations found in Info.plist")
        }
        
        // Include development region
        if let devRegion = infoPlist["CFBundleDevelopmentRegion"] as? String {
            if !languages.contains(devRegion) {
                languages.insert(devRegion, at: 0)
            }
            Logger.debug("Found CFBundleDevelopmentRegion: \(devRegion)")
        }
        
        // Always scan for .lproj directories as primary source if Info.plist doesn't have full list
        // Many iOS apps don't populate CFBundleLocalizations properly
        if languages.count < 3 {  // If we only have 1-2 languages, likely Info.plist is incomplete
            Logger.debug("Info.plist has limited language info (\(languages.count) languages), scanning .lproj directories...")
            let lprojLanguages = scanLprojDirectories()
            
            // Merge with existing languages
            for lang in lprojLanguages {
                if !languages.contains(lang) {
                    languages.append(lang)
                }
            }
        }
        
        supportedLanguages = languages
        Logger.debug("Final supported languages for \(app.displayName): \(languages)")
    }
    
    private func scanLprojDirectories() -> [String] {
        var rawLanguages: [String] = []
        
        // Recursively scan for .lproj directories (same as analysis)
        guard let enumerator = FileManager.default.enumerator(
            at: app.appURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            Logger.debug("Failed to create enumerator for \(app.appURL.path)")
            return []
        }
        
        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "lproj" {
                let langCode = fileURL.deletingPathExtension().lastPathComponent
                // Convert Base.lproj to en
                let normalizedCode = langCode == "Base" ? "en" : langCode
                rawLanguages.append(normalizedCode)
            }
        }
        
        Logger.debug("Found raw .lproj directories: \(rawLanguages)")
        
        // Normalize and deduplicate language codes
        let normalizedLanguages = normalizeLanguageCodes(rawLanguages)
        Logger.debug("Normalized languages: \(normalizedLanguages)")
        
        return normalizedLanguages.sorted()
    }
    
    private func normalizeLanguageCodes(_ codes: [String]) -> [String] {
        var normalizedSet: Set<String> = []
        
        for code in codes {
            let normalized = normalizeLanguageCode(code)
            normalizedSet.insert(normalized)
        }
        
        return Array(normalizedSet)
    }
    /// Normalize language code using Apple's canonical identifier system
    /// - Handles Chinese script variants (Hans/Hant) properly
    /// - Removes unnecessary region codes while preserving important ones
    /// - Uses Locale.canonicalLanguageIdentifier for standard processing
    private func normalizeLanguageCode(_ code: String) -> String {
        // For Chinese, explicitly preserve script subtags (Hans/Hant)
        // zh-CN -> zh-Hans, zh-TW -> zh-Hant, zh-HK -> zh-Hant
        if code.hasPrefix("zh") {
            if code.contains("Hans") {
                return "zh-Hans"  // Already has script, keep it
            } else if code.contains("Hant") {
                return "zh-Hant"  // Already has script, keep it
            } else if code == "zh-CN" || code == "zh-SG" {
                return "zh-Hans"  // Mainland China/Singapore use Simplified
            } else if code == "zh-TW" || code == "zh-HK" || code == "zh-MO" {
                return "zh-Hant"  // Taiwan/Hong Kong/Macau use Traditional
            } else if code == "zh" {
                return "zh-Hans"  // Default to Simplified
            }
        }
        
        // For Cantonese, preserve script subtags
        if code.hasPrefix("yue") {
            if code.contains("Hans") {
                return "yue-Hans"
            } else if code.contains("Hant") {
                return "yue-Hant"
            }
        }
        
        // For Portuguese, keep pt-BR distinct from pt
        if code == "pt-BR" {
            return "pt-BR"
        } else if code.hasPrefix("pt") {
            return "pt"
        }
        
        // Use Apple's canonical identifier for standard processing
        // This handles most language variants automatically
        let canonical = Locale.canonicalLanguageIdentifier(from: code)
        
        // For languages with script variants, keep them
        if canonical.contains("-Hans") || canonical.contains("-Hant") {
            return canonical
        }
        
        // For most languages, strip region code (e.g., en-US -> en, es-ES -> es)
        // But keep exceptions like pt-BR
        if canonical.contains("-") && canonical != "pt-BR" && !canonical.contains("yue") {
            return canonical.components(separatedBy: "-").first ?? canonical
        }
        
        return canonical
    }
    
    /// Get language display name localized to current UI language
    /// - Uses Locale.current to show language names in the current UI language
    /// - For app-specific language settings, this shows names like:
    ///   * Japanese UI: "日本語", "英語", "中国語（簡体字）"
    ///   * Chinese UI: "日语", "英语", "简体中文"
    ///   * English UI: "Japanese", "English", "Simplified Chinese"
    private func getLanguageDisplayName(_ code: String) -> String {
        let locale = Locale.current
        
        // Use localizedString(forIdentifier:) which properly handles script variants
        // This is the correct API for getting full locale display names including script
        if let displayName = locale.localizedString(forIdentifier: code) {
            return displayName
        }
        
        // Special cases: Cantonese with script variants
        // These are not standard and need manual handling
        if code == "yue-Hans" {
            // In current UI language
            if let yueName = locale.localizedString(forLanguageCode: "yue") {
                return "\(yueName) (简体)"  // Show script in Chinese
            }
            return "粵語 (简体)"
        } else if code == "yue-Hant" {
            if let yueName = locale.localizedString(forLanguageCode: "yue") {
                return "\(yueName) (繁體)"
            }
            return "粵語 (繁體)"
        }
        
        // For all other languages with variants (including pt-BR, Chinese, etc.),
        // localizedString(forIdentifier:) handles them properly
        // It automatically formats as "Language (Region)" or "Language (Script)" as appropriate
        return locale.localizedString(forLanguageCode: code) ?? code
    }
    
    private func resetToGlobalDefaults() {
        let perAppSettings = viewModel.getPerAppSettings()
        perAppSettings.removeSettings(for: app.bundleIdentifier)
        nobrowseOverride = .useGlobal
        dataHandlingOverride = .useGlobal
        languageOverride = nil
    }
}

// MARK: - Info Tab

private struct DetailsView: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @State private var infoPlist: [String: Any]?
    @State private var selectedSection: DetailSection = .info
    
    enum DetailSection: String, CaseIterable, Identifiable {
        case info
        case analysis
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .info: return String(localized: "技術情報")
            case .analysis: return String(localized: "解析")
            }
        }
        
        var icon: String {
            switch self {
            case .info: return "info.circle"
            case .analysis: return "chart.bar.doc.horizontal"
            }
        }
    }
    
    init(app: PlayCoverApp, viewModel: LauncherViewModel) {
        self.app = app
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("詳細情報")
                .font(.headline)
            
            // Sub-section selector
            Picker("", selection: $selectedSection) {
                ForEach(DetailSection.allCases) { section in
                    Label(section.localizedTitle, systemImage: section.icon).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            
            ScrollView {
                switch selectedSection {
                case .info:
                    InfoContentView(app: app, viewModel: viewModel, infoPlist: $infoPlist)
                case .analysis:
                    AnalysisContentView(app: app)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            loadInfoPlist()
        }
    }
    
    private func loadInfoPlist() {
        guard let bundle = Bundle(url: app.appURL),
              let info = bundle.infoDictionary else { return }
        infoPlist = info
    }
}

// MARK: - Info Content View
private struct InfoContentView: View {
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @Binding var infoPlist: [String: Any]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Basic Info Section
            infoSection(title: String(localized: "基本情報")) {
                infoRow(label: String(localized: "アプリ名"), value: app.displayName)
                if let standardName = app.standardName, standardName != app.displayName {
                    infoRow(label: String(localized: "英語名"), value: standardName)
                }
                infoRow(label: "Bundle ID", value: app.bundleIdentifier)
                if let version = app.version {
                    infoRow(label: String(localized: "バージョン"), value: version)
                }
                if let buildVersion = infoPlist?["CFBundleVersion"] as? String, buildVersion != app.version {
                    infoRow(label: String(localized: "ビルド番号"), value: buildVersion)
                }
            }
            
            // Technical Info Section
            infoSection(title: String(localized: "技術情報")) {
                if let executableName = infoPlist?["CFBundleExecutable"] as? String {
                    infoRow(label: String(localized: "実行ファイル"), value: executableName)
                }
                if let minOSVersion = infoPlist?["MinimumOSVersion"] as? String {
                    infoRow(label: String(localized: "最小iOS"), value: minOSVersion)
                }
                if let targetDevice = getTargetDeviceFamily() {
                    infoRow(label: String(localized: "対応デバイス"), value: targetDevice)
                }
                if let packageType = infoPlist?["CFBundlePackageType"] as? String {
                    infoRow(label: String(localized: "パッケージ種別"), value: packageType)
                }
            }
            
            // Capabilities Section
            if let capabilities = getCapabilities() {
                infoSection(title: String(localized: "機能・権限")) {
                    ForEach(Array(capabilities.enumerated()), id: \.offset) { _, capability in
                        Text("• \(capability)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Developer Info Section
            infoSection(title: String(localized: "開発者情報")) {
                if let copyright = infoPlist?["NSHumanReadableCopyright"] as? String {
                    infoRow(label: String(localized: "著作権"), value: copyright)
                }
                if let teamId = getTeamIdentifier() {
                    infoRow(label: "Team ID", value: teamId)
                }
            }
            
            // Storage Info Section
            if let storageInfo = getStorageInfo() {
                infoSection(title: String(localized: "ストレージ情報")) {
                    // App bundle
                    VStack(alignment: .leading, spacing: 4) {
                        Text("アプリ本体")
                            .font(.caption)
                            .fontWeight(.medium)
                        infoRow(label: String(localized: "所在地"), value: storageInfo.appPath)
                        infoRow(label: String(localized: "使用容量"), value: storageInfo.appSize)
                        Button("アプリ本体を表示") {
                            NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Disk image
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ディスクイメージ")
                            .font(.caption)
                            .fontWeight(.medium)
                        infoRow(label: String(localized: "所在地"), value: storageInfo.containerPath)
                        infoRow(label: String(localized: "ファイルサイズ"), value: storageInfo.containerSize)
                        infoRow(label: String(localized: "マウント状態"), value: storageInfo.isMounted ? "マウント中" : "アンマウント中")
                        Button("ディスクイメージを表示") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: storageInfo.containerPath)])
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                    
                    // Internal data usage (reference only, when unmounted)
                    if let internalSize = storageInfo.internalDataSize {
                        Divider()
                            .padding(.vertical, 4)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("内部データ (参考情報)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            infoRow(label: String(localized: "使用量"), value: internalSize)
                                .foregroundStyle(.secondary)
                            Text("※ イメージ内のデータ使用量（合計に含まれません）")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    // Total
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("合計使用容量:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(storageInfo.totalSize)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                        }
                        Text("※ アプリ本体 + ディスクイメージファイル")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private func infoSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .trailing)
            
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func getTargetDeviceFamily() -> String? {
        guard let deviceFamily = infoPlist?["UIDeviceFamily"] as? [Int] else { return nil }
        
        let devices = deviceFamily.compactMap { family -> String? in
            switch family {
            case 1: return "iPhone"
            case 2: return "iPad"
            case 3: return "Apple TV"
            case 4: return "Apple Watch"
            default: return nil
            }
        }
        
        return devices.isEmpty ? nil : devices.joined(separator: ", ")
    }
    
    private func getCapabilities() -> [String]? {
        var capabilities: [String] = []
        
        // Check for common permissions
        let permissionKeys: [String: String] = [
            "NSCameraUsageDescription": String(localized: "カメラ"),
            "NSPhotoLibraryUsageDescription": String(localized: "写真ライブラリ"),
            "NSMicrophoneUsageDescription": String(localized: "マイク"),
            "NSLocationWhenInUseUsageDescription": String(localized: "位置情報（使用中）"),
            "NSLocationAlwaysUsageDescription": String(localized: "位置情報（常に）"),
            "NSContactsUsageDescription": String(localized: "連絡先"),
            "NSCalendarsUsageDescription": String(localized: "カレンダー"),
            "NSRemindersUsageDescription": String(localized: "リマインダー"),
            "NSMotionUsageDescription": String(localized: "モーションセンサー"),
            "NSBluetoothAlwaysUsageDescription": "Bluetooth",
            "NSSiriUsageDescription": "Siri",
            "NSFaceIDUsageDescription": "Face ID"
        ]
        
        for (key, name) in permissionKeys {
            if infoPlist?[key] != nil {
                capabilities.append(name)
            }
        }
        
        // Check for background modes
        if let backgroundModes = infoPlist?["UIBackgroundModes"] as? [String] {
            for mode in backgroundModes {
                switch mode {
                case "audio": capabilities.append(String(localized: "バックグラウンド音声"))
                case "location": capabilities.append(String(localized: "バックグラウンド位置情報"))
                case "voip": capabilities.append("VoIP")
                case "fetch": capabilities.append(String(localized: "バックグラウンド取得"))
                case "remote-notification": capabilities.append(String(localized: "リモート通知"))
                default: break
                }
            }
        }
        
        return capabilities.isEmpty ? nil : capabilities
    }
    
    private func getTeamIdentifier() -> String? {
        // Try to read team ID from embedded.mobileprovision or code signature
        let provisionPath = app.appURL.appendingPathComponent("embedded.mobileprovision")
        guard FileManager.default.fileExists(atPath: provisionPath.path),
              let provisionData = try? Data(contentsOf: provisionPath),
              let provisionString = String(data: provisionData, encoding: .ascii) else {
            return nil
        }
        
        // Simple regex to extract team identifier (this is a simplified approach)
        if let range = provisionString.range(of: "<key>TeamIdentifier</key>\\s*<array>\\s*<string>([A-Z0-9]+)</string>", options: .regularExpression) {
            let match = String(provisionString[range])
            if let idRange = match.range(of: "[A-Z0-9]{10}", options: .regularExpression) {
                return String(match[idRange])
            }
        }
        
        return nil
    }
    
    private func getSupportedLanguages() -> [String] {
        guard let infoPlist = infoPlist else { return [] }
        
        var languages: [String] = []
        
        // Get CFBundleLocalizations (list of supported localizations)
        if let localizations = infoPlist["CFBundleLocalizations"] as? [String] {
            languages.append(contentsOf: localizations)
        }
        
        // Also include development region as fallback
        if let devRegion = infoPlist["CFBundleDevelopmentRegion"] as? String {
            if !languages.contains(devRegion) {
                languages.insert(devRegion, at: 0)
            }
        }
        
        return languages
    }
    
    private func getAppSize() -> String? {
        return calculateDirectorySize(at: app.appURL)
    }
    
    private func calculateDirectorySize(at url: URL) -> String? {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private func getStorageInfo() -> StorageInfo? {
        let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
        
        // Get app size
        guard let appSize = calculateDirectorySize(at: app.appURL) else {
            return nil
        }
        
        // All apps use disk images - get disk image state
        guard let diskImageState = try? DiskImageHelper.checkDiskImageState(
            for: app.bundleIdentifier,
            containerURL: containerURL,
            diskImageService: viewModel.diskImageService
        ) else {
            return nil
        }
        
        let diskImagePath = diskImageState.descriptor.imageURL.path
        let diskImageSize: String
        if let sizeOnDisk = diskImageState.descriptor.sizeOnDisk {
            diskImageSize = ByteCountFormatter.string(fromByteCount: Int64(sizeOnDisk), countStyle: .file)
        } else if diskImageState.imageExists {
            diskImageSize = calculateDirectorySize(at: diskImageState.descriptor.imageURL) ?? String(localized: "不明")
        } else {
            diskImageSize = String(localized: "未作成")
        }
        
        // Calculate internal data size only when not mounted
        let internalDataSize: String?
        if !diskImageState.isMounted, let volumePath = diskImageState.descriptor.volumePath {
            internalDataSize = calculateDirectorySize(at: volumePath)
        } else if !diskImageState.isMounted {
            internalDataSize = calculateDirectorySize(at: containerURL)
        } else {
            internalDataSize = nil
        }
        
        // Total = app + disk image file size
        let totalSize: String
        if diskImageSize != String(localized: "未作成"),
           let appBytes = parseByteCount(appSize),
           let imageBytes = parseByteCount(diskImageSize) {
            let total = appBytes + imageBytes
            totalSize = ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
        } else {
            totalSize = appSize
        }
        
        return StorageInfo(
            appPath: app.appURL.path,
            appSize: appSize,
            containerPath: diskImagePath,
            containerSize: diskImageSize,
            totalSize: totalSize,
            internalDataSize: internalDataSize,
            isMounted: diskImageState.isMounted
        )
    }
    
    private func parseByteCount(_ sizeString: String) -> Int64? {
        // Simple parser for byte count strings like "123.4 MB"
        let components = sizeString.components(separatedBy: " ")
        guard components.count == 2,
              let value = Double(components[0].replacingOccurrences(of: ",", with: "")) else {
            return nil
        }
        
        let multiplier: Int64
        switch components[1].uppercased() {
        case "BYTES", "バイト": multiplier = 1
        case "KB": multiplier = 1000
        case "MB": multiplier = 1000 * 1000
        case "GB": multiplier = 1000 * 1000 * 1000
        case "TB": multiplier = 1000 * 1000 * 1000 * 1000
        default: return nil
        }
        
        return Int64(value * Double(multiplier))
    }
}

// MARK: - Storage Info

struct StorageInfo {
    let appPath: String
    let appSize: String
    let containerPath: String       // Disk image path
    let containerSize: String       // Disk image size
    let totalSize: String
    let internalDataSize: String?   // Internal usage when unmounted
    let isMounted: Bool
}

// MARK: - Analysis Content View

private struct AnalysisContentView: View {
    let app: PlayCoverApp
    @State private var analyzing = false
    @State private var analysisResult: AppAnalysisResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("アプリ解析")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if analyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                Button(analyzing ? "解析中..." : "再解析") {
                    Task { await performAnalysis() }
                }
                .disabled(analyzing)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            if let result = analysisResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Bundle Structure
                        analysisSection(title: String(localized: "バンドル構造"), icon: "folder.fill") {
                            infoRow(label: String(localized: "総ファイル数"), value: "\(result.totalFiles) 個")
                            infoRow(label: String(localized: "総サイズ"), value: result.totalSize)
                            infoRow(label: String(localized: "最大ファイル"), value: result.largestFile.name)
                            infoRow(label: String(localized: "最大ファイルサイズ"), value: result.largestFile.size)
                        }
                        
                        // Localization
                        if !result.localizations.isEmpty {
                            analysisSection(title: String(localized: "対応言語 (\(result.localizations.count))"), icon: "globe") {
                                ForEach(result.localizations.sorted(), id: \.self) { lang in
                                    Text("• \(getLanguageName(lang))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Frameworks & Libraries
                        if !result.frameworks.isEmpty {
                            analysisSection(title: String(localized: "フレームワーク (\(result.frameworks.count))"), icon: "shippingbox.fill") {
                                ForEach(result.frameworks.sorted(), id: \.self) { framework in
                                    Text("• \(framework)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Code Signature
                        analysisSection(title: String(localized: "コード署名"), icon: "signature") {
                            infoRow(label: String(localized: "署名状態"), value: result.codeSignature.isSigned ? "署名済み" : "未署名")
                            if let teamId = result.codeSignature.teamIdentifier {
                                infoRow(label: "Team ID", value: teamId)
                            }
                            if let signDate = result.codeSignature.signDate {
                                infoRow(label: String(localized: "署名日"), value: signDate)
                            }
                        }
                        
                        // Entitlements
                        if !result.entitlements.isEmpty {
                            analysisSection(title: "Entitlements (\(result.entitlements.count))", icon: "key.fill") {
                                ForEach(result.entitlements.sorted(), id: \.self) { entitlement in
                                    Text("• \(entitlement)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Binary Info
                        if let binary = result.binaryInfo {
                            analysisSection(title: String(localized: "バイナリ情報"), icon: "cpu") {
                                infoRow(label: String(localized: "アーキテクチャ"), value: binary.architectures.joined(separator: ", "))
                                infoRow(label: String(localized: "バイナリサイズ"), value: binary.size)
                                if let minOS = binary.minOSVersion {
                                    infoRow(label: String(localized: "最小OS"), value: minOS)
                                }
                            }
                        }
                        
                        // File Types
                        if !result.fileTypes.isEmpty {
                            analysisSection(title: String(localized: "ファイル種別"), icon: "doc.fill") {
                                ForEach(result.fileTypes.sorted(by: { $0.count > $1.count }), id: \.fileExtension) { fileType in
                                    HStack {
                                        Text(fileType.fileExtension.isEmpty ? "(拡張子なし)" : ".\(fileType.fileExtension)")
                                            .font(.caption)
                                            .frame(width: 80, alignment: .leading)
                                        Text("\(fileType.count) 個")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(fileType.totalSize)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    
                    Text("アプリを解析して詳細情報を表示します")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button("解析開始") {
                        Task { await performAnalysis() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            if analysisResult == nil {
                Task { await performAnalysis() }
            }
        }
    }
    
    @ViewBuilder
    private func analysisSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(label):")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .trailing)
            
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func performAnalysis() async {
        analyzing = true
        defer { analyzing = false }
        
        let analyzer = AppAnalyzer()
        analysisResult = await analyzer.analyze(appURL: app.appURL)
    }
    
    private func getLanguageName(_ code: String) -> String {
        let locale = Locale(identifier: "ja")
        return locale.localizedString(forIdentifier: code) ?? code
    }
}

// MARK: - App Analysis Models

struct AppAnalysisResult {
    var totalFiles: Int
    var totalSize: String
    var largestFile: (name: String, size: String)
    var localizations: [String]
    var frameworks: [String]
    var codeSignature: CodeSignatureInfo
    var entitlements: [String]
    var binaryInfo: BinaryInfo?
    var fileTypes: [FileTypeInfo]
}

struct CodeSignatureInfo {
    var isSigned: Bool
    var teamIdentifier: String?
    var signDate: String?
}

struct BinaryInfo {
    var architectures: [String]
    var size: String
    var minOSVersion: String?
}

struct FileTypeInfo {
    var fileExtension: String
    var count: Int
    var totalSize: String
}

// MARK: - App Analyzer

actor AppAnalyzer {
    func analyze(appURL: URL) async -> AppAnalysisResult {
        // Run file enumeration in detached task to avoid async context issues
        // and enable memory-efficient streaming
        return await Task.detached(priority: .utility) {
            await self.analyzeInternal(appURL: appURL)
        }.value
    }
    
    // Helper function to enumerate files synchronously (Swift 6 compatibility)
    nonisolated private func enumerateFilesSynchronously(at url: URL) -> [URL] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        // Synchronously collect all URLs - this avoids async context issues
        return enumerator.compactMap { $0 as? URL }
    }
    
    private func analyzeInternal(appURL: URL) async -> AppAnalysisResult {
        var totalFiles = 0
        var totalBytes: Int64 = 0
        var largestFile: (url: URL, size: Int64) = (appURL, 0)
        var localizations: Set<String> = []
        var frameworks: Set<String> = []
        var fileTypeMap: [String: (count: Int, bytes: Int64)] = [:]
        
        // Enumerate all files synchronously to avoid Swift 6 async context issues
        let allFileURLs = enumerateFilesSynchronously(at: appURL)
        
        // Process all files
        for fileURL in allFileURLs {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]),
                      let isDirectory = resourceValues.isDirectory else {
                    continue
                }
                
                if !isDirectory {
                    totalFiles += 1
                    
                    if let fileSize = resourceValues.fileSize {
                        let bytes = Int64(fileSize)
                        totalBytes += bytes
                        
                        if bytes > largestFile.size {
                            largestFile = (fileURL, bytes)
                        }
                        
                        // Track file types
                        let ext = fileURL.pathExtension.lowercased()
                        let current = fileTypeMap[ext] ?? (0, 0)
                        fileTypeMap[ext] = (current.count + 1, current.bytes + bytes)
                    }
                }
                
                // Check for localization
                if fileURL.pathExtension == "lproj" {
                    let langCode = fileURL.deletingPathExtension().lastPathComponent
                    // Normalize Base.lproj to en
                    let normalizedCode = langCode == "Base" ? "en" : langCode
                    localizations.insert(normalizedCode)
                }
                
                // Check for frameworks
                if fileURL.pathExtension == "framework" {
                    frameworks.insert(fileURL.deletingPathExtension().lastPathComponent)
                }
        }
        
        // Get code signature info
        let codeSignature = await getCodeSignature(appURL: appURL)
        
        // Get entitlements
        let entitlements = await getEntitlements(appURL: appURL)
        
        // Get binary info
        let binaryInfo = await getBinaryInfo(appURL: appURL)
        
        // Convert file types
        let fileTypes = Array(fileTypeMap).map { ext, info in
            FileTypeInfo(
                fileExtension: ext,
                count: info.count,
                totalSize: ByteCountFormatter.string(fromByteCount: info.bytes, countStyle: .file)
            )
        }
        
        return AppAnalysisResult(
            totalFiles: totalFiles,
            totalSize: ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file),
            largestFile: (
                name: largestFile.url.lastPathComponent,
                size: ByteCountFormatter.string(fromByteCount: largestFile.size, countStyle: .file)
            ),
            localizations: Array(localizations),
            frameworks: Array(frameworks),
            codeSignature: codeSignature,
            entitlements: entitlements,
            binaryInfo: binaryInfo,
            fileTypes: fileTypes
        )
    }
    
    private func getCodeSignature(appURL: URL) async -> CodeSignatureInfo {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dv", "--verbose=4", appURL.path]
        
        let pipe = Pipe()
        process.standardError = pipe
        
        var isSigned = false
        var teamId: String?
        var signDate: String?
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                isSigned = output.contains("Signature=")
                
                // Extract team identifier
                if let range = output.range(of: "TeamIdentifier=([A-Z0-9]+)", options: .regularExpression) {
                    let match = String(output[range])
                    teamId = match.components(separatedBy: "=").last
                }
                
                // Extract signing time
                if let range = output.range(of: "Signing Time=([^\n]+)", options: .regularExpression) {
                    let match = String(output[range])
                    signDate = match.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces)
                }
            }
        } catch {
            // Failed to check signature
        }
        
        return CodeSignatureInfo(isSigned: isSigned, teamIdentifier: teamId, signDate: signDate)
    }
    
    private func getEntitlements(appURL: URL) async -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-d", "--entitlements", ":-", appURL.path]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        var entitlements: [String] = []
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = data.parsePlist() {
                entitlements = plist.keys.sorted()
            }
        } catch {
            // Failed to read entitlements
        }
        
        return entitlements
    }
    
    private func getBinaryInfo(appURL: URL) async -> BinaryInfo? {
        guard let bundle = Bundle(url: appURL),
              let executablePath = bundle.executablePath else {
            return nil
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = [executablePath]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        var architectures: [String] = []
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if output.contains("arm64") { architectures.append("ARM64") }
                if output.contains("x86_64") { architectures.append("x86_64") }
            }
        } catch {
            // Failed to check binary
        }
        
        // Get file size
        let fileURL = URL(fileURLWithPath: executablePath)
        guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
              let fileSize = resourceValues.fileSize else {
            return nil
        }
        
        // Get minimum OS version
        var minOS: String?
        if let infoPlist = bundle.infoDictionary,
           let minOSVersion = infoPlist["MinimumOSVersion"] as? String {
            minOS = "iOS \(minOSVersion)"
        }
        
        return BinaryInfo(
            architectures: architectures,
            size: ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file),
            minOSVersion: minOS
        )
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
                    title: String(localized: "PlayCover アプリを開く"),
                    help: String(localized: "PlayCover アプリを開く (⌘⇧P)")
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
                    title: String(localized: "IPA をインストール"),
                    help: String(localized: "IPA をインストール (⌘I)")
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
                    title: String(localized: "アプリをアンインストール"),
                    help: String(localized: "アプリをアンインストール (⌘D)")
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
                    title: String(localized: "設定"),
                    help: String(localized: "設定 (ショートカット)")
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
        .background(
            // Enhanced drawer with gradient glass
            ZStack {
                // Background glow
                LinearGradient(
                    colors: [.blue.opacity(0.05), .purple.opacity(0.03), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 30)
                
                // Main glass layer
                Rectangle()
                    .glassEffect(.regular.tint(.primary.opacity(0.08)), in: .rect)
            }
            .allowsHitTesting(false)  // Allow clicks through to drawer items
        )
        .overlay(alignment: .trailing) {
            // Enhanced separator with gradient
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .primary.opacity(0.15), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .frame(width: 1)
                .allowsHitTesting(false)  // Allow clicks through separator
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 4, y: 0)
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
        ShortcutItem(keys: "⌘,", description: String(localized: "設定を開く"), category: "グローバル"),
        ShortcutItem(keys: "⌘I", description: String(localized: "IPA をインストール"), category: "グローバル"),
        ShortcutItem(keys: "⌘D", description: String(localized: "アプリをアンインストール"), category: "グローバル"),
        ShortcutItem(keys: "⌘M", description: String(localized: "メニューを開く/閉じる"), category: "グローバル"),
        ShortcutItem(keys: "⌘R", description: String(localized: "アプリ一覧を更新"), category: "グローバル"),
        ShortcutItem(keys: "⌘⇧U", description: String(localized: "すべてマウント解除"), category: "グローバル"),
        ShortcutItem(keys: "⌘⇧P", description: String(localized: "PlayCover.app を開く"), category: "グローバル"),
        ShortcutItem(keys: "⌘/", description: String(localized: "このヘルプを表示"), category: "グローバル"),
        
        // Navigation
        ShortcutItem(keys: "↑↓←→", description: String(localized: "アプリ間を移動"), category: "ナビゲーション"),
        ShortcutItem(keys: "Enter / Space", description: String(localized: "フォーカスされたアプリを起動"), category: "ナビゲーション"),
        ShortcutItem(keys: "Escape", description: String(localized: "フォーカスをクリア"), category: "ナビゲーション"),
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
                .help(String(localized: "閉じる (Esc)"))
            }
            .padding(24)
            .glassEffect(.regular, in: .rect)
            
            Divider()
            
            // Shortcuts list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach([String(localized: "グローバル"), "ナビゲーション"], id: \.self) { category in
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
            .glassEffect(.regular, in: .rect)
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
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
        .onAppear { setupKeyboardMonitor() }
        .onDisappear { cleanupKeyboardMonitor() }
    }
    
    private func strategyDescription(for strategy: SettingsStore.InternalDataStrategy) -> String {
        switch strategy {
        case .discard:
            return String(localized: "内部データを破棄してから新しくマウントします")
        case .mergeThenDelete:
            return String(localized: "内部データをコンテナに統合してから削除してマウントします")
        case .leave:
            return String(localized: "内部データはそのまま残してマウントします")
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
