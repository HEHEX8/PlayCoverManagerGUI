import SwiftUI
import AppKit
import Observation

struct QuickLauncherView: View {
    @Bindable var viewModel: LauncherViewModel
    @Environment(SettingsStore.self) private var settingsStore
    
    private let gridColumns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                TextField("アプリを検索", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)
                
                Spacer()
                
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
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // App Grid
            if viewModel.filteredApps.isEmpty {
                EmptyAppListView {
                    Task { await viewModel.refresh() }
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: gridColumns, spacing: 20) {
                        ForEach(viewModel.filteredApps) { app in
                            AppGridItemView(app: app) {
                                viewModel.launch(app: app)
                            } contextAction: {
                                viewModel.selectedApp = app
                            }
                        }
                    }
                    .padding(20)
                }
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

private struct AppGridItemView: View {
    let app: PlayCoverApp
    let launchAction: () -> Void
    let contextAction: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon
            Group {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                } else {
                    Image(systemName: "app.dashed")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            
            // App name
            Text(app.displayName)
                .font(.system(size: 13))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
        }
        .frame(width: 120)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .onTapGesture(count: 2) {
            launchAction()
        }
        .onTapGesture {
            contextAction()
        }
        .contextMenu {
            Button("起動") { launchAction() }
            Divider()
            Button("Finder で表示") {
                NSWorkspace.shared.activateFileViewerSelecting([app.appURL])
            }
            Button("アプリフォルダを開く") {
                NSWorkspace.shared.open(app.appURL.deletingLastPathComponent())
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

private struct EmptyAppListView: View {
    let refreshAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("インストール済みアプリがありません")
                .font(.title2)
                .foregroundStyle(.primary)
            
            VStack(spacing: 8) {
                Text("PlayCover でアプリをインストールすると、ここに表示されます。")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("PlayCover を開いてアプリをインストールしてください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 400)
            
            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "file:///Applications/PlayCover.app") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("PlayCover を開く", systemImage: "app.badge")
                }
                
                Button {
                    refreshAction()
                } label: {
                    Label("再読み込み", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}



