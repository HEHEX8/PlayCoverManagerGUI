import SwiftUI
import AppKit

struct AppRootView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var settingsStore: SettingsStore

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
        .environmentObject(settingsStore)
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
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(.orange)
            Text(error.title)
                .font(.title2)
            Text(error.message)
                .multilineTextAlignment(.center)
            HStack {
                Button("終了") { NSApplication.shared.terminate(nil) }
                Button("再試行", action: retry)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
    }
}
