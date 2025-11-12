import SwiftUI
import AppKit
import Observation

struct AppRootView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        Group {
            switch appViewModel.phase {
            case .checking:
                CheckingView(status: appViewModel.statusMessage) {
                    appViewModel.retry()
                }
            case .setup:
                if let setupVM = appViewModel.setupViewModel, let paths = appViewModel.playCoverPaths {
                    SetupWizardView(viewModel: setupVM, playCoverPaths: paths)
                } else if let setupVM = appViewModel.setupViewModel {
                    SetupWizardView(viewModel: setupVM, playCoverPaths: nil)
                } else {
                    CheckingView(status: String(localized: "セットアップを準備しています…")) {
                        appViewModel.retry()
                    }
                }
            case .launcher:
                if let launcherVM = appViewModel.launcherViewModel {
                    QuickLauncherView(viewModel: launcherVM)
                        .environment(launcherVM)
                } else {
                    CheckingView(status: String(localized: "アプリ情報を取得しています…")) {
                        appViewModel.retry()
                    }
                }
            case .error(let error):
                ErrorView(error: error,
                          onRetry: { appViewModel.retry() },
                          onChangeSettings: { appViewModel.requestStorageLocationChange() })
            case .terminating:
                ProgressView(String(localized: "終了しています…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .onAppear { appViewModel.onAppear() }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            // Track window size changes for responsive UI
            // This uses the new macOS 26 onGeometryChange API
        }
        .overlay {
            // Termination flow overlay
            if appViewModel.terminationFlowState != .idle {
                TerminationFlowView(state: appViewModel.terminationFlowState,
                                    onContinueWaiting: { appViewModel.continueWaiting() },
                                    onForceTerminate: { appViewModel.forceTerminate() },
                                    onCancel: { appViewModel.cancelTermination() })
            }
        }
    }
}

struct CheckingView: View {
    let status: String
    let retry: () -> Void
    @State private var windowSize: CGSize = .zero
    
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 960.0
        let baseHeight: CGFloat = 640.0
        
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
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 32 * uiScale) {
                ProgressView()
                    .scaleEffect(1.5 * uiScale)
                
                Text(status)
                    .font(.system(size: 17 * uiScale, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                Button {
                    retry()
                } label: {
                    Label("再試行", systemImage: "arrow.clockwise")
                        .font(.system(size: 14 * uiScale, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(40 * uiScale)
            .frame(maxWidth: 500 * uiScale)
            .background(
                ZStack {
                    LinearGradient(colors: [.blue.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 25 * uiScale)
                    RoundedRectangle(cornerRadius: 20 * uiScale).glassEffect(.regular.tint(.blue.opacity(0.18)), in: RoundedRectangle(cornerRadius: 20 * uiScale))
                }
                .allowsHitTesting(false)
            )
            .overlay { LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 20 * uiScale)).allowsHitTesting(false) }
            .shadow(color: .blue.opacity(0.2), radius: 35 * uiScale, x: 0, y: 12 * uiScale)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
    }
}

struct ErrorView: View {
    let error: AppError
    let onRetry: () -> Void
    let onChangeSettings: () -> Void
    @State private var windowSize: CGSize = .zero
    
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 960.0
        let baseHeight: CGFloat = 640.0
        
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
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 32 * uiScale) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 80 * uiScale))
                    .foregroundStyle(iconColor)
                
                // Title and message
                VStack(spacing: 16 * uiScale) {
                    Text(error.title)
                        .font(.system(size: 28 * uiScale, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text(error.message)
                        .font(.system(size: 15 * uiScale))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 450 * uiScale)
                }
                
                Divider()
                    .frame(maxWidth: 400 * uiScale)
                
                // Action buttons
                VStack(spacing: 12 * uiScale) {
                    if error.category == .permissionDenied {
                        Button {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("システム設定を開く", systemImage: "gear")
                                .font(.system(size: 15 * uiScale, weight: .medium))
                                .frame(minWidth: 200 * uiScale)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut("s", modifiers: [.command])
                        
                    } else if error.category == .diskImage {
                        Button {
                            onChangeSettings()
                        } label: {
                            Label("保存先を変更", systemImage: "folder.badge.gearshape")
                                .font(.system(size: 15 * uiScale, weight: .medium))
                                .frame(minWidth: 200 * uiScale)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut("s", modifiers: [.command])
                        
                    } else if error.requiresAction {
                        SettingsLink {
                            Label("設定を開く", systemImage: "gear")
                                .font(.system(size: 15 * uiScale, weight: .medium))
                                .frame(minWidth: 200 * uiScale)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    HStack(spacing: 12 * uiScale) {
                        Button {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Text("終了")
                                .font(.system(size: 14 * uiScale, weight: .medium))
                                .frame(minWidth: 80 * uiScale)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button {
                            onRetry()
                        } label: {
                            Label("再試行", systemImage: "arrow.clockwise")
                                .font(.system(size: 14 * uiScale, weight: .medium))
                                .frame(minWidth: 100 * uiScale)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(48 * uiScale)
            .frame(maxWidth: 600 * uiScale)
            .background(
                ZStack {
                    LinearGradient(colors: [.orange.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 25 * uiScale)
                    RoundedRectangle(cornerRadius: 20 * uiScale).glassEffect(.regular.tint(.orange.opacity(0.14)), in: RoundedRectangle(cornerRadius: 20 * uiScale))
                }
                .allowsHitTesting(false)
            )
            .overlay { LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 20 * uiScale)).allowsHitTesting(false) }
            .shadow(color: .orange.opacity(0.2), radius: 35 * uiScale, x: 0, y: 12 * uiScale)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
    }
    
    private var iconName: String {
        switch error.category {
        case .permissionDenied:
            return "lock.shield.fill"
        case .diskImage:
            return "externaldrive.badge.exclamationmark"
        default:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var iconColor: Color {
        switch error.category {
        case .permissionDenied:
            return .red
        case .diskImage:
            return .orange
        default:
            return .orange
        }
    }
}

// MARK: - Termination Flow View
struct TerminationFlowView: View {
    let state: AppViewModel.TerminationFlowState
    let onContinueWaiting: () -> Void
    let onForceTerminate: () -> Void
    let onCancel: () -> Void
    @State private var windowSize: CGSize = .zero
    
    private func calculateUIScale(for size: CGSize) -> CGFloat {
        let baseWidth: CGFloat = 960.0
        let baseHeight: CGFloat = 640.0
        
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
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 32 * uiScale) {
                switch state {
                case .unmounting(let status):
                    unmountingView(status: status)
                case .timeout:
                    timeoutView()
                case .failed(let failedCount, let runningApps):
                    failedView(failedCount: failedCount, runningApps: runningApps)
                case .idle:
                    EmptyView()
                }
            }
            .padding(48 * uiScale)
            .frame(maxWidth: 600 * uiScale)
            .background(
                ZStack {
                    LinearGradient(colors: [.blue.opacity(0.07), .clear], startPoint: .topLeading, endPoint: .bottomTrailing).blur(radius: 25 * uiScale)
                    RoundedRectangle(cornerRadius: 20 * uiScale).glassEffect(.regular.tint(.blue.opacity(0.14)), in: RoundedRectangle(cornerRadius: 20 * uiScale))
                }
                .allowsHitTesting(false)
            )
            .overlay { LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .topLeading, endPoint: .center).clipShape(RoundedRectangle(cornerRadius: 20 * uiScale)).allowsHitTesting(false) }
            .shadow(color: .blue.opacity(0.25), radius: 35 * uiScale, x: 0, y: 12 * uiScale)
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            windowSize = newSize
        }
    }
    
    private func unmountingView(status: String) -> some View {
        VStack(spacing: 24 * uiScale) {
            ProgressView()
                .scaleEffect(1.5 * uiScale)
            
            Text(status)
                .font(.system(size: 17 * uiScale, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
    
    private func timeoutView() -> some View {
        VStack(spacing: 32 * uiScale) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 64 * uiScale))
                .foregroundStyle(.orange)
            
            VStack(spacing: 16 * uiScale) {
                Text("アンマウント処理がタイムアウトしました")
                    .font(.system(size: 22 * uiScale, weight: .bold))
                
                Text("ディスクイメージのアンマウントに時間がかかっています。\n\n強制終了しますか？（データが失われる可能性があります）")
                    .font(.system(size: 15 * uiScale))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12 * uiScale) {
                Button {
                    onContinueWaiting()
                } label: {
                    Text("待機")
                        .font(.system(size: 14 * uiScale, weight: .medium))
                        .frame(minWidth: 100 * uiScale)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button {
                    onForceTerminate()
                } label: {
                    Text("強制終了")
                        .font(.system(size: 14 * uiScale, weight: .medium))
                        .frame(minWidth: 100 * uiScale)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    private func failedView(failedCount: Int, runningApps: [String]) -> some View {
        RunningAppsBlockingView(
            runningAppBundleIDs: runningApps,
            onCancel: onCancel,
            onQuitAllAndRetry: { [self] in
                // Retry unmount after quitting all apps
                self.retryUnmount()
            },
            uiScale: uiScale
        )
    }
    
    private func retryUnmount() {
        // Apps are already terminated by quitAllAppsAndRetry()
        // Wait for auto-eject to complete, then verify and eject PlayCover container
        Task { @MainActor in
            if let viewModel = AppDelegate.shared {
                viewModel.terminationFlowState = .unmounting(status: String(localized: "アンマウント処理を完了しています…"))
                
                // Give auto-eject time to complete (it triggers on app termination)
                try? await Task.sleep(for: .seconds(1))
                
                // Verify and eject remaining containers (including PlayCover)
                let result = await viewModel.unmountAllContainersForTermination()
                
                if result.success {
                    // All clear, terminate the app without showing result
                    viewModel.terminationFlowState = .idle
                    NSApplication.shared.reply(toApplicationShouldTerminate: true)
                } else if !result.runningApps.isEmpty {
                    // Some apps still running
                    viewModel.terminationFlowState = .failed(failedCount: result.failedCount, runningApps: result.runningApps)
                } else {
                    // PlayCover container failed to eject - block termination
                    viewModel.terminationFlowState = .idle
                    NSApplication.shared.reply(toApplicationShouldTerminate: false)
                    
                    // Show error to user
                    if let launcherVM = viewModel.launcherViewModel {
                        await MainActor.run {
                            launcherVM.unmountFlowState = .error(
                                title: String(localized: "アンマウントに失敗しました"),
                                message: String(localized: "一部のディスクイメージをアンマウントできませんでした。\n\n手動でアンマウントしてから再度終了してください。")
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Running Apps Blocking View (Shared by ⌘Q and ALL unmount)
struct RunningAppsBlockingView: View {
    let runningAppBundleIDs: [String]
    let onCancel: () -> Void
    let onQuitAllAndRetry: (() -> Void)?  // Optional: retry unmount after quitting all apps
    var uiScale: CGFloat = 1.0
    
    @State private var appInfoList: [RunningAppInfo] = []
    @State private var isProcessing: Bool = false  // Processing state for "すべて終了"
    
    struct RunningAppInfo: Identifiable {
        let id: String  // bundle ID
        let name: String
        let icon: NSImage?
        let app: NSRunningApplication
    }
    
    var body: some View {
        ZStack {
            // Background overlay - same as QuickLauncherView
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    if !isProcessing {
                        onCancel()
                    }
                }
            
            VStack(spacing: 32 * uiScale) {
                if isProcessing {
                    // Processing state: show progress indicator
                    ProgressView()
                        .scaleEffect(1.5 * uiScale)
                        .padding(.bottom, 16 * uiScale)
                    
                    Text("アプリを終了しています...")
                        .font(.system(size: 17 * uiScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    // Header with icon and title
                    VStack(spacing: 16 * uiScale) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 72 * uiScale))
                            .foregroundStyle(.orange)
                            .shadow(color: .orange.opacity(0.3), radius: 12 * uiScale, x: 0, y: 4 * uiScale)
                        
                        VStack(spacing: 8 * uiScale) {
                            Text("一部のディスクイメージをアンマウントできません")
                                .font(.system(size: 24 * uiScale, weight: .bold))
                                .multilineTextAlignment(.center)
                            
                            Text("以下のアプリが実行中です。")
                                .font(.system(size: 15 * uiScale))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Running apps list with beautiful cards
                    ScrollView {
                        VStack(spacing: 16 * uiScale) {
                            ForEach(appInfoList) { appInfo in
                                HStack(spacing: 16 * uiScale) {
                                    // App icon - larger and more prominent
                                    if let icon = appInfo.icon {
                                        Image(nsImage: icon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 64 * uiScale, height: 64 * uiScale)
                                            .clipShape(RoundedRectangle(cornerRadius: 14 * uiScale))
                                            .shadow(color: .black.opacity(0.15), radius: 4 * uiScale, x: 0, y: 2 * uiScale)
                                    } else {
                                        RoundedRectangle(cornerRadius: 14 * uiScale)
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 64 * uiScale, height: 64 * uiScale)
                                            .overlay {
                                                Image(systemName: "app.dashed")
                                                    .font(.system(size: 28 * uiScale))
                                                    .foregroundStyle(.tertiary)
                                            }
                                    }
                                    
                                    // App name - larger text
                                    Text(appInfo.name)
                                        .font(.system(size: 17 * uiScale, weight: .semibold))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .foregroundStyle(.primary)
                                    
                                    // Quit button - modern style
                                    Button {
                                        quitApp(appInfo.app)
                                    } label: {
                                        HStack(spacing: 6 * uiScale) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 14 * uiScale))
                                            Text("終了")
                                                .font(.system(size: 14 * uiScale, weight: .semibold))
                                        }
                                        .padding(.horizontal, 16 * uiScale)
                                        .padding(.vertical, 10 * uiScale)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.red)
                                }
                                .padding(20 * uiScale)
                                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16 * uiScale))
                                .shadow(color: .black.opacity(0.1), radius: 8 * uiScale, x: 0, y: 4 * uiScale)
                            }
                        }
                        .padding(.horizontal, 4 * uiScale)
                    }
                    .frame(maxHeight: 350 * uiScale)
                    
                    // Bottom action buttons
                    HStack(spacing: 16 * uiScale) {
                        Button {
                            onCancel()
                        } label: {
                            Text("キャンセル")
                                .font(.system(size: 16 * uiScale, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44 * uiScale)
                        }
                        .buttonStyle(.bordered)
                        .keyboardShortcut(.cancelAction)
                        
                        Button {
                            if let onQuitAllAndRetry = onQuitAllAndRetry {
                                quitAllAppsAndRetry(onRetry: onQuitAllAndRetry)
                            } else {
                                quitAllApps()
                            }
                        } label: {
                            HStack(spacing: 8 * uiScale) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16 * uiScale))
                                Text("すべて終了")
                                    .font(.system(size: 16 * uiScale, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44 * uiScale)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(40 * uiScale)
            .frame(maxWidth: 700 * uiScale)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20 * uiScale))
            .shadow(color: .black.opacity(0.3), radius: 40 * uiScale, x: 0, y: 20 * uiScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadRunningApps()
        }
    }
    
    private func loadRunningApps() {
        let launcherService = LauncherService()
        appInfoList = runningAppBundleIDs.compactMap { bundleID in
            guard let app = launcherService.getRunningApp(bundleID: bundleID) else {
                return nil
            }
            
            let name = app.localizedName ?? bundleID
            let icon = app.icon
            
            return RunningAppInfo(id: bundleID, name: name, icon: icon, app: app)
        }
    }
    
    private func quitApp(_ app: NSRunningApplication) {
        let launcherService = LauncherService()
        _ = launcherService.terminateApp(bundleID: app.bundleIdentifier ?? "")
        
        // Wait a moment and check if app is still running
        // Using Swift 6.2 structured concurrency instead of DispatchQueue
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            loadRunningApps()
            
            // If all apps are closed, automatically proceed
            if appInfoList.isEmpty {
                onCancel()  // Close dialog and let the system retry
            }
        }
    }
    
    private func quitAllApps() {
        let launcherService = LauncherService()
        
        // Terminate all running apps
        for bundleID in runningAppBundleIDs {
            _ = launcherService.terminateApp(bundleID: bundleID)
        }
        
        // Wait a moment and check if all apps are closed
        // Using Swift 6.2 structured concurrency instead of DispatchQueue
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            loadRunningApps()
            
            // If all apps are closed, automatically proceed
            if appInfoList.isEmpty {
                // For ⌘Q flow: retry unmount
                // For ALL unmount flow: just close dialog
                if let retry = onQuitAllAndRetry {
                    retry()
                } else {
                    onCancel()
                }
            }
        }
    }
    
    private func quitAllAppsAndRetry(onRetry: @escaping () -> Void) {
        // Show processing state
        isProcessing = true
        
        // Terminate all running apps
        let launcherService = LauncherService()
        for bundleID in runningAppBundleIDs {
            _ = launcherService.terminateApp(bundleID: bundleID)
        }
        
        // Wait for termination and auto-eject, then retry
        // Using Swift 6.2 structured concurrency instead of DispatchQueue
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            onRetry()
        }
    }
}
