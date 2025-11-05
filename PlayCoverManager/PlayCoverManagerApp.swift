//
//  PlayCoverManagerApp.swift
//  PlayCoverManager
//
//  Created by HEHEX on 2025/11/05.
//

import SwiftUI

@main
struct PlayCoverManagerApp: App {
    @StateObject private var appViewModel: AppViewModel
    @StateObject private var settingsStore: SettingsStore

    init() {
        let settings = SettingsStore()
        _settingsStore = StateObject(wrappedValue: settings)
        _appViewModel = StateObject(wrappedValue: AppViewModel(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(appViewModel)
                .environmentObject(settingsStore)
        }
        Settings {
            SettingsRootView()
                .environmentObject(appViewModel)
                .environmentObject(settingsStore)
        }
    }
}
