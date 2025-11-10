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

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                ProgressView()
                    .scaleEffect(1.5)
                
                Text(status)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Button {
                    retry()
                } label: {
                    Label("再試行", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(40)
            .frame(maxWidth: 500)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 10)
        }
    }
}

struct ErrorView: View {
    let error: AppError
    let onRetry: () -> Void
    let onChangeSettings: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 80))
                    .foregroundStyle(iconColor)
                
                // Title and message
                VStack(spacing: 16) {
                    Text(error.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                    
                    Text(error.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 450)
                }
                
                Divider()
                    .frame(maxWidth: 400)
                
                // Action buttons
                VStack(spacing: 12) {
                    if error.category == .permissionDenied {
                        Button {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Label("システム設定を開く", systemImage: "gear")
                                .font(.system(size: 15, weight: .medium))
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut("s", modifiers: [.command])
                        
                    } else if error.category == .diskImage {
                        Button {
                            onChangeSettings()
                        } label: {
                            Label("保存先を変更", systemImage: "folder.badge.gearshape")
                                .font(.system(size: 15, weight: .medium))
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut("s", modifiers: [.command])
                        
                    } else if error.requiresAction {
                        SettingsLink {
                            Label("設定を開く", systemImage: "gear")
                                .font(.system(size: 15, weight: .medium))
                                .frame(minWidth: 200)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    
                    HStack(spacing: 12) {
                        Button {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Text("終了")
                                .font(.system(size: 14, weight: .medium))
                                .frame(minWidth: 80)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        
                        Button {
                            onRetry()
                        } label: {
                            Label("再試行", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium))
                                .frame(minWidth: 100)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
            .padding(48)
            .frame(maxWidth: 600)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: 10)
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
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
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
            .padding(48)
            .frame(maxWidth: 600)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 10)
        }
    }
    
    private func unmountingView(status: String) -> some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text(status)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
    
    private func timeoutView() -> some View {
        VStack(spacing: 32) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            VStack(spacing: 16) {
                Text("アンマウント処理がタイムアウトしました")
                    .font(.title2.bold())
                
                Text("ディスクイメージのアンマウントに時間がかかっています。\n\n強制終了しますか？（データが失われる可能性があります）")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button {
                    onContinueWaiting()
                } label: {
                    Text("待機")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Button {
                    onForceTerminate()
                } label: {
                    Text("強制終了")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 100)
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
            }
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
    
    @State private var appInfoList: [RunningAppInfo] = []
    
    struct RunningAppInfo: Identifiable {
        let id: String  // bundle ID
        let name: String
        let icon: NSImage?
        let app: NSRunningApplication
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            VStack(spacing: 16) {
                Text("一部のディスクイメージをアンマウントできません")
                    .font(.title2.bold())
                
                Text("以下のアプリが実行中です。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                // Running apps list with icons and quit buttons
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appInfoList) { appInfo in
                            HStack(spacing: 12) {
                                // App icon
                                if let icon = appInfo.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 48, height: 48)
                                }
                                
                                // App name
                                Text(appInfo.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Quit button
                                Button {
                                    quitApp(appInfo.app)
                                } label: {
                                    Text("終了")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .padding(12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
            
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("キャンセル")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                
                Button {
                    if let onQuitAllAndRetry = onQuitAllAndRetry {
                        quitAllAppsAndRetry(onRetry: onQuitAllAndRetry)
                    } else {
                        quitAllApps()
                    }
                } label: {
                    Text("すべて終了")
                        .font(.system(size: 14, weight: .medium))
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(48)
        .frame(maxWidth: 600)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        let launcherService = LauncherService()
        
        // Terminate all running apps
        for bundleID in runningAppBundleIDs {
            _ = launcherService.terminateApp(bundleID: bundleID)
        }
        
        // Wait a moment and then retry
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onRetry()
        }
    }
}
