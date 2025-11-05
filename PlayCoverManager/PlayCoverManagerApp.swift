//
//  PlayCoverManagerApp.swift
//  PlayCoverManager
//
//  Created by HEHEX on 2025/11/05.
//

import SwiftUI
import Observation

@main
struct PlayCoverManagerApp: App {
    @State private var appViewModel: AppViewModel
    @State private var settingsStore: SettingsStore

    init() {
        print("⭐️ [APP] アプリ起動")
        let settings = SettingsStore()
        _settingsStore = State(wrappedValue: settings)
        _appViewModel = State(wrappedValue: AppViewModel(settings: settings))
        print("⭐️ [APP] 初期化完了")
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appViewModel)
                .environment(settingsStore)
        }
        Settings {
            SettingsRootView()
                .environment(appViewModel)
                .environment(settingsStore)
        }
    }
}
