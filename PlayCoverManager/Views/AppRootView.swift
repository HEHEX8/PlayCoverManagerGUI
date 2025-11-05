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
                } else {
                    CheckingView(status: "アプリ情報を取得しています…") {
                        appViewModel.retry()
                    }
                }
            case .error(let error):
                ErrorView(error: error) {
                    appViewModel.retry()
                }
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
        VStack(spacing: 16) {
            ProgressView()
            Text(status)
            Button("再試行", action: retry)
                .keyboardShortcut(.defaultAction)
        }
        .padding()
    }
}

struct ErrorView: View {
    let error: AppError
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(iconColor)
            Text(error.title)
                .font(.title2)
            Text(error.message)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 500)
            HStack(spacing: 12) {
                if error.category == .permissionDenied {
                    Button("システム設定を開く") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .keyboardShortcut("s", modifiers: [.command])
                } else if error.requiresAction {
                    Button("設定を開く") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
                Button("終了") { NSApplication.shared.terminate(nil) }
                Button("再試行", action: retry)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
    
    private var iconName: String {
        switch error.category {
        case .permissionDenied:
            return "lock.shield"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch error.category {
        case .permissionDenied:
            return .red
        default:
            return .orange
        }
    }
}
