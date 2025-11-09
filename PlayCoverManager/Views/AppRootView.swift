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
    
    /// Get app name from bundle ID
    private func getAppName(bundleID: String) -> String {
        // Try to find running app with this bundle ID
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleID }),
           let appName = app.localizedName {
            return appName
        }
        
        // Fallback to bundle ID
        return bundleID
    }
    
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
        VStack(spacing: 32) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            VStack(spacing: 16) {
                Text("一部のディスクイメージをアンマウントできません")
                    .font(.title2.bold())
                
                VStack(spacing: 12) {
                    Text("\(failedCount) 個のディスクイメージをアンマウントできませんでした。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    if !runningApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("実行中のアプリ:")
                                .font(.callout.bold())
                                .foregroundStyle(.secondary)
                            
                            ForEach(runningApps, id: \.self) { bundleID in
                                let appName = getAppName(bundleID: bundleID)
                                Text("• \(appName)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Text("アプリを終了してから再度お試しください。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        .padding()
                        .background(.tertiary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .multilineTextAlignment(.center)
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
                .keyboardShortcut(.defaultAction)
                
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
            }
        }
    }
}
