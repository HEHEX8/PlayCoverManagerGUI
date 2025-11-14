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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appViewModel: AppViewModel
    @State private var settingsStore: SettingsStore
    @State private var perAppSettingsStore: PerAppSettingsStore
    @State private var showingUnsupportedOSAlert = false

    init() {
        // Suppress unnecessary system logs
        setenv("OS_ACTIVITY_MODE", "disable", 1)
        
        // macOS バージョンチェック（macOS Tahoe 26.0 以降が必要）
        if !Self.isCompatibleOS() {
            _showingUnsupportedOSAlert = State(initialValue: true)
        }
        
        let settings = SettingsStore()
        let perAppSettings = PerAppSettingsStore()
        _settingsStore = State(wrappedValue: settings)
        _perAppSettingsStore = State(wrappedValue: perAppSettings)
        
        let viewModel = AppViewModel(settings: settings, perAppSettings: perAppSettings)
        _appViewModel = State(wrappedValue: viewModel)
        
        // Pass viewModel to AppDelegate for termination handling
        AppDelegate.shared = viewModel
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
                
                Button(String(localized: "アプリをアンインストール")) {
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
                Button("設定(メニュー)") {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            
            // Quit command (ensure ⌘Q works)
            CommandGroup(replacing: .appTermination) {
                Button("PlayCover Manager を終了") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: [.command])
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

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppViewModel?
    private var forceTerminateTimer: Timer?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for multiple running instances
        let bundleID = Bundle.main.bundleIdentifier ?? "io.playcover.PlayCoverManager"
        let runningApps = NSWorkspace.shared.runningApplications
        let matchingApps = runningApps.filter { $0.bundleIdentifier == bundleID }
        
        // If more than 1 instance (self + others) - prevent duplicate launch
        if matchingApps.count > 1 {
            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "PlayCover Manager は既に起動しています"
                alert.informativeText = """
                    PlayCover Manager は既に実行中です。
                    
                    複数のインスタンスを同時に実行すると、ディスクイメージの競合が発生し、
                    アンマウントに失敗する可能性があります。
                    
                    実行中のインスタンス: \(matchingApps.count)個
                    
                    このインスタンスを終了します。
                    """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                
                // Always terminate this instance to prevent conflicts
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // ⌘W: Do not terminate, just close the window
        return false
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // When dock icon is clicked and no windows are visible, show main window
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check if critical operation is in progress
        Task { @MainActor in
            if CriticalOperationService.shared.isOperationInProgress {
                let description = CriticalOperationService.shared.currentOperationDescription ?? "処理"
                Logger.lifecycle("Termination blocked: Critical operation in progress - \(description)")
                
                // Show alert that termination is not allowed
                let alert = NSAlert()
                alert.messageText = String(localized: "処理中のため終了できません")
                alert.informativeText = String(localized: "\(description)が完了するまでお待ちください。")
                alert.alertStyle = .warning
                alert.addButton(withTitle: String(localized: "OK"))
                alert.runModal()
            }
        }
        
        // Block termination if critical operation is in progress
        if CriticalOperationService.shared.isOperationInProgress {
            return .terminateCancel
        }
        
        // ⌘Q: Unmount all containers before terminating
        guard let viewModel = Self.shared else {
            return .terminateNow
        }
        
        // Set up 10-second timeout for force termination (allow time for force eject)
        forceTerminateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimeout()
            }
        }
        
        // Start async unmount and return later
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            viewModel.terminationFlowState = .unmounting(status: String(localized: "ディスクイメージをアンマウントしています…"))
            
            // Try to unmount all containers
            let result = await viewModel.unmountAllContainersForTermination()
            
            // Cancel timeout timer
            self.forceTerminateTimer?.invalidate()
            self.forceTerminateTimer = nil
            
            if result.success {
                // All unmounted successfully
                viewModel.terminationFlowState = .idle
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            } else {
                // Some failed - show UI
                viewModel.terminationFlowState = .failed(failedCount: result.failedCount, runningApps: result.runningApps)
            }
        }
        
        return .terminateLater
    }
    
    @MainActor
    private func handleTimeout() {
        guard let viewModel = Self.shared else { return }
        viewModel.terminationFlowState = .timeout
    }
    
    @MainActor
    func extendTimeout() {
        forceTerminateTimer?.invalidate()
        forceTerminateTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTimeout()
            }
        }
    }
}
