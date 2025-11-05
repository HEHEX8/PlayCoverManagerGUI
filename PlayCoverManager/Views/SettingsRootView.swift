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
    @Environment(SettingsStore.self) private var settingsStore
    @State private var installerService: IPAInstallerService?
    @State private var selectedIPAs: [URL] = []
    @State private var isProcessing = false
    @State private var statusMessage = ""
    @State private var progress: Double = 0
    @State private var showResults = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("IPA インストーラー")
                .font(.title2)
                .fontWeight(.semibold)
            
            if selectedIPAs.isEmpty && !showResults {
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
            } else if showResults {
                // Results view
                VStack(alignment: .leading, spacing: 16) {
                    if let service = installerService, !service.installedApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("✅ インストール成功: \(service.installedApps.count) 個")
                                .font(.headline)
                                .foregroundStyle(.green)
                            ForEach(service.installedApps, id: \.self) { appName in
                                Text("  • \(appName)")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    if let service = installerService, !service.failedApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("❌ インストール失敗: \(service.failedApps.count) 個")
                                .font(.headline)
                                .foregroundStyle(.red)
                            ForEach(service.failedApps, id: \.self) { error in
                                Text("  • \(error)")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                            ProgressView(value: progress)
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button(showResults ? "閉じる" : "キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if !selectedIPAs.isEmpty && !showResults {
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
        .onAppear {
            let diskImageService = DiskImageService(processRunner: ProcessRunner(), settings: settingsStore)
            installerService = IPAInstallerService(diskImageService: diskImageService, settingsStore: settingsStore)
        }
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
        guard let service = installerService else { return }
        
        await MainActor.run {
            isProcessing = true
        }
        
        do {
            try await service.installIPAs(selectedIPAs)
        } catch {
            await MainActor.run {
                statusMessage = "エラー: \(error.localizedDescription)"
            }
        }
        
        // Update UI with service state on main thread
        await MainActor.run {
            statusMessage = service.currentStatus
            progress = service.currentProgress
            isProcessing = false
            showResults = true
        }
    }
}

// App Uninstaller Sheet
private struct AppUninstallerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore
    @State private var uninstallerService: AppUninstallerService?
    @State private var apps: [AppUninstallerService.InstalledAppInfo] = []
    @State private var selectedApps: Set<String> = []
    @State private var isLoading = true
    @State private var isUninstalling = false
    @State private var statusMessage = ""
    @State private var showResults = false
    @State private var totalSize: Int64 = 0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("アプリアンインストーラー")
                .font(.title2)
                .fontWeight(.semibold)
            
            if isLoading {
                ProgressView("アプリ一覧を読み込み中...")
            } else if showResults {
                // Results view
                VStack(alignment: .leading, spacing: 16) {
                    if let service = uninstallerService, !service.uninstalledApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("✅ アンインストール成功: \(service.uninstalledApps.count) 個")
                                .font(.headline)
                                .foregroundStyle(.green)
                            ForEach(service.uninstalledApps, id: \.self) { appName in
                                Text("  • \(appName)")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    if let service = uninstallerService, !service.failedApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("❌ アンインストール失敗: \(service.failedApps.count) 個")
                                .font(.headline)
                                .foregroundStyle(.red)
                            ForEach(service.failedApps, id: \.self) { error in
                                Text("  • \(error)")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                        Text("合計: \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    List(apps, id: \.bundleID, selection: $selectedApps) { app in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.appName)
                                    .font(.body)
                                Text(app.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(ByteCountFormatter.string(fromByteCount: app.appSize + app.diskImageSize, countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("App: \(ByteCountFormatter.string(fromByteCount: app.appSize, countStyle: .file))")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    
                    if isUninstalling {
                        VStack(spacing: 8) {
                            ProgressView()
                            Text(statusMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button(showResults ? "閉じる" : "キャンセル") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                if !apps.isEmpty && !selectedApps.isEmpty && !showResults {
                    Button("削除 (\(selectedApps.count) 個)") {
                        Task {
                            await startUninstallation()
                        }
                    }
                    .tint(.red)
                    .buttonStyle(.borderedProminent)
                    .disabled(isUninstalling)
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
        guard let service = uninstallerService else {
            let diskImageService = DiskImageService(processRunner: ProcessRunner(), settings: settingsStore)
            let service = AppUninstallerService(diskImageService: diskImageService, settingsStore: settingsStore)
            self.uninstallerService = service
            await loadApps()
            return
        }
        
        do {
            apps = try await service.getInstalledApps()
            totalSize = apps.reduce(0) { $0 + $1.appSize + $1.diskImageSize }
        } catch {
            apps = []
            totalSize = 0
        }
        
        isLoading = false
    }
    
    private func startUninstallation() async {
        guard let service = uninstallerService else { return }
        
        let appsToUninstall = apps.filter { selectedApps.contains($0.bundleID) }
        guard !appsToUninstall.isEmpty else { return }
        
        isUninstalling = true
        statusMessage = "アンインストール中..."
        
        do {
            try await service.uninstallApps(appsToUninstall)
        } catch {
            statusMessage = "エラー: \(error.localizedDescription)"
        }
        
        statusMessage = service.currentStatus
        isUninstalling = false
        showResults = true
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

