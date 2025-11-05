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
        let settings = SettingsStore()
        _settingsStore = State(wrappedValue: settings)
        _appViewModel = State(wrappedValue: AppViewModel(settings: settings))
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
