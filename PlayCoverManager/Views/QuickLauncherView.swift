import SwiftUI
import AppKit

struct QuickLauncherView: View {
    @ObservedObject var viewModel: LauncherViewModel
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        NavigationSplitView {
            List(viewModel.filteredApps, selection: $viewModel.selectedApp) { app in
                HStack(alignment: .center, spacing: 12) {
                    AppIconView(icon: app.icon)
                    VStack(alignment: .leading) {
                        Text(app.localizedName ?? app.displayName)
                        Text(app.bundleIdentifier)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if app.lastLaunchedFlag {
                        Image(systemName: "clock.badge.checkmark")
                            .foregroundStyle(.green)
                            .help("前回起動")
                    }
                }
                .padding(4)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { viewModel.launch(app: app) }
            }
            .searchable(text: $viewModel.searchText, prompt: Text("アプリを検索"))
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Label("再読み込み", systemImage: "arrow.clockwise")
                    }
                    .keyboardShortcut("r", modifiers: [.command])

                    Button {
                        viewModel.unmountAll(applyToPlayCoverContainer: true)
                    } label: {
                        Label("すべてアンマウント", systemImage: "eject")
                    }
                    .keyboardShortcut(KeyEquivalent("u"), modifiers: [.command, .shift])
                }
            }
        } detail: {
            if let selected = viewModel.selectedApp ?? viewModel.filteredApps.first {
                AppDetailView(app: selected) {
                    viewModel.launch(app: selected)
                } refreshAction: {
                    Task { await viewModel.refresh() }
                }
            } else {
                Text("左の一覧からアプリを選択してください")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .overlay(alignment: .center) {
            if viewModel.isBusy {
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
        }
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

private struct AppDetailView: View {
    let app: PlayCoverApp
    let launchAction: () -> Void
    let refreshAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                AppIconView(icon: app.icon)
                    .frame(width: 80, height: 80)
                VStack(alignment: .leading, spacing: 8) {
                    Text(app.localizedName ?? app.displayName)
                        .font(.title2)
                    if let version = app.version {
                        Text("Version \(version)")
                            .foregroundStyle(.secondary)
                    }
                    Text(app.bundleIdentifier)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    launchAction()
                } label: {
                    Label("起動", systemImage: "play.circle.fill")
                }
                .keyboardShortcut(.defaultAction)

                Button {
                    refreshAction()
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                }
            }

            Spacer()
        }
        .padding(24)
    }
}
