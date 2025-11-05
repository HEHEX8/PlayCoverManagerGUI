import SwiftUI
import AppKit

struct SettingsRootView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        TabView {
            GeneralSettingsView()
                .environmentObject(settingsStore)
                .tabItem {
                    Label("一般", systemImage: "gear")
                }
            DataSettingsView()
                .environmentObject(settingsStore)
                .tabItem {
                    Label("データ", systemImage: "internaldrive")
                }
            MaintenanceSettingsView()
                .environmentObject(settingsStore)
                .environmentObject(appViewModel)
                .tabItem {
                    Label("メンテナンス", systemImage: "wrench")
                }
        }
        .padding(24)
        .frame(width: 520, height: 360)
    }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

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
                Toggle("マウント時に Finder に表示しない (-nobrowse)", isOn: $settingsStore.nobrowseEnabled)
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

private struct DataSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section(header: Text("内部データ処理の既定値")) {
                Picker("既定の処理", selection: $settingsStore.defaultDataHandling) {
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

private struct MaintenanceSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @EnvironmentObject private var appViewModel: AppViewModel

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
        }
    }
}
