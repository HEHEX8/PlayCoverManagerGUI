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
    @State private var focusedColumn: Int = 0  // Column within the row (0-9)
    @FocusState private var isSearchFieldFocused: Bool  // Track if search field has focus
    @State private var eventMonitor: Any?  // For monitoring keyboard events
    @State private var showingShortcutGuide = false  // For keyboard shortcut cheat sheet
    @State private var windowSize: CGSize = CGSize(width: 960, height: 640)  // Track window size for responsive UI
    @State private var hoveredAppIndex: Int? = nil  // Track hovered app for enhanced feedback
    @State private var searchHistory: [String] = []  // Search history for quick access
    @State private var showingSearchSuggestions = false  // Show search suggestions dropdown
    
    // Fixed 10 columns per row (iOS Dock style)
    private var columnsPerRow: Int {
        return 10
    }
    
    // Calculate dynamic icon size based on available width and app count
    // Formula: (availableWidth - totalSpacing - sidePadding) / effectiveColumnCount
    private func calculateIconSize(for availableWidth: CGFloat, appCount: Int) -> CGFloat {
        let sidePadding: CGFloat = 64.0  // 32 padding on each side
        let minimumSpacing: CGFloat = 12.0
        
        // Determine effective column count based on app count
        let effectiveColumns: Int
        if appCount == 0 {
            effectiveColumns = 10  // Default
        } else if appCount <= 5 {
            // Very few apps: use actual count for larger icons
            effectiveColumns = min(appCount, 5)
        } else if appCount < 10 {
            // Less than 10 apps: use actual count for optimal spacing
            effectiveColumns = appCount
        } else {
            // 10 or more apps: use standard 10 columns
            effectiveColumns = 10
        }
        
        let spacingMultiplier = CGFloat(effectiveColumns - 1)
        let totalSpacing = minimumSpacing * spacingMultiplier
        
        let availableForIcons = availableWidth - sidePadding - totalSpacing
        let calculatedSize = availableForIcons / CGFloat(effectiveColumns)
        
        // Dynamic bounds based on app count
        let minSize: CGFloat = appCount <= 5 ? 80 : 60
        let maxSize: CGFloat = appCount <= 5 ? 200 : 150
        
        return max(minSize, min(maxSize, calculatedSize))
    }
    
    // Calculate dynamic spacing based on icon size and app count
    private func calculateSpacing(for iconSize: CGFloat, appCount: Int) -> CGFloat {
        // Spacing scales proportionally with icon size
        // Base: 20pt spacing at 100pt icon = 0.2 ratio
        // Increase spacing when fewer apps for more spacious layout
        let baseSpacing = iconSize * 0.2
        
        if appCount < 10 && appCount > 0 {
            // Add extra spacing when fewer than 10 apps
            return baseSpacing * 1.5
        }
        
        return baseSpacing
    }
    
    // Calculate dynamic font size based on icon size
    private func calculateFontSize(for iconSize: CGFloat) -> CGFloat {
        // Font scales proportionally with icon size
        // Base: 11pt font at 100pt icon = 0.11 ratio
        return iconSize * 0.11
    }
    
    // Calculate badge font size based on icon size
    private func calculateBadgeFontSize(for iconSize: CGFloat) -> CGFloat {
        // Badge font scales proportionally with icon size
        // Base: 12pt font at 100pt icon = 0.12 ratio
        return iconSize * 0.12
    }
    
    // Calculate badge size based on icon size
    private func calculateBadgeSize(for iconSize: CGFloat) -> CGFloat {
        // Badge size scales proportionally with icon size
        // Base: 20pt badge at 100pt icon = 0.2 ratio
        return iconSize * 0.2
    }
    
    // MARK: - UI Scale Calculations
    
    // Calculate overall UI scale factor based on window size
    // Base size: 960x640 (minimum) = scale 1.0
    // Returns scale factor between 1.0 and 2.0
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 960.0
        let baseHeight: CGFloat = 640.0
        
        // Calculate scale based on both width and height, use the smaller one
        let widthScale = size.width / baseWidth
        let heightScale = size.height / baseHeight
        let scale = min(widthScale, heightScale)
        
        // Clamp between 1.0 and 2.0 for reasonable scaling
        return max(1.0, min(2.0, scale))
    }
    
    // Calculated scaled values for UI elements
    private var uiScale: CGFloat {
        let scale = calculateUIScale(for: windowSize)
        print("🎯 uiScale computed property accessed: windowSize=\(windowSize.width)x\(windowSize.height), scale=\(scale)")
        return scale
    }
    
    // Toolbar dimensions
    private var toolbarHeight: CGFloat { 16 * uiScale }
    private var toolbarHorizontalPadding: CGFloat { 24 * uiScale }
    private var toolbarButtonSize: CGFloat { 44 * uiScale }
    private var toolbarButtonIconSize: CGFloat { 17 * uiScale }
    
    // Search field dimensions
    private var searchFieldMaxWidth: CGFloat { 400 * uiScale }
    private var searchFieldFontSize: CGFloat { 14 * uiScale }
    private var searchFieldPadding: CGFloat { 12 * uiScale }
    private var searchFieldVerticalPadding: CGFloat { 10 * uiScale }
    
    // Recent app button dimensions
    private var recentAppIconSize: CGFloat { 56 * uiScale }
    private var recentAppTitleFontSize: CGFloat { 17 * uiScale }
    private var recentAppSubtitleFontSize: CGFloat { 13 * uiScale }
    private var recentAppPadding: CGFloat { 20 * uiScale }
    
    // General spacing
    private var contentHorizontalPadding: CGFloat { 32 * uiScale }
    private var contentVerticalPadding: CGFloat { 24 * uiScale }
    
    // Current focused row (for multi-row navigation)
    @State private var focusedRow: Int = 0
    
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
    
    // Launch app at specific index with animation
    private func launchAppAtIndex(_ index: Int) {
        let apps = viewModel.filteredApps
        guard index < apps.count else { return }
        
        let app = apps[index]
        
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
        
        // Calculate total rows
        let totalRows = (apps.count + columnsPerRow - 1) / columnsPerRow
        
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
            focusedRow = 0
            focusedColumn = 0
            return true
        }
        
        // Handle number keys 1-9, 0 (key codes: 18-26 for 1-9, 29 for 0)
        // Map: 1=18, 2=19, 3=20, 4=21, 5=23, 6=22, 7=26, 8=28, 9=25, 0=29
        let numberKeyMap: [UInt16: Int] = [
            18: 0,  // 1 -> column 0
            19: 1,  // 2 -> column 1
            20: 2,  // 3 -> column 2
            21: 3,  // 4 -> column 3
            23: 4,  // 5 -> column 4
            22: 5,  // 6 -> column 5
            26: 6,  // 7 -> column 6
            28: 7,  // 8 -> column 7
            25: 8,  // 9 -> column 8
            29: 9   // 0 -> column 9
        ]
        
        if let column = numberKeyMap[keyCode] {
            // Calculate app index: row * 10 + column
            let targetIndex = focusedRow * columnsPerRow + column
            
            if targetIndex < apps.count {
                // Valid app at this position - launch it immediately
                focusedColumn = column
                focusedAppIndex = targetIndex
                launchAppAtIndex(targetIndex)
                return true
            }
            return false
        }
        
        // Handle up/down arrows - switch rows
        switch keyCode {
        case 125:  // Down arrow - next row
            if focusedRow < totalRows - 1 {
                focusedRow += 1
                // Update focused index to same column in new row
                let newIndex = focusedRow * columnsPerRow + focusedColumn
                // Clamp to valid range
                focusedAppIndex = min(newIndex, apps.count - 1)
                // Adjust column if we're at the last row and it's not full
                if focusedAppIndex! < apps.count {
                    focusedColumn = focusedAppIndex! % columnsPerRow
                }
            }
            return true
            
        case 126:  // Up arrow - previous row
            if focusedRow > 0 {
                focusedRow -= 1
                // Update focused index to same column in new row
                let newIndex = focusedRow * columnsPerRow + focusedColumn
                focusedAppIndex = newIndex
            }
            return true
            
        case 36, 49:  // Return (36) or Space (49)
            // Launch focused app with animation
            if let currentIndex = focusedAppIndex, currentIndex < apps.count {
                launchAppAtIndex(currentIndex)
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
    
    // MARK: - View Components
    
    @ViewBuilder
    private var backgroundLayer: some View {
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
                        .frame(width: 400 * uiScale, height: 400 * uiScale)
                        .blur(radius: 60 * uiScale)
                    
                    Spacer()
                    
                    Circle()
                        .fill(RadialGradient(
                            colors: [.purple.opacity(0.06), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        ))
                        .frame(width: 350 * uiScale, height: 350 * uiScale)
                        .blur(radius: 50 * uiScale)
                }
                Spacer()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
    
    @ViewBuilder
    private var toolbarView: some View {
        HStack(spacing: 16 * uiScale) {
            // Hamburger menu button
            ModernToolbarButton(
                icon: "line.3.horizontal",
                color: .primary,
                help: String(localized: "メニュー (⌘M)"),
                size: toolbarButtonSize,
                iconSize: toolbarButtonIconSize
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isDrawerOpen.toggle()
                }
            }
            .keyboardShortcut("m", modifiers: [.command])
            
            searchField
            
            Spacer()
            
            // Help button (shows keyboard shortcuts)
            ModernToolbarButton(
                icon: "questionmark.circle",
                color: .secondary,
                help: String(localized: "キーボードショートカット (⌘?)"),
                size: toolbarButtonSize,
                iconSize: toolbarButtonIconSize
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingShortcutGuide.toggle()
                }
            }
            .keyboardShortcut("/", modifiers: [.command])
            
            // Unmount All & Quit button with modern styling
            ModernToolbarButton(
                icon: "eject.circle",
                color: .orange,
                help: String(localized: "全イジェクト (⌘⇧E)"),
                size: toolbarButtonSize,
                iconSize: toolbarButtonIconSize
            ) {
                viewModel.unmountAll()
            }
            .keyboardShortcut(KeyEquivalent("e"), modifiers: [.command, .shift])
        }
        .padding(.horizontal, toolbarHorizontalPadding)
        .padding(.vertical, toolbarHeight)
        .background(toolbarBackground)
        .shadow(color: .black.opacity(0.08), radius: 12 * uiScale, x: 0, y: 4 * uiScale)
        .overlay(alignment: .bottom) {
            toolbarSeparator
        }
    }
    
    @ViewBuilder
    private var searchField: some View {
        HStack(spacing: 8 * uiScale) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: searchFieldFontSize, weight: .medium))
                .foregroundStyle(.secondary)
            
            TextField(String(localized: "アプリを検索"), text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: searchFieldFontSize))
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
        .padding(.horizontal, searchFieldPadding)
        .padding(.vertical, searchFieldVerticalPadding)
        .background(
            RoundedRectangle.standard(.medium, scale: uiScale)
                .glassEffect(.regular, in: RoundedRectangle.standard(.medium, scale: uiScale))
        )
        .overlay {
            RoundedRectangle.standard(.medium, scale: uiScale)
                .strokeBorder(
                    isSearchFieldFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.1),
                    lineWidth: isSearchFieldFocused ? 2 * uiScale : 1 * uiScale
                )
        }
        .shadow(
            color: isSearchFieldFocused ? .accentColor.opacity(0.2) : .clear,
            radius: isSearchFieldFocused ? 8 * uiScale : 0,
            x: 0,
            y: 2 * uiScale
        )
        .animation(.easeOut(duration: 0.2), value: isSearchFieldFocused)
        .frame(maxWidth: searchFieldMaxWidth)
    }
    
    @ViewBuilder
    private var toolbarBackground: some View {
        ZStack {
            // Bottom layer - subtle glow
            Rectangle()
                .fill(LinearGradient(
                    colors: [.accentColor.opacity(0.03), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .blur(radius: 20 * uiScale)
            
            // Top layer - main glass
            Rectangle()
                .glassEffect(.regular.tint(.primary.opacity(0.05)), in: .rect)
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var toolbarSeparator: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [.clear, .primary.opacity(0.1), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .frame(height: 0.5 * uiScale)
            .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if let recentApp = viewModel.filteredApps.first(where: { $0.lastLaunchedFlag }) {
            VStack(spacing: 0 * uiScale) {
                // Main app grid
                if viewModel.filteredApps.isEmpty {
                    EmptyAppListView(searchText: viewModel.searchText, showingInstaller: $showingInstaller)
                } else {
                    ResponsiveAppGrid(
                        viewModel: viewModel,
                        hasPerformedInitialAnimation: $hasPerformedInitialAnimation,
                        focusedAppIndex: $focusedAppIndex,
                        focusedRow: focusedRow,
                        selectedAppForDetail: $selectedAppForDetail,
                        selectedAppForUninstall: $selectedAppForUninstall,
                        calculateIconSize: calculateIconSize,
                        calculateSpacing: calculateSpacing,
                        calculateFontSize: calculateFontSize,
                        calculateBadgeFontSize: calculateBadgeFontSize,
                        calculateBadgeSize: calculateBadgeSize,
                        clearSearchFocus: { isSearchFieldFocused = false }
                    )
                }
                
                recentAppButton(recentApp)
            }
        } else {
            // No recent app - show full-height app grid
            if viewModel.filteredApps.isEmpty {
                EmptyAppListView(searchText: viewModel.searchText, showingInstaller: $showingInstaller)
            } else {
                ResponsiveAppGrid(
                    viewModel: viewModel,
                    hasPerformedInitialAnimation: $hasPerformedInitialAnimation,
                    focusedAppIndex: $focusedAppIndex,
                    focusedRow: focusedRow,
                    selectedAppForDetail: $selectedAppForDetail,
                    selectedAppForUninstall: $selectedAppForUninstall,
                    calculateIconSize: calculateIconSize,
                    calculateSpacing: calculateSpacing,
                    calculateFontSize: calculateFontSize,
                    calculateBadgeFontSize: calculateBadgeFontSize,
                    calculateBadgeSize: calculateBadgeSize,
                    clearSearchFocus: { isSearchFieldFocused = false }
                )
            }
        }
    }
    
    @ViewBuilder
    private func recentAppButton(_ recentApp: PlayCoverApp) -> some View {
        VStack(spacing: 0 * uiScale) {
            // Glowing separator
            Rectangle()
                .fill(LinearGradient(
                    colors: [.clear, .accentColor.opacity(0.3), .purple.opacity(0.2), .accentColor.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(height: 1 * uiScale)
                .blur(radius: 2 * uiScale)
            
            RecentAppLaunchButton(
                app: recentApp,
                iconSize: recentAppIconSize,
                titleFontSize: recentAppTitleFontSize,
                subtitleFontSize: recentAppSubtitleFontSize,
                padding: recentAppPadding,
                onLaunch: {
                    viewModel.launch(app: recentApp)
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
            .background(recentAppButtonBackground)
            .shadow(color: .accentColor.opacity(0.15), radius: 12 * uiScale, x: 0, y: -4 * uiScale)
            .overlay(alignment: .top) {
                recentAppButtonShine
            }
        }
    }
    
    @ViewBuilder
    private var recentAppButtonBackground: some View {
        ZStack {
            // Animated gradient glow
            LinearGradient(
                colors: [.accentColor.opacity(0.08), .purple.opacity(0.05), .blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blur(radius: 20 * uiScale)
            
            // Main glass layer
            Rectangle()
                .glassEffect(.regular.tint(.accentColor.opacity(0.12)), in: .rect)
        }
        .allowsHitTesting(false)
    }
    
    @ViewBuilder
    private var recentAppButtonShine: some View {
        LinearGradient(
            colors: [.white.opacity(0.15), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 40 * uiScale)
        .allowsHitTesting(false)
    }

    var body: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .focusable()
                .focusEffectDisabled()
                .opacity(0.01)
            
            backgroundLayer
            
            VStack(spacing: 0 * uiScale) {
                toolbarView
                mainContent
            }
            
            // Overlay modals (instead of sheets) for dynamic scaling support
            if let app = selectedAppForDetail {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedAppForDetail = nil
                        restoreWindowFocus()
                    }
                
                AppDetailSheet(
                    isPresented: Binding(
                        get: { selectedAppForDetail != nil },
                        set: { if !$0 { selectedAppForDetail = nil; restoreWindowFocus() } }
                    ),
                    app: app,
                    viewModel: viewModel
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            if showingSettings {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingSettings = false
                        restoreWindowFocus()
                    }
                
                SettingsRootView(isPresented: $showingSettings)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            if showingInstaller {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingInstaller = false
                        restoreWindowFocus()
                    }
                
                IPAInstallerSheet(isPresented: $showingInstaller)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            if let identifiableString = selectedAppForUninstall {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedAppForUninstall = nil
                        restoreWindowFocus()
                    }
                
                AppUninstallerSheet(isPresented: Binding(
                    get: { selectedAppForUninstall != nil },
                    set: { if !$0 { selectedAppForUninstall = nil; restoreWindowFocus() } }
                ), preSelectedBundleID: identifiableString.id)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            if showingUninstaller {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        showingUninstaller = false
                        restoreWindowFocus()
                    }
                
                AppUninstallerSheet(isPresented: $showingUninstaller, preSelectedBundleID: nil)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedAppForDetail != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingSettings)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingInstaller)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedAppForUninstall != nil)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showingUninstaller)
        .frame(minWidth: 960, minHeight: 640)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            print("📏 onGeometryChange fired: \(newSize.width)x\(newSize.height)")
            windowSize = newSize
            let scale = calculateUIScale(for: newSize)
            print("🔍 QuickLauncher window size updated: \(windowSize.width)x\(windowSize.height), calculated scale: \(scale)")
        }
        .overlay(alignment: .center) {
            if viewModel.unmountFlowState != .idle {
                ZStack {
                    Color.black.opacity(0.3)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                    UnmountOverlayView(viewModel: viewModel)
                        .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(998)
            } else if viewModel.isBusy && viewModel.isShowingStatus {
                VStack(spacing: 12 * uiScale) {
                    ProgressView()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                    }
                }
                .padding()
                .glassEffect(.regular.tint(.blue.opacity(0.2)), in: RoundedRectangle.standard(.regular, scale: uiScale))
                .shadow(radius: 12 * uiScale)
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
            viewModel.onStorageChangeCompleted = { [weak appViewModel] in
                appViewModel?.completeStorageLocationChange()
            }
        }
        .onAppear {
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if showingSettings || showingInstaller || showingUninstaller || 
                   selectedAppForDetail != nil || selectedAppForUninstall != nil ||
                   showingShortcutGuide || viewModel.unmountFlowState != .idle {
                    return event
                }
                if isSearchFieldFocused {
                    return event
                }
                switch event.keyCode {
                case 123, 124, 125, 126, 36, 49, 53,
                     18, 19, 20, 21, 22, 23, 25, 26, 28, 29:
                    let handled = handleKeyCode(event.keyCode)
                    if handled {
                        return nil
                    }
                    return event
                default:
                    return event
                }
            }
        }
        .onDisappear {
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
            if isDrawerOpen {
                ZStack(alignment: .leading) {
                    Color.black.opacity(0.3)
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                isDrawerOpen = false
                            }
                        }
                    DrawerPanel(
                        showingSettings: $showingSettings,
                        showingInstaller: $showingInstaller,
                        showingUninstaller: $showingUninstaller,
                        getPlayCoverIcon: getPlayCoverIcon,
                        isOpen: $isDrawerOpen,
                        uiScale: uiScale
                    )
                    .transition(.move(edge: .leading))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(999)
            }
            if showingShortcutGuide {
                ZStack {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                showingShortcutGuide = false
                            }
                        }
                    KeyboardShortcutGuide(isShowing: $showingShortcutGuide, uiScale: uiScale)
                        .transition(.scale.combined(with: .opacity))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(1000)
            }
        }
        .uiScale(uiScale)  // Inject UI scale into environment for all child views
    }
}

// MARK: - Modern Toolbar Button with Hover Effect
private struct ModernToolbarButton: View {
    @Environment(\.uiScale) var uiScale
    let icon: String
    let color: Color
    let help: String
    var rotation: Double = 0  // Optional rotation angle for animations
    var size: CGFloat = 44  // Button size (dynamic)
    var iconSize: CGFloat = 17  // Icon size (dynamic)
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        let cornerRadius = size * 0.27  // 12/44 ≈ 0.27
        
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(isHovered ? color.opacity(0.9) : color)
                .rotationEffect(.degrees(rotation))
                .frame(width: size, height: size)
                .background(
                    ZStack {
                        // Glow effect when hovered
                        if isHovered {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(color.opacity(0.15))
                                .blur(radius: size * 0.18)
                        }
                        
                        // Main glass button
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .glassEffect(
                                isHovered 
                                ? .regular.tint(color.opacity(0.15))
                                : .regular, 
                                in: RoundedRectangle(cornerRadius: cornerRadius)
                            )
                    }
                    .allowsHitTesting(false)  // Allow clicks through to button
                )
                .shadow(
                    color: isHovered ? color.opacity(0.3) : .black.opacity(0.1), 
                    radius: isHovered ? size * 0.18 : size * 0.09, 
                    x: 0, 
                    y: size * 0.045
                )
                .overlay {
                    // Shine effect on hover
                    if isHovered {
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
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
    let iconSize: CGFloat  // Dynamic icon size
    let fontSize: CGFloat  // Dynamic font size
    let uiScale: CGFloat  // UI scale for dynamic scaling
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
    
    // Computed scale for cleaner code
    private var currentScale: CGFloat {
        if isPressing { return 0.85 }
        if isBouncing { return 1.15 }
        if isAnimating { return 0.85 }
        if isHovering { return 1.05 }
        return 1.0
    }
    
    // Icon content view
    @ViewBuilder
    private var iconContent: some View {
        if let icon = app.icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            RoundedRectangle(cornerRadius: iconSize * 0.18)
                .fill(Color.gray.opacity(0.3))
                .overlay {
                    Image(systemName: "app.dashed")
                        .font(.system(size: iconSize * 0.32))
                        .foregroundStyle(.secondary)
                }
        }
    }
    
    // Status indicator view
    @ViewBuilder
    private var statusIndicator: some View {
        // Scale status indicator with icon size (base: 14pt at 100pt icon = 0.14 ratio)
        let circleSize: CGFloat = iconSize * 0.14
        let borderWidth: CGFloat = iconSize * 0.025
        
        ZStack {
            Circle()
                .fill(app.isRunning ? Color.green : app.isMounted ? Color.orange : Color.red)
                .frame(width: circleSize, height: circleSize)
            Circle()
                .strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: borderWidth)
                .frame(width: circleSize, height: circleSize)
        }
        .shadow(color: .black.opacity(0.2), radius: iconSize * 0.03, x: 0, y: iconSize * 0.01)
    }
    
    var body: some View {
        // Calculate corner radius dynamically (base: 18pt at 100pt icon = 0.18 ratio)
        let cornerRadius = iconSize * 0.18
        let spacingBetweenIconAndText = iconSize * 0.08
        
        VStack(spacing: spacingBetweenIconAndText) {
            // iOS-style app icon (rounded square)
            iconContent
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .background {
                // Hover glow effect behind the icon (doesn't cover image)
                if isHovering {
                    RoundedRectangle(cornerRadius: cornerRadius)
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
                                endRadius: iconSize * 0.6
                            )
                        )
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(1.2)
                        .blur(radius: iconSize * 0.08)
                }
            }
            .shadow(
                color: isHovering ? .accentColor.opacity(0.5) : .black.opacity(0.2), 
                radius: isHovering ? iconSize * 0.16 : iconSize * 0.03, 
                x: 0, 
                y: isHovering ? iconSize * 0.06 : iconSize * 0.02
            )
            .overlay {
                // Simple focus border (keyboard focus only)
                if isFocused {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(Color.accentColor, lineWidth: iconSize * 0.03)
                }
            }
            .overlay {
                // Hover border glow
                if isHovering {
                    RoundedRectangle(cornerRadius: cornerRadius)
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
                            lineWidth: iconSize * 0.02
                        )
                }
            }
            .overlay(alignment: .bottom) {
                statusIndicator
                    .offset(x: 0, y: iconSize * 0.06)  // Shift down slightly from bottom edge
            }
            // Press & bounce & hover animation
            .scaleEffect(currentScale)
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
                        
                        pressLocation = nil
                    }
            )
            
            // App name below icon
            Text(app.displayName)
                .font(.system(size: fontSize, weight: .regular))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)
        }
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
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    isAnimating = true
                    try? await Task.sleep(for: .milliseconds(550))
                    isAnimating = false
                }
            }
        }
        // Standard context menu (macOS 26.1 supports icons in menu items)
        .contextMenu {
            Button {
                Task { @MainActor in
                    isAnimating = true
                    try? await Task.sleep(for: .milliseconds(100))
                    tapAction()
                    try? await Task.sleep(for: .milliseconds(550))
                    isAnimating = false
                }
            } label: {
                Label("起動", systemImage: "play.fill")
            }
            
            Button {
                launchInDebugConsole(app: app)
            } label: {
                Label("デバッグコンソールで起動", systemImage: "terminal.fill")
            }
            
            Divider()
            
            Button {
                rightClickAction()
            } label: {
                Label("詳細と設定", systemImage: "gearshape.fill")
            }
            
            Divider()
            
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
            } label: {
                Label("アプリ本体を Finder で表示", systemImage: "folder.fill")
            }
            
            Button {
                let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
                if FileManager.default.fileExists(atPath: containerURL.path) {
                    NSWorkspace.shared.activateFileViewerSelecting([containerURL])
                }
            } label: {
                Label("コンテナを Finder で表示", systemImage: "externaldrive.fill")
            }
            
            Divider()
            
            Button(role: .destructive) {
                uninstallAction()
            } label: {
                Label("アンインストール", systemImage: "trash.fill")
            }
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
    @Binding var isPresented: Bool
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @State private var selectedTab: SettingsTab = .overview
    @State private var windowSize: CGSize = CGSize(width: 800, height: 650)
    
    init(isPresented: Binding<Bool>, app: PlayCoverApp, viewModel: LauncherViewModel) {
        self._isPresented = isPresented
        self.app = app
        self._viewModel = Bindable(wrappedValue: viewModel)
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
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    Text(app.displayName)
                        .font(.system(size: 24 * uiScale, weight: .bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    
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
                
                // Content area
                ScrollView {
                    VStack(spacing: 24 * uiScale) {
                        // App info card
                        VStack(spacing: 16 * uiScale) {
                            HStack(spacing: 16 * uiScale) {
                                // App icon
                                if let icon = app.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 80 * uiScale, height: 80 * uiScale)
                                        .clipShape(RoundedRectangle(cornerRadius: 18 * uiScale))
                                        .shadow(color: .black.opacity(0.2), radius: 8 * uiScale, x: 0, y: 4 * uiScale)
                                } else {
                                    RoundedRectangle(cornerRadius: 18 * uiScale)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 80 * uiScale, height: 80 * uiScale)
                                        .overlay {
                                            Image(systemName: "app.dashed")
                                                .font(.system(size: 32 * uiScale))
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                
                                VStack(alignment: .leading, spacing: 6 * uiScale) {
                                    if let version = app.version {
                                        HStack(spacing: 4 * uiScale) {
                                            Image(systemName: "tag.fill")
                                                .font(.system(size: 10 * uiScale))
                                            Text("バージョン \(version)")
                                                .font(.system(size: 13 * uiScale))
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    
                                    Text(app.bundleIdentifier)
                                        .font(.system(size: 11 * uiScale, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                
                                Spacer()
                                
                                // Quick launch button
                                CustomButton(
                                    title: "起動",
                                    action: {
                                        isPresented = false
                                        viewModel.launch(app: app)
                                    },
                                    isPrimary: true,
                                    icon: "play.circle.fill",
                                    uiScale: uiScale
                                )
                                .frame(minWidth: 100 * uiScale)
                            }
                        }
                        .padding(24 * uiScale)
                        .liquidGlassCard(uiScale: uiScale)
                        
                        // Tab selector
                        HStack(spacing: 12 * uiScale) {
                            ForEach(SettingsTab.allCases) { tab in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedTab = tab
                                    }
                                } label: {
                                    VStack(spacing: 8 * uiScale) {
                                        Image(systemName: tab.icon)
                                            .font(.system(size: 24 * uiScale, weight: .medium))
                                        Text(tab.localizedTitle)
                                            .font(.system(size: 12 * uiScale, weight: .medium))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16 * uiScale)
                                    .background(
                                        RoundedRectangle.standard(.regular, scale: uiScale)
                                            .fill(selectedTab == tab ? Color.blue : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                    )
                                    .foregroundStyle(selectedTab == tab ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // Tab content
                        VStack(spacing: 0) {
                            switch selectedTab {
                            case .overview:
                                OverviewView(app: app, viewModel: viewModel)
                            case .settings:
                                SettingsView(app: app, viewModel: viewModel)
                            case .details:
                                DetailsView(app: app, viewModel: viewModel)
                            }
                        }
                        .padding(24 * uiScale)
                        .liquidGlassCard(uiScale: uiScale)
                        
                        // Bottom action buttons
                        HStack(spacing: 12 * uiScale) {
                            CustomLargeButton(
                                title: "アプリ本体を表示",
                                action: {
                                    NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
                                },
                                isPrimary: false,
                                icon: "folder",
                                uiScale: uiScale
                            )
                        }
                        .padding(.bottom, 24 * uiScale)
                    }
                    .padding(.horizontal, 32 * uiScale)
                    .padding(.vertical, 24 * uiScale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .uiScale(uiScale)
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
        .frame(minWidth: 800, minHeight: 650)
        .clipShape(RoundedRectangle.standard(.large, scale: uiScale))
        .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 15 * uiScale)
    }
}

private struct EmptyAppListView: View {
    let searchText: String
    @Binding var showingInstaller: Bool
    @Environment(\.uiScale) var uiScale
    
    // Check if this is a search result empty state or truly no apps
    private var isSearchEmpty: Bool {
        !searchText.isEmpty
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 32 * uiScale) {
                // Icon and title card
                VStack(spacing: 24 * uiScale) {
                    Image(systemName: isSearchEmpty ? "magnifyingglass" : "tray")
                        .font(.system(size: 80 * uiScale))
                        .foregroundStyle(isSearchEmpty ? .blue : .secondary)
                    
                    VStack(spacing: 12 * uiScale) {
                        Text(isSearchEmpty ? "検索結果が見つかりません" : "インストール済みアプリがありません")
                            .font(.system(size: 28 * uiScale, weight: .bold))
                        
                        if isSearchEmpty {
                            // Search empty state
                            VStack(spacing: 8 * uiScale) {
                                Text("\"\(searchText)\" に一致するアプリが見つかりませんでした。")
                                    .font(.system(size: 15 * uiScale))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("別のキーワードで検索してみてください。")
                                    .font(.system(size: 15 * uiScale))
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: 450 * uiScale)
                        } else {
                            // No apps installed state
                            VStack(spacing: 8 * uiScale) {
                                Text("IPA ファイルをインストールすると、ここに表示されます。")
                                    .font(.system(size: 15 * uiScale))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text("下のボタンから IPA をインストールしてください。")
                                    .font(.system(size: 15 * uiScale))
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: 450 * uiScale)
                        }
                    }
                }
                .padding(40 * uiScale)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20 * uiScale))
                .shadow(color: .black.opacity(0.15), radius: 30 * uiScale, x: 0, y: 10 * uiScale)
                
                // Action buttons (only for non-search empty state)
                if !isSearchEmpty {
                    CustomLargeButton(
                        title: "IPA をインストール",
                        action: {
                            showingInstaller = true
                        },
                        isPrimary: true,
                        icon: "square.and.arrow.down",
                        uiScale: uiScale
                    )
                    .frame(minWidth: 200 * uiScale)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .frame(maxWidth: 600 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Wrapper to access Environment in sheet (removed - now using ZStack overlay)


// Recent app launch button with rich animations
private struct RecentAppLaunchButton: View {
    @Environment(\.uiScale) var uiScale
    let app: PlayCoverApp
    var iconSize: CGFloat = 56
    var titleFontSize: CGFloat = 17
    var subtitleFontSize: CGFloat = 13
    var padding: CGFloat = 20
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
            let displayIconSize = iconSize * 1.4  // 40% larger for better visibility (512x512 source prevents blur)
            let cornerRadius = displayIconSize * 0.21  // Adjust corner radius proportionally
            let iconSpacing = padding * 1.0
            
            HStack(spacing: iconSpacing) {
                // Icon with animations - ZStack layers old icon, ripple, and new icon
                ZStack {
                    // Old icon (during transition) - bottom layer
                    if let oldIcon = oldIcon {
                        Image(nsImage: oldIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: displayIconSize, height: displayIconSize)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            .shadow(color: .black.opacity(0.2), radius: displayIconSize * 0.11, x: 0, y: displayIconSize * 0.05)
                            .offset(x: oldIconOffsetX, y: oldIconOffsetY)
                            .scaleEffect(oldIconScale)
                            .opacity(oldIconOpacity)
                    }
                    
                    // Ripple effect - middle layer, centered on icon
                    RippleEffect(trigger: rippleTrigger)
                        .frame(width: displayIconSize, height: displayIconSize)
                    
                    // Current icon - top layer with modern shadow
                    if let icon = app.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: displayIconSize, height: displayIconSize)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                            .shadow(color: .black.opacity(0.2), radius: displayIconSize * 0.11, x: 0, y: displayIconSize * 0.05)
                            .offset(x: iconOffsetX, y: iconOffsetY)
                            .scaleEffect(iconScale)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: displayIconSize, height: displayIconSize)
                            .overlay {
                                Image(systemName: "app.fill")
                                    .font(.system(size: displayIconSize * 0.5))
                                    .foregroundStyle(.tertiary)
                            }
                            .offset(x: iconOffsetX, y: iconOffsetY)
                            .scaleEffect(iconScale)
                    }
                }
                .frame(width: displayIconSize, height: displayIconSize)
                
                // App info with modern styling
                VStack(alignment: .leading, spacing: iconSize * 0.11) {
                    Text(displayedTitle)
                        .font(.system(size: titleFontSize, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: iconSize * 0.11) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: subtitleFontSize * 0.85, weight: .medium))
                        Text("前回起動したアプリ")
                            .font(.system(size: subtitleFontSize, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .opacity(textOpacity)
                .animation(.easeInOut(duration: 0.3), value: displayedTitle)
                
                Spacer()
                
                // Modern Enter key hint with glassmorphism
                HStack(spacing: iconSize * 0.11) {
                    Image(systemName: "return")
                        .font(.system(size: subtitleFontSize * 0.85, weight: .bold))
                    Text("Enter")
                        .font(.system(size: subtitleFontSize * 0.92, weight: .semibold))
                }
                .padding(.horizontal, padding * 0.6)
                .padding(.vertical, padding * 0.3)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: padding * 0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: padding * 0.4)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1 * uiScale)
                )
                .foregroundStyle(.secondary)
                .shadow(color: .black.opacity(0.05), radius: padding * 0.1, x: 0, y: 1)
            }
            .padding(.horizontal, padding * 1.2)
            .padding(.vertical, padding * 0.8)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 0 * uiScale)
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
    @Environment(\.uiScale) var uiScale
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
    @Environment(\.uiScale) var uiScale
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
                .blur(radius: 8 * uiScale)
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
                .blur(radius: 4 * uiScale)
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
                    lineWidth: 4 * uiScale
                )
                .scaleEffect(ripple.scale)
                .opacity(ripple.opacity)
                .shadow(color: rippleColor.opacity(ripple.opacity * 0.5), radius: 6 * uiScale, x: 0, y: 2)
            
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
                .blur(radius: 10 * uiScale)
                .opacity(ripple.opacity)
        }
    }
}

// MARK: - Overview Tab

private struct OverviewView: View {
    @Environment(\.uiScale) var uiScale
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @State private var infoPlist: [String: Any]?
    @State private var storageInfo: StorageInfo?
    
    init(app: PlayCoverApp, viewModel: LauncherViewModel) {
        self.app = app
        self.viewModel = viewModel
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20 * uiScale) {
            Text("アプリ概要")
                .font(.system(size: 17 * uiScale, weight: .semibold))
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16 * uiScale) {
                    // App Card
                    HStack(spacing: 16 * uiScale) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 80 * uiScale, height: 80 * uiScale)
                                .clipShape(RoundedRectangle(cornerRadius: 18 * uiScale))
                                .shadow(color: .black.opacity(0.2), radius: 8 * uiScale, x: 0, y: 4)
                        }
                        
                        VStack(alignment: .leading, spacing: 4 * uiScale) {
                            Text(app.displayName)
                                .font(.system(size: 22 * uiScale, weight: .bold))
                                .fontWeight(.bold)
                            
                            if let version = app.version {
                                Text("バージョン \(version)")
                                    .font(.system(size: 13 * uiScale))
                                    .foregroundStyle(.secondary)
                            }
                            
                            if let minOS = infoPlist?["MinimumOSVersion"] as? String {
                                HStack(spacing: 4 * uiScale) {
                                    Image(systemName: "iphone")
                                        .font(.system(size: 11 * uiScale))
                                    Text("iOS \(minOS)+")
                                        .font(.system(size: 11 * uiScale))
                                }
                                .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(12 * uiScale)
                    
                    // Quick Stats
                    HStack(spacing: 12 * uiScale) {
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
                        VStack(alignment: .leading, spacing: 8 * uiScale) {
                            Text("ストレージ内訳")
                                .font(.system(size: 13 * uiScale))
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 8 * uiScale) {
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
                            .padding(12 * uiScale)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                            .cornerRadius(8 * uiScale)
                            
                            VStack(alignment: .leading, spacing: 4 * uiScale) {
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
                    VStack(alignment: .leading, spacing: 8 * uiScale) {
                        Text("基本情報")
                            .font(.system(size: 13 * uiScale))
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 6 * uiScale) {
                            QuickInfoRow(icon: "checkmark.seal.fill", label: "Bundle ID", value: app.bundleIdentifier)
                            
                            if let executableName = infoPlist?["CFBundleExecutable"] as? String {
                                QuickInfoRow(icon: "gearshape.fill", label: String(localized: "実行ファイル"), value: executableName)
                            }
                            
                            if let capabilities = getCapabilitiesCount() {
                                QuickInfoRow(icon: "lock.shield.fill", label: String(localized: "権限要求"), value: "\(capabilities) 個")
                            }
                        }
                        .padding(12 * uiScale)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                        .cornerRadius(8 * uiScale)
                    }
                    
                    // Quick Actions
                    VStack(spacing: 8 * uiScale) {
                        CustomButton(
                            title: "アプリ本体を Finder で表示",
                            action: {
                                NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
                            },
                            isPrimary: false,
                            icon: "folder",
                            uiScale: uiScale
                        )
                        
                        CustomButton(
                            title: "コンテナを Finder で表示",
                            action: {
                                let containerURL = PlayCoverPaths.containerURL(for: app.bundleIdentifier)
                                if FileManager.default.fileExists(atPath: containerURL.path) {
                                    NSWorkspace.shared.activateFileViewerSelecting([containerURL])
                                }
                            },
                            isPrimary: false,
                            icon: "externaldrive",
                            uiScale: uiScale
                        )
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
    @Environment(\.uiScale) var uiScale
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8 * uiScale) {
            HStack(spacing: 6 * uiScale) {
                Image(systemName: icon)
                    .font(.system(size: 20 * uiScale, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 11 * uiScale))
                    .foregroundStyle(.secondary)
            }
            
            Text(value)
                .font(.system(size: 20 * uiScale, weight: .semibold))
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12 * uiScale)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8 * uiScale)
    }
}

private struct StorageRow: View {
    @Environment(\.uiScale) var uiScale
    let label: String
    let size: String
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8 * uiScale, height: 8 * uiScale)
            
            Text(label)
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(size)
                .font(.system(size: 11 * uiScale))
                .fontWeight(.medium)
        }
    }
}

private struct QuickInfoRow: View {
    @Environment(\.uiScale) var uiScale
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8 * uiScale) {
            Image(systemName: icon)
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(.blue)
                .frame(width: 16 * uiScale)
            
            Text(label)
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(.secondary)
                .frame(width: 90 * uiScale, alignment: .leading)
            
            Text(value)
                .font(.system(size: 11 * uiScale))
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Basic Settings Tab

private struct SettingsView: View {
    @Environment(\.uiScale) var uiScale
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
        VStack(alignment: .leading, spacing: 20 * uiScale) {
            Text("アプリ設定")
                .font(.system(size: 17 * uiScale, weight: .semibold))
            
            // Nobrowse setting
            VStack(alignment: .leading, spacing: 8 * uiScale) {
                Text("Finder での表示設定")
                    .font(.system(size: 13 * uiScale))
                    .fontWeight(.medium)
                
                Picker("", selection: $nobrowseOverride) {
                    ForEach(NobrowseOverride.allCases) { option in
                        Text(option.localizedTitle).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: nobrowseOverride) { _, newValue in
                    saveNobrowseSetting(newValue)
                }
                
                Text("このアプリのディスクイメージを Finder に表示するかどうかを設定します。")
                    .font(.system(size: 11 * uiScale))
                    .foregroundStyle(.secondary)
                
                if nobrowseOverride == .useGlobal {
                    Text("現在のグローバル設定: \(settingsStore.nobrowseEnabled ? "Finderに表示しない" : "Finderに表示する")")
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Data handling strategy
            VStack(alignment: .leading, spacing: 8 * uiScale) {
                Text("内部データ処理方法")
                    .font(.system(size: 13 * uiScale))
                    .fontWeight(.medium)
                
                Picker("", selection: $dataHandlingOverride) {
                    ForEach(DataHandlingOverride.allCases) { option in
                        Text(option.localizedTitle).tag(option)
                    }
                }
                .labelsHidden()
                .onChange(of: dataHandlingOverride) { _, newValue in
                    saveDataHandlingSetting(newValue)
                }
                
                Text("起動時に内部データが見つかった場合の処理方法を設定します。")
                    .font(.system(size: 11 * uiScale))
                    .foregroundStyle(.secondary)
                
                if dataHandlingOverride == .useGlobal {
                    Text("現在のグローバル設定: \(settingsStore.defaultDataHandling.localizedDescription)")
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
            
            // Language setting
            if !supportedLanguages.isEmpty {
                VStack(alignment: .leading, spacing: 8 * uiScale) {
                    Text("アプリの言語設定")
                        .font(.system(size: 13 * uiScale))
                        .fontWeight(.medium)
                    
                    // Use standard Picker for Optional<String> since CustomPicker requires RawRepresentable
                    Picker("", selection: $languageOverride) {
                        Text("システムデフォルト").tag(nil as String?)
                        ForEach(supportedLanguages, id: \.self) { lang in
                            Text(getLanguageDisplayName(lang)).tag(lang as String?)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: languageOverride) { _, newValue in
                        saveLanguageSetting(newValue)
                    }
                    
                    Text("このアプリで使用する言語を設定します。")
                        .font(.system(size: 11 * uiScale))
                        .foregroundStyle(.secondary)
                    
                    if languageOverride == nil {
                        let systemLangs = Locale.preferredLanguages
                        if let primaryLang = systemLangs.first {
                            // Extract language code from locale identifier (e.g., "ja-JP" -> "ja")
                            let langCode = primaryLang.components(separatedBy: "-").first ?? primaryLang
                            Text("現在のシステム言語: \(getLanguageDisplayName(langCode))")
                                .font(.system(size: 11 * uiScale))
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
    @Environment(\.uiScale) var uiScale
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
        VStack(alignment: .leading, spacing: 16 * uiScale) {
            Text("詳細情報")
                .font(.system(size: 17 * uiScale, weight: .semibold))
            
            // Sub-section selector
            Picker("", selection: $selectedSection) {
                ForEach(DetailSection.allCases) { section in
                    Text(section.localizedTitle).tag(section)
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
    @Environment(\.uiScale) var uiScale
    let app: PlayCoverApp
    @Bindable var viewModel: LauncherViewModel
    @Binding var infoPlist: [String: Any]?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16 * uiScale) {
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
                            .font(.system(size: 11 * uiScale))
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
                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                        Text("アプリ本体")
                            .font(.system(size: 11 * uiScale))
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
                        .padding(.vertical, 4 * uiScale)
                    
                    // Disk image
                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                        Text("ディスクイメージ")
                            .font(.system(size: 11 * uiScale))
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
                            .padding(.vertical, 4 * uiScale)
                        
                        VStack(alignment: .leading, spacing: 4 * uiScale) {
                            Text("内部データ (参考情報)")
                                .font(.system(size: 11 * uiScale))
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            infoRow(label: String(localized: "使用量"), value: internalSize)
                                .foregroundStyle(.secondary)
                            Text("※ イメージ内のデータ使用量（合計に含まれません）")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2 * uiScale)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4 * uiScale)
                    
                    // Total
                    VStack(alignment: .leading, spacing: 4 * uiScale) {
                        HStack {
                            Text("合計使用容量:")
                                .font(.system(size: 11 * uiScale))
                                .fontWeight(.semibold)
                            Spacer()
                            Text(storageInfo.totalSize)
                                .font(.system(size: 11 * uiScale))
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
        VStack(alignment: .leading, spacing: 8 * uiScale) {
            Text(title)
                .font(.system(size: 13 * uiScale))
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 4 * uiScale) {
                content()
            }
            .padding(12 * uiScale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8 * uiScale)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8 * uiScale) {
            Text("\(label):")
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(.secondary)
                .frame(width: 100 * uiScale, alignment: .trailing)
            
            Text(value)
                .font(.system(size: 11 * uiScale))
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
    @Environment(\.uiScale) var uiScale
    let app: PlayCoverApp
    @State private var analyzing = false
    @State private var analysisResult: AppAnalysisResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16 * uiScale) {
            HStack {
                Text("アプリ解析")
                    .font(.system(size: 13 * uiScale))
                    .fontWeight(.medium)
                
                Spacer()
                
                if analyzing {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                CustomButton(
                    title: analyzing ? "解析中..." : "再解析",
                    action: {
                        Task { await performAnalysis() }
                    },
                    isPrimary: true,
                    uiScale: uiScale,
                    isEnabled: !analyzing
                )
            }
            
            if let result = analysisResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16 * uiScale) {
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
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        // Frameworks & Libraries
                        if !result.frameworks.isEmpty {
                            analysisSection(title: String(localized: "フレームワーク (\(result.frameworks.count))"), icon: "shippingbox.fill") {
                                ForEach(result.frameworks.sorted(), id: \.self) { framework in
                                    Text("• \(framework)")
                                        .font(.system(size: 11 * uiScale))
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
                                        .font(.system(size: 11 * uiScale))
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
                                            .font(.system(size: 11 * uiScale))
                                            .frame(width: 80 * uiScale, alignment: .leading)
                                        Text("\(fileType.count) 個")
                                            .font(.system(size: 11 * uiScale))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text(fileType.totalSize)
                                            .font(.system(size: 11 * uiScale))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack(spacing: 16 * uiScale) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 64 * uiScale))
                        .foregroundStyle(.secondary)
                    
                    Text("アプリを解析して詳細情報を表示します")
                        .font(.system(size: 13 * uiScale))
                        .foregroundStyle(.secondary)
                    
                    CustomButton(
                        title: "解析開始",
                        action: {
                            Task { await performAnalysis() }
                        },
                        isPrimary: true,
                        uiScale: uiScale
                    )
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
        VStack(alignment: .leading, spacing: 8 * uiScale) {
            HStack(spacing: 8 * uiScale) {
                Image(systemName: icon)
                    .font(.system(size: 13 * uiScale))
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.system(size: 13 * uiScale))
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            
            VStack(alignment: .leading, spacing: 4 * uiScale) {
                content()
            }
            .padding(12 * uiScale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(8 * uiScale)
        }
    }
    
    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8 * uiScale) {
            Text("\(label):")
                .font(.system(size: 11 * uiScale))
                .foregroundStyle(.secondary)
                .frame(width: 120 * uiScale, alignment: .trailing)
            
            Text(value)
                .font(.system(size: 11 * uiScale))
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
    let uiScale: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0 * uiScale) {
            // Header
            HStack {
                Text("メニュー")
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14 * uiScale))
                }
                .buttonStyle(.plain)
            }
            .padding(16 * uiScale)
            
            Divider()
            
            VStack(spacing: 0 * uiScale) {
                Spacer()
                    .frame(height: 20 * uiScale)
            
                // PlayCover.app button
                DrawerMenuItem(
                    icon: AnyView(
                        Group {
                            if let playCoverIcon = getPlayCoverIcon() {
                                Image(nsImage: playCoverIcon)
                                    .resizable()
                                    .frame(width: 32 * uiScale, height: 32 * uiScale)
                                    .clipShape(RoundedRectangle(cornerRadius: 7 * uiScale))
                            } else {
                                Image(systemName: "app.badge.checkmark")
                                    .font(.system(size: 20 * uiScale))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 32 * uiScale, height: 32 * uiScale)
                            }
                        }
                    ),
                    title: String(localized: "PlayCover アプリを開く"),
                    help: String(localized: "PlayCover アプリを開く (⌘⇧P)"),
                    uiScale: uiScale
                ) {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/PlayCover.app"))
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                Divider()
                    .padding(.leading, 16 * uiScale)
                
                // Install button
                DrawerMenuItem(
                    icon: AnyView(
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 20 * uiScale))
                            .foregroundStyle(.blue)
                            .frame(width: 32 * uiScale, height: 32 * uiScale)
                    ),
                    title: String(localized: "IPA をインストール"),
                    help: String(localized: "IPA をインストール (⌘I)"),
                    uiScale: uiScale
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
                            .font(.system(size: 20 * uiScale))
                            .foregroundStyle(.red)
                            .frame(width: 32 * uiScale, height: 32 * uiScale)
                    ),
                    title: String(localized: "アプリをアンインストール"),
                    help: String(localized: "アプリをアンインストール (⌘D)"),
                    uiScale: uiScale
                ) {
                    showingUninstaller = true
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isOpen = false
                    }
                }
                .keyboardShortcut("d", modifiers: [.command])
                
                Divider()
                    .padding(.leading, 16 * uiScale)
                
                // Settings button
                DrawerMenuItem(
                    icon: AnyView(
                        Image(systemName: "gear")
                            .font(.system(size: 20 * uiScale))
                            .foregroundStyle(.secondary)
                            .frame(width: 32 * uiScale, height: 32 * uiScale)
                    ),
                    title: String(localized: "設定"),
                    help: String(localized: "設定 (ショートカット)"),
                    uiScale: uiScale
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
        .frame(width: 260 * uiScale)
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
                .blur(radius: 30 * uiScale)
                
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
                .frame(width: 1 * uiScale)
                .allowsHitTesting(false)  // Allow clicks through separator
        }
        .shadow(color: .black.opacity(0.2), radius: 20 * uiScale, x: 4 * uiScale, y: 0)
        .shadow(color: .black.opacity(0.3), radius: 10 * uiScale, x: 2 * uiScale, y: 0)
    }
}

// MARK: - Drawer Menu Item with Hover Effect
private struct DrawerMenuItem: View {
    let icon: AnyView
    let title: String
    let help: String
    let uiScale: CGFloat
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12 * uiScale) {
                icon
                Text(title)
                    .font(.system(size: 15 * uiScale))
                Spacer()
            }
            .padding(.horizontal, 16 * uiScale)
            .padding(.vertical, 12 * uiScale)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 0 * uiScale)
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
    let uiScale: CGFloat
    
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
        VStack(spacing: 0 * uiScale) {
            // Header
            HStack {
                Image(systemName: "keyboard")
                    .font(.system(size: 24 * uiScale))
                    .foregroundStyle(.blue)
                
                Text("キーボードショートカット")
                    .font(.system(size: 20 * uiScale, weight: .bold))
                
                Spacer()
                
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24 * uiScale))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(String(localized: "閉じる (Esc)"))
            }
            .padding(24 * uiScale)
            .glassEffect(.regular, in: .rect)
            
            Divider()
            
            // Shortcuts list
            ScrollView {
                VStack(spacing: 0 * uiScale) {
                    ForEach([String(localized: "グローバル"), "ナビゲーション"], id: \.self) { category in
                        shortcutCategoryView(for: category)
                    }
                }
                .padding(.vertical, 12 * uiScale)
            }
            
            Divider()
            
            // Footer
            HStack {
                Image(systemName: "info.circle")
                    .font(.system(size: 13 * uiScale))
                    .foregroundStyle(.secondary)
                Text("Escキーまたは背景をクリックして閉じる")
                    .font(.system(size: 12 * uiScale))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("閉じる") {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isShowing = false
                    }
                }
                .font(.system(size: 14 * uiScale))
                .keyboardShortcut(.cancelAction)
            }
            .padding(16 * uiScale)
            .glassEffect(.regular, in: .rect)
        }
        .frame(width: 600 * uiScale, height: 500 * uiScale)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle.standard(.large, scale: uiScale))
        .shadow(color: .black.opacity(0.3), radius: 30 * uiScale, x: 0, y: 10 * uiScale)
    }
    
    // Helper method to break up complex expression for type checker
    @ViewBuilder
    private func shortcutCategoryView(for category: String) -> some View {
        let categorySpacing: CGFloat = 12 * uiScale
        let horizontalPadding: CGFloat = 24 * uiScale
        let topPadding: CGFloat = 16 * uiScale
        let fontSize: CGFloat = 17 * uiScale
        let itemFontSize: CGFloat = 15 * uiScale
        let itemHorizontalPadding: CGFloat = 12 * uiScale
        let itemVerticalPadding: CGFloat = 6 * uiScale
        let cornerRadius: CGFloat = 6 * uiScale
        let minWidth: CGFloat = 100 * uiScale
        let rowHorizontalPadding: CGFloat = 24 * uiScale
        let rowVerticalPadding: CGFloat = 10 * uiScale
        let itemSpacing: CGFloat = 16 * uiScale
        
        VStack(alignment: .leading, spacing: categorySpacing) {
            Text(category)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, topPadding)
            
            VStack(spacing: 0 * uiScale) {
                ForEach(shortcuts.filter { $0.category == category }, id: \.keys) { shortcut in
                    HStack(spacing: itemSpacing) {
                        // Key combination
                        Text(shortcut.keys)
                            .font(.system(size: itemFontSize, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, itemHorizontalPadding)
                            .padding(.vertical, itemVerticalPadding)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: cornerRadius))
                            .frame(minWidth: minWidth, alignment: .leading)
                        
                        // Description
                        Text(shortcut.description)
                            .font(.system(size: itemFontSize))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, rowHorizontalPadding)
                    .padding(.vertical, rowVerticalPadding)
                    .background(Color.clear)
                    .contentShape(Rectangle())
                }
            }
        }
    }
}

// MARK: - Data Handling Alert View

private struct DataHandlingAlertView: View {
    @Environment(\.uiScale) var uiScale
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
            VStack(spacing: 20 * uiScale) {
                Image(systemName: "folder.fill.badge.questionmark")
                    .font(.system(size: 64 * uiScale))
                    .foregroundStyle(.blue)
                
                Text("内部データが見つかりました")
                    .font(.system(size: 22 * uiScale, weight: .bold))
                    .fontWeight(.semibold)
                
                Text("\(request.app.displayName) の内部ストレージにデータが存在します。どのように処理しますか？")
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400 * uiScale)
                
                // Strategy selection buttons
                VStack(spacing: 12 * uiScale) {
                    ForEach(Array(SettingsStore.InternalDataStrategy.allCases.enumerated()), id: \.offset) { index, strategy in
                        Button {
                            onSelect(strategy)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4 * uiScale) {
                                    HStack(spacing: 6 * uiScale) {
                                        Text(strategy.localizedDescription)
                                            .font(.system(size: 15 * uiScale))
                                            .fontWeight(.medium)
                                        
                                        if strategy == defaultStrategy {
                                            Text("（既定）")
                                                .font(.system(size: 11 * uiScale))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    
                                    // Add description for each strategy
                                    Text(strategyDescription(for: strategy))
                                        .font(.system(size: 11 * uiScale))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                if selectedIndex == index {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .padding(12 * uiScale)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle.standard(.small, scale: uiScale)
                                    .fill(selectedIndex == index ? Color.blue.opacity(0.1) : Color.clear)
                            )
                            .overlay {
                                if selectedIndex == index {
                                    RoundedRectangle.standard(.small, scale: uiScale)
                                        .strokeBorder(Color.blue, lineWidth: 2 * uiScale)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: 500 * uiScale)
                
                // Cancel button
                CustomButton(
                    title: "キャンセル",
                    action: onCancel,
                    isPrimary: false,
                    uiScale: uiScale
                )
                .keyboardShortcut(.cancelAction)
            }
            .padding(32 * uiScale)
            .frame(maxWidth: 600 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle.standard(.large, scale: uiScale))
            .shadow(color: .black.opacity(0.3), radius: 20 * uiScale)
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

// MARK: - Responsive App Grid Helper View
private struct ResponsiveAppGrid: View {
    @Environment(\.uiScale) var uiScale
    @Bindable var viewModel: LauncherViewModel
    @Binding var hasPerformedInitialAnimation: Bool
    @Binding var focusedAppIndex: Int?
    let focusedRow: Int
    @Binding var selectedAppForDetail: PlayCoverApp?
    @Binding var selectedAppForUninstall: IdentifiableString?
    
    let calculateIconSize: (CGFloat, Int) -> CGFloat
    let calculateSpacing: (CGFloat, Int) -> CGFloat
    let calculateFontSize: (CGFloat) -> CGFloat
    let calculateBadgeFontSize: (CGFloat) -> CGFloat
    let calculateBadgeSize: (CGFloat) -> CGFloat
    let clearSearchFocus: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            let appCount = viewModel.filteredApps.count
            let iconSize = calculateIconSize(geometry.size.width, appCount)
            let spacing = calculateSpacing(iconSize, appCount)
            let fontSize = calculateFontSize(iconSize)
            let badgeFontSize = calculateBadgeFontSize(iconSize)
            let badgeSize = calculateBadgeSize(iconSize)
            
            ScrollView {
                VStack(spacing: spacing * 1.6) {
                    ForEach(0..<((viewModel.filteredApps.count + 9) / 10), id: \.self) { rowIndex in
                        AppGridRow(
                            apps: viewModel.filteredApps,
                            rowIndex: rowIndex,
                            focusedRow: focusedRow,
                            focusedAppIndex: $focusedAppIndex,
                            hasPerformedInitialAnimation: hasPerformedInitialAnimation,
                            selectedAppForDetail: $selectedAppForDetail,
                            selectedAppForUninstall: $selectedAppForUninstall,
                            iconSize: iconSize,
                            spacing: spacing,
                            fontSize: fontSize,
                            badgeFontSize: badgeFontSize,
                            badgeSize: badgeSize,
                            launchApp: viewModel.launch,
                            clearSearchFocus: clearSearchFocus
                        )
                    }
                }
                .padding(.horizontal, 32 * uiScale)
                .padding(.vertical, 24 * uiScale)
                .onAppear {
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

// MARK: - App Grid Row Helper View
private struct AppGridRow: View {
    @Environment(\.uiScale) var uiScale
    let apps: [PlayCoverApp]
    let rowIndex: Int
    let focusedRow: Int
    @Binding var focusedAppIndex: Int?
    let hasPerformedInitialAnimation: Bool
    @Binding var selectedAppForDetail: PlayCoverApp?
    @Binding var selectedAppForUninstall: IdentifiableString?
    
    let iconSize: CGFloat
    let spacing: CGFloat
    let fontSize: CGFloat
    let badgeFontSize: CGFloat
    let badgeSize: CGFloat
    let launchApp: (PlayCoverApp) -> Void
    let clearSearchFocus: () -> Void
    
    var body: some View {
        let appsInRow = min(10, apps.count - (rowIndex * 10))
        let maxColumns = max(1, appsInRow)
        
        HStack(spacing: spacing) {
            Spacer(minLength: 0)
            
            ForEach(0..<maxColumns, id: \.self) { columnIndex in
                let index = rowIndex * 10 + columnIndex
                if index < apps.count {
                    AppGridCell(
                        app: apps[index],
                        index: index,
                        rowIndex: rowIndex,
                        columnIndex: columnIndex,
                        focusedRow: focusedRow,
                        focusedAppIndex: $focusedAppIndex,
                        hasPerformedInitialAnimation: hasPerformedInitialAnimation,
                        selectedAppForDetail: $selectedAppForDetail,
                        selectedAppForUninstall: $selectedAppForUninstall,
                        iconSize: iconSize,
                        fontSize: fontSize,
                        badgeFontSize: badgeFontSize,
                        badgeSize: badgeSize,
                        launchApp: launchApp,
                        clearSearchFocus: clearSearchFocus
                    )
                }
            }
            
            Spacer(minLength: 0)
        }
    }
}

// MARK: - App Grid Cell Helper View
private struct AppGridCell: View {
    @Environment(\.uiScale) var uiScale
    let app: PlayCoverApp
    let index: Int
    let rowIndex: Int
    let columnIndex: Int
    let focusedRow: Int
    @Binding var focusedAppIndex: Int?
    let hasPerformedInitialAnimation: Bool
    @Binding var selectedAppForDetail: PlayCoverApp?
    @Binding var selectedAppForUninstall: IdentifiableString?
    
    let iconSize: CGFloat
    let fontSize: CGFloat
    let badgeFontSize: CGFloat
    let badgeSize: CGFloat
    let launchApp: (PlayCoverApp) -> Void
    let clearSearchFocus: () -> Void
    
    var body: some View {
        let keyNumber = columnIndex == 9 ? "0" : "\(columnIndex + 1)"
        
        ZStack(alignment: .top) {
            iOSAppIconView(
                app: app,
                index: index,
                shouldAnimate: !hasPerformedInitialAnimation,
                isFocused: focusedAppIndex == index,
                iconSize: iconSize,
                fontSize: fontSize,
                uiScale: uiScale
            ) {
                // Tap action
                clearSearchFocus()
                focusedAppIndex = index
                launchApp(app)
                
                NotificationCenter.default.post(
                    name: NSNotification.Name("TriggerAppIconAnimation"),
                    object: nil,
                    userInfo: ["bundleID": app.bundleIdentifier]
                )
                
                if app.lastLaunchedFlag {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TriggerRecentAppBounce"),
                        object: nil
                    )
                }
            } rightClickAction: {
                selectedAppForDetail = app
            } uninstallAction: {
                selectedAppForUninstall = IdentifiableString(app.bundleIdentifier)
            }
            
            // Number key indicator badge
            if rowIndex == focusedRow {
                Text(keyNumber)
                    .font(.system(size: badgeFontSize, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: badgeSize, height: badgeSize)
                    .background(
                        Circle()
                            .fill(Color.accentColor)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 2 * uiScale, x: 0, y: 1)
                    .offset(x: 0, y: -badgeSize * 0.3)
            }
        }
        .frame(width: iconSize)
    }
}
