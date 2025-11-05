import SwiftUI
import AppKit
import Observation
import UniformTypeIdentifiers

struct SettingsRootView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
            AppManagementSettingsView()
                .tabItem {
                    Label("アプリ管理", systemImage: "square.and.arrow.down")
                }
            DataSettingsView()
                .tabItem {
                    Label("データ", systemImage: "internaldrive")
                }
            MaintenanceSettingsView()
                .tabItem {
                    Label("メンテナンス", systemImage: "wrench")
                }
        }
        .padding(24)
        .frame(width: 600, height: 480)
    }
}

private struct GeneralSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        Form {
            Section(header: Text("ディスクイメージ")) {
                LabeledContent("保存先") {
                    Text(settingsStore.diskImageDirectory?.path ?? "未設定")
                        .font(.system(.body, design: .monospaced))
                }
                Button("保存先を変更") {
                    chooseStorageDirectory()
                }
                Toggle("マウント時に Finder に表示しない (-nobrowse)", isOn: Binding(get: { settingsStore.nobrowseEnabled }, set: { settingsStore.nobrowseEnabled = $0 }))
            }
        }
    }

    private func chooseStorageDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "選択"
        if panel.runModal() == .OK, let url = panel.url {
            settingsStore.diskImageDirectory = url
        }
    }
}

private struct AppManagementSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel
    @State private var showingInstaller = false
    @State private var showingUninstaller = false
    
    var body: some View {
        Form {
            Section(header: Text("インストール")) {
                Button {
                    showingInstaller = true
                } label: {
                    Label("IPA をインストール", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                
                Text("IPA ファイルを選択して PlayCover 経由でインストールします。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(header: Text("アンインストール")) {
                Button {
                    showingUninstaller = true
                } label: {
                    Label("アプリをアンインストール", systemImage: "trash")
                }
                .tint(.red)
                
                Text("インストール済みアプリとディスクイメージを削除します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $showingInstaller) {
            IPAInstallerSheet()
        }
        .sheet(isPresented: $showingUninstaller) {
            AppUninstallerSheet()
        }
    }
}

private struct DataSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        Form {
            Section(header: Text("内部データ処理の既定値")) {
                Picker("既定の処理", selection: Binding<SettingsStore.InternalDataStrategy>(get: { settingsStore.defaultDataHandling }, set: { settingsStore.defaultDataHandling = $0 })) {
                    ForEach(SettingsStore.InternalDataStrategy.allCases) { strategy in
                        Text(strategy.localizedDescription).tag(strategy)
                    }
                }
            }
            Section(header: Text("説明")) {
                Text("アプリのコンテナに内部データが残っていた場合のデフォルト処理です。ランチャーから起動する際に変更できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// IPA Installer Sheet
private struct IPAInstallerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIPAs: [URL] = []
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var progress: Double = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("IPA インストーラー")
                .font(.title2)
                .fontWeight(.semibold)
            
            if selectedIPAs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("IPA ファイルを選択してください")
                        .font(.headline)
                    
                    Button("IPA を選択") {
                        selectIPAFiles()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("選択された IPA ファイル:")
                        .font(.headline)
                    
                    List(selectedIPAs, id: \.self) { ipa in
                        HStack {
                            Image(systemName: "doc.fill")
                            Text(ipa.lastPathComponent)
                            Spacer()
                            Button {
                                selectedIPAs.removeAll { $0 == ipa }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 200)
                    
                    if isProcessing {
                        VStack(spacing: 8) {
                            ProgressView(value: progress, total: Double(selectedIPAs.count))
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if !selectedIPAs.isEmpty {
                    Button("別の IPA を追加") {
                        selectIPAFiles()
                    }
                    .disabled(isProcessing)
                    
                    Button("インストール開始") {
                        Task {
                            await startInstallation()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isProcessing)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 600, height: 500)
    }
    
    private func selectIPAFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        if let ipaType = UTType(filenameExtension: "ipa") {
            panel.allowedContentTypes = [ipaType]
        } else {
            panel.allowedContentTypes = [.data]
        }
        panel.message = "インストールする IPA ファイルを選択してください"
        
        if panel.runModal() == .OK {
            selectedIPAs.append(contentsOf: panel.urls)
        }
    }
    
    private func startInstallation() async {
        isProcessing = true
        
        for (index, ipaURL) in selectedIPAs.enumerated() {
            progress = Double(index)
            statusMessage = "\(ipaURL.lastPathComponent) をインストール中..."
            
            // TODO: Implement actual installation logic
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        progress = Double(selectedIPAs.count)
        statusMessage = "すべてのインストールが完了しました"
        isProcessing = false
        
        // Auto-close after 2 seconds
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        dismiss()
    }
}

// App Uninstaller Sheet
private struct AppUninstallerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apps: [UninstallableApp] = []
    @State private var selectedApps: Set<UUID> = []
    @State private var isLoading = true
    @State private var totalSize: UInt64 = 0
    
    struct UninstallableApp: Identifiable, Hashable {
        let id = UUID()
        let bundleID: String
        let name: String
        let appSize: UInt64
        let diskImageSize: UInt64
        let appURL: URL
        let diskImageURL: URL?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: UninstallableApp, rhs: UninstallableApp) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("アプリアンインストーラー")
                .font(.title2)
                .fontWeight(.semibold)
            
            if isLoading {
                ProgressView("アプリ一覧を読み込み中...")
            } else if apps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("アンインストール可能なアプリがありません")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("インストール済みアプリ (\(apps.count) 個)")
                            .font(.headline)
                        Spacer()
                        Text("合計: \(ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    List(apps, selection: $selectedApps) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.name)
                                    .font(.body)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(app.appSize + app.diskImageSize), countStyle: .file))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button("キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if !apps.isEmpty && !selectedApps.isEmpty {
                    Button("削除 (\(selectedApps.count) 個)") {
                        // TODO: Implement uninstall
                    }
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 600, height: 500)
        .task {
            await loadApps()
        }
    }
    
    private func loadApps() async {
        // TODO: Load actual apps
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLoading = false
    }
}

private struct MaintenanceSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        Form {
            Section(header: Text("アンマウント")) {
                Button("すべてのディスクイメージをアンマウントして終了") {
                    appViewModel.launcherViewModel?.unmountAll(applyToPlayCoverContainer: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appViewModel.terminateApplication()
                    }
                }
                .disabled(appViewModel.launcherViewModel == nil)
                Text("ランチャーが初期化されている場合のみ実行できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Section(header: Text("デバッグ情報")) {
                LabeledContent("現在のフォーマット") {
                    Text(settingsStore.diskImageFormat.rawValue)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            
            Section(header: Text("リセット")) {
                Button("設定をリセット") {
                    resetSettings()
                }
                .foregroundStyle(.red)
                Text("すべての設定を初期値に戻します（ディスクイメージは削除されません）。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func resetSettings() {
        UserDefaults.standard.removeObject(forKey: "diskImageDirectory")
        UserDefaults.standard.removeObject(forKey: "diskImageDirectoryBookmark")
        UserDefaults.standard.removeObject(forKey: "nobrowseEnabled")
        UserDefaults.standard.removeObject(forKey: "defaultDataHandling")
        UserDefaults.standard.removeObject(forKey: "diskImageFormat")
        
        NSApp.sendAction(#selector(NSApplication.terminate(_:)), to: nil, from: nil)
    }
}

