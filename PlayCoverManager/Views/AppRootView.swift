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
                    CheckingView(status: "セットアップを準備しています…") {
                        appViewModel.retry()
                    }
                }
            case .launcher:
                if let launcherVM = appViewModel.launcherViewModel {
                    QuickLauncherView(viewModel: launcherVM)
                        .environment(launcherVM)
                } else {
                    CheckingView(status: "アプリ情報を取得しています…") {
                        appViewModel.retry()
                    }
                }
            case .error(let error):
                ErrorView(error: error,
                          onRetry: { appViewModel.retry() },
                          onChangeSettings: { appViewModel.requestStorageLocationChange() })
            case .terminating:
                ProgressView("終了しています…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .onAppear { appViewModel.onAppear() }
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
