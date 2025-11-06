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
    @State private var perAppSettingsStore: PerAppSettingsStore

    init() {
        let settings = SettingsStore()
        let perAppSettings = PerAppSettingsStore()
        _settingsStore = State(wrappedValue: settings)
        _perAppSettingsStore = State(wrappedValue: perAppSettings)
        _appViewModel = State(wrappedValue: AppViewModel(settings: settings, perAppSettings: perAppSettings))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appViewModel)
                .environment(settingsStore)
                .environment(perAppSettingsStore)
        }
        Settings {
            SettingsRootView()
                .environment(appViewModel)
                .environment(settingsStore)
                .environment(perAppSettingsStore)
        }
    }
}
