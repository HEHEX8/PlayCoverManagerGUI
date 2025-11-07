//
//  PlayCoverManagerApp.swift
//  PlayCoverManager
//
//  Created by HEHEX on 2025/11/05.
//

import SwiftUI
import Observation
import AppKit

@main
struct PlayCoverManagerApp: App {
    @State private var appViewModel: AppViewModel
    @State private var settingsStore: SettingsStore
    @State private var perAppSettingsStore: PerAppSettingsStore
    @State private var showingUnsupportedOSAlert = false

    init() {
        // macOS バージョンチェック（macOS Tahoe 26.0 以降が必要）
        if !Self.isCompatibleOS() {
            _showingUnsupportedOSAlert = State(initialValue: true)
        }
        
        let settings = SettingsStore()
        let perAppSettings = PerAppSettingsStore()
        _settingsStore = State(wrappedValue: settings)
        _perAppSettingsStore = State(wrappedValue: perAppSettings)
        _appViewModel = State(wrappedValue: AppViewModel(settings: settings, perAppSettings: perAppSettings))
    }
    
    /// macOS Tahoe 26.0 以降かどうかをチェック
    private static func isCompatibleOS() -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        // macOS Tahoe = 26.0
        return osVersion.majorVersion >= 26
    }

    var body: some Scene {
        WindowGroup {
            if showingUnsupportedOSAlert {
                UnsupportedOSView()
            } else {
                AppRootView()
                    .environment(appViewModel)
                    .environment(settingsStore)
                    .environment(perAppSettingsStore)
            }
        }
        .commands {
            // File menu
            CommandGroup(replacing: .newItem) {
                Button("IPA をインストール") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowInstaller"), object: nil)
                }
                .keyboardShortcut("i", modifiers: [.command])
                
                Button("アプリをアンインストール") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowUninstaller"), object: nil)
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
            
            // View menu
            CommandGroup(after: .sidebar) {
                Button("メニューを表示") {
                    NotificationCenter.default.post(name: NSNotification.Name("ToggleDrawer"), object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command])
                
                Divider()
                
                Button("アプリ一覧を更新") {
                    NotificationCenter.default.post(name: NSNotification.Name("RefreshApps"), object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Button("すべてアンマウント") {
                    NotificationCenter.default.post(name: NSNotification.Name("UnmountAll"), object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
                
                Divider()
                
                Button("PlayCover.app を開く") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenPlayCover"), object: nil)
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            
            // Settings menu
            CommandGroup(replacing: .appSettings) {
                Button("設定...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            
            // Help menu
            CommandGroup(after: .help) {
                Button("キーボードショートカット") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowShortcutGuide"), object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command])
            }
        }
    }
}

// MARK: - Unsupported OS View
private struct UnsupportedOSView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            VStack(spacing: 12) {
                Text("このアプリは macOS Tahoe 26.0 以降が必要です")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("お使いの macOS バージョン: \(Self.currentOSVersion)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Text("このアプリは ASIF ディスクイメージフォーマットを使用しており、macOS Tahoe (バージョン 26) 以降でのみ動作します。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }
            
            VStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.open(URL(string: "https://www.apple.com/macos/")!)
                } label: {
                    Label("macOS をアップデート", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button("終了") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(48)
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private static var currentOSVersion: String {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
    }
}
