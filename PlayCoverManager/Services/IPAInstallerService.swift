//
//  IPAInstallerService.swift
//  PlayCoverManager
//
//  IPA installation service
//  Handles IPA file parsing, volume creation, PlayCover integration, and installation monitoring
//

import Foundation
import AppKit
import Observation
import CoreServices

@MainActor
@Observable
class IPAInstallerService {
    let processRunner: ProcessRunner
    let diskImageService: DiskImageService
    let settingsStore: SettingsStore
    let launcherService: LauncherService
    
    // Installation state
    var isInstalling = false
    var currentProgress: Double = 0.0
    var currentStatus: String = ""
    var currentAppName: String = ""  // Currently installing app name
    var currentAppIcon: NSImage? = nil  // Currently installing app icon
    var installedApps: [String] = []
    var installedAppDetails: [InstalledAppDetail] = []  // Detailed info for results screen
    var failedApps: [String] = []
    var retryCount: Int = 0  // Current retry attempt
    var maxRetries: Int = 3  // Maximum number of retries for PlayCover crashes
    
    // Result detail for installed apps (with icon from .app bundle)
    struct InstalledAppDetail: Identifiable {
        let id = UUID()
        let appName: String
        let bundleID: String
        let icon: NSImage?
    }
    
    init(processRunner: ProcessRunner? = nil,
         diskImageService: DiskImageService,
         settingsStore: SettingsStore,
         launcherService: LauncherService) {
        self.processRunner = processRunner ?? ProcessRunner()
        self.diskImageService = diskImageService
        self.settingsStore = settingsStore
        self.launcherService = launcherService
    }
    
    // MARK: - IPA Information Extraction
    
    struct IPAInfo: Identifiable, Sendable {
        let id: UUID
        let ipaURL: URL
        let bundleID: String
        let appName: String
        let appNameEnglish: String
        let version: String
        let icon: NSImage?
        let fileSize: Int64
        let existingVersion: String?
        let installType: InstallType
        
        nonisolated enum InstallType: Sendable, Equatable {
            case newInstall
            case upgrade
            case downgrade
            case reinstall
        }
        
        // Volume name is always Bundle ID
        nonisolated var volumeName: String { bundleID }
        
        var installTypeDescription: String {
            switch installType {
            case .newInstall: return String(localized: "新規インストール")
            case .upgrade: return String(localized: "アップグレード")
            case .downgrade: return String(localized: "ダウングレード")
            case .reinstall: return String(localized: "上書き")
            }
        }
        
        nonisolated init(id: UUID = UUID(), ipaURL: URL, bundleID: String, appName: String, appNameEnglish: String, version: String, icon: NSImage?, fileSize: Int64, existingVersion: String? = nil, installType: InstallType = .newInstall) {
            self.id = id
            self.ipaURL = ipaURL
            self.bundleID = bundleID
            self.appName = appName
            self.appNameEnglish = appNameEnglish
            self.version = version
            self.icon = icon
            self.fileSize = fileSize
            self.existingVersion = existingVersion
            self.installType = installType
        }
    }
    
    nonisolated func extractIPAInfo(from ipaURL: URL) async throws -> IPAInfo {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Get app's configured language (respects user's language setting in app)
        let appLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
        let primaryLanguage = appLanguages.first ?? Locale.preferredLanguages.first ?? "en"
        
        // Extract Info.plist and localized strings using wildcards (FAST - no listing needed)
        // Use wildcards to extract: Payload/*.app/Info.plist, en.lproj (fallback), system language .lproj, and app icon
        var extractPatterns = [
            "Payload/*.app/Info.plist",
            "Payload/*.app/en.lproj/InfoPlist.strings",  // English fallback
            "Payload/*.app/AppIcon60x60@2x.png",  // Most common iOS app icon
            "Payload/*.app/AppIcon76x76@2x~ipad.png"  // iPad icon
        ]
        
        // Add patterns for configured language (try both full code and base code)
        if primaryLanguage != "en" {
            // Try full language code first (e.g., zh-Hans)
            extractPatterns.append("Payload/*.app/\(primaryLanguage).lproj/InfoPlist.strings")
            // Also try base code (e.g., zh)
            let baseLanguageCode = String(primaryLanguage.prefix(2))
            if baseLanguageCode != primaryLanguage {
                extractPatterns.append("Payload/*.app/\(baseLanguageCode).lproj/InfoPlist.strings")
            }
        }
        
        // Extract with wildcards - unzip handles pattern matching internally (much faster)
        // Note: Without -j to preserve directory structure for multiple InfoPlist.strings files
        _ = try? await processRunner.run("/usr/bin/unzip", ["-q", ipaURL.path] + extractPatterns + ["-d", tempDir.path])
        
        // Find the .app directory
        let payloadURL = tempDir.appendingPathComponent("Payload")
        guard let appURL = try? FileManager.default.contentsOfDirectory(at: payloadURL, includingPropertiesForKeys: nil).first(where: { $0.pathExtension == "app" }) else {
            throw AppError.installation(String(localized: "IPA 内に .app が見つかりません"), message: "")
        }
        
        let infoPlistURL = appURL.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw AppError.installation(String(localized: "IPA 内に Info.plist が見つかりません"), message: "")
        }
        
        // Read plist data
        guard let plist = infoPlistURL.readPlist() else {
            throw AppError.installation(String(localized: "Info.plist の読み取りに失敗しました"), message: "")
        }
        
        // Extract Bundle ID
        guard let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw AppError.installation(String(localized: "Bundle Identifier の取得に失敗しました"), message: "")
        }
        
        // Extract version
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "Unknown"
        
        // Get Info.plist default name (used as final fallback)
        let infoPlistDefaultName = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? ""
        guard !infoPlistDefaultName.isEmpty else {
            throw AppError.installation(String(localized: "アプリ名の取得に失敗しました"), message: "")
        }
        
        // Try to get English app name (from en.lproj) for middle fallback
        var appNameEnglish = ""
        let enLprojURL = appURL.appendingPathComponent("en.lproj/InfoPlist.strings")
        if FileManager.default.fileExists(atPath: enLprojURL.path),
           let stringsData = try? Data(contentsOf: enLprojURL),
           let stringsDict = stringsData.parsePlist() as? [String: String] {
            appNameEnglish = stringsDict["CFBundleDisplayName"] ?? stringsDict["CFBundleName"] ?? ""
        }
        
        // Fallback: English name or Info.plist default
        if appNameEnglish.isEmpty {
            appNameEnglish = infoPlistDefaultName
        }
        
        // Try to extract localized app name for configured language
        var appName = ""
        
        // Try configured language first (try both full code and base code)
        if primaryLanguage != "en" {
            // Try full language code first (e.g., zh-Hans.lproj)
            var langStringsURL = appURL.appendingPathComponent("\(primaryLanguage).lproj/InfoPlist.strings")
            if FileManager.default.fileExists(atPath: langStringsURL.path),
               let stringsData = try? Data(contentsOf: langStringsURL),
               let stringsDict = stringsData.parsePlist() as? [String: String] {
                appName = stringsDict["CFBundleDisplayName"] ?? stringsDict["CFBundleName"] ?? ""
            }
            
            // If not found, try base language code (e.g., zh.lproj)
            if appName.isEmpty {
                let baseLanguageCode = String(primaryLanguage.prefix(2))
                langStringsURL = appURL.appendingPathComponent("\(baseLanguageCode).lproj/InfoPlist.strings")
                if FileManager.default.fileExists(atPath: langStringsURL.path),
                   let stringsData = try? Data(contentsOf: langStringsURL),
                   let stringsDict = stringsData.parsePlist() as? [String: String] {
                    appName = stringsDict["CFBundleDisplayName"] ?? stringsDict["CFBundleName"] ?? ""
                }
            }
        }
        
        // Middle fallback to English if configured language not found
        if appName.isEmpty && primaryLanguage != "en" {
            appName = appNameEnglish
        }
        
        // Final fallback to Info.plist default if no English either
        if appName.isEmpty {
            appName = infoPlistDefaultName
        }
        
        // Try to load extracted icon
        var icon: NSImage? = nil
        let possibleIconNames = ["AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png"]
        for iconName in possibleIconNames {
            let iconURL = appURL.appendingPathComponent(iconName)
            if FileManager.default.fileExists(atPath: iconURL.path),
               let imageData = try? Data(contentsOf: iconURL) {
                icon = NSImage(data: imageData)
                break
            }
        }
        
        // Get file size
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: ipaURL.path)[.size] as? Int64) ?? 0
        
        // Check if app already installed and get existing version
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        var existingVersion: String? = nil
        var installType: IPAInfo.InstallType = .newInstall
        
        if let appDirs = try? FileManager.default.contentsOfDirectory(at: applicationsDir, includingPropertiesForKeys: nil) {
            for appURL in appDirs where appURL.pathExtension == "app" {
                let appInfoPlist = appURL.appendingPathComponent("Info.plist")
                if FileManager.default.fileExists(atPath: appInfoPlist.path),
                   let appPlistData = try? Data(contentsOf: appInfoPlist),
                   let appPlist = appPlistData.parsePlist(),
                   let installedBundleID = appPlist["CFBundleIdentifier"] as? String,
                   installedBundleID == bundleID {
                    // Found existing installation
                    existingVersion = (appPlist["CFBundleShortVersionString"] as? String) ?? (appPlist["CFBundleVersion"] as? String)
                    
                    if let existing = existingVersion {
                        if version == existing {
                            installType = .reinstall
                        } else if version.compare(existing, options: .numeric) == .orderedDescending {
                            installType = .upgrade
                        } else {
                            installType = .downgrade
                        }
                    }
                    break
                }
            }
        }
        
        return IPAInfo(
            ipaURL: ipaURL,
            bundleID: bundleID,
            appName: appName,
            appNameEnglish: appNameEnglish,
            version: version,
            icon: icon,
            fileSize: fileSize,
            existingVersion: existingVersion,
            installType: installType
        )
    }
    
    // MARK: - Volume Creation and Mounting
    
    nonisolated func createAppDiskImage(info: IPAInfo) async throws -> URL {
        Logger.installation("Creating disk image for \(info.bundleID)")
        await MainActor.run {
            currentStatus = String(localized: "ディスクイメージ作成中")
        }
        
        guard let diskImageDir = await settingsStore.diskImageDirectory else {
            Logger.error("Disk image directory not set")
            throw AppError.diskImage(String(localized: "ディスクイメージの保存先が未設定"), message: "設定画面から保存先を指定してください。")
        }
        
        let imageName = "\(info.volumeName).asif"
        let imageURL = diskImageDir.appendingPathComponent(imageName)
        Logger.debug("Disk image path: \(imageURL.path)")
        
        // Check if image already exists
        if FileManager.default.fileExists(atPath: imageURL.path) {
            Logger.installation("Disk image already exists, reusing")
            await MainActor.run {
                currentStatus = String(localized: "既存のディスクイメージを使用")
            }
            return imageURL
        }
        
        // Create ASIF disk image (uses default size from settings)
        try await Logger.measureAsync("Create disk image for installation") {
            try await diskImageService.createDiskImage(
                at: imageURL,
                volumeName: info.volumeName
            )
        }
        Logger.installation("Successfully created disk image")
        
        await MainActor.run {
            currentStatus = String(localized: "作成完了")
        }
        return imageURL
    }
    
    nonisolated func mountAppDiskImage(imageURL: URL, bundleID: String) async throws -> URL {
        await MainActor.run {
            currentStatus = String(localized: "マウント中")
        }
        
        let mountPoint = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(bundleID, isDirectory: true)
        
        // Check if already mounted at correct location
        if FileManager.default.fileExists(atPath: mountPoint.path),
           let attributes = try? FileManager.default.attributesOfItem(atPath: mountPoint.path),
           attributes[.type] as? FileAttributeType == .typeDirectory {
            // Verify it's actually mounted
            let mountOutput = try await processRunner.run("/sbin/mount", [])
            if mountOutput.contains(mountPoint.path) {
                await MainActor.run {
                    currentStatus = String(localized: "既にマウント済み")
                }
                return mountPoint
            }
        }
        
        // Mount with nobrowse option
        try await diskImageService.mountDiskImage(imageURL, at: mountPoint, nobrowse: true)
        
        await MainActor.run {
            currentStatus = String(localized: "マウント完了")
        }
        return mountPoint
    }
    
    // MARK: - PlayCover Integration
    
    nonisolated func installIPAToPlayCover(_ ipaURL: URL, info: IPAInfo) async throws {
        await MainActor.run {
            currentStatus = String(localized: "PlayCover でインストール中")
        }
        
        // Retry loop for PlayCover crashes
        var shouldRetry = true
        while shouldRetry {
            // Open IPA with PlayCover
            let openTask = Process()
            openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            openTask.arguments = ["-a", "PlayCover", ipaURL.path]
            
            try openTask.run()
            openTask.waitUntilExit()
            
            guard openTask.terminationStatus == 0 else {
                throw AppError.installation(String(localized: "PlayCover の起動に失敗しました"), message: "")
            }
            
            // Monitor installation progress
            do {
                try await monitorInstallationProgress(bundleID: info.bundleID, appName: info.appName)
                shouldRetry = false  // Success - exit retry loop
            } catch let error as AppError {
                if error.category == .installationRetry {
                    // Automatic retry triggered by crash detection
                    shouldRetry = true
                    continue
                } else {
                    // Other errors - propagate
                    throw error
                }
            } catch {
                // Unknown errors - propagate
                throw error
            }
        }
    }
    
    // MARK: - Installation Progress Monitoring
    
    // Monitor installation completion by watching Applications directory
    // Simplified process: Wait for PlayCover to start → Wait for .app creation/update → Wait for valid signature → Complete
    private nonisolated func monitorInstallationProgress(bundleID: String, appName: String) async throws {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        // Step 0: Wait for PlayCover to start (確実に起動を検知してからトリガー)
        await MainActor.run { currentStatus = String(localized: "PlayCoverの起動を待機中...") }
        Logger.installation("Waiting for PlayCover to start")
        
        let startupTimeout = 30 // 30 seconds to start
        var playCoverStarted = false
        
        for _ in 0..<startupTimeout {
            let isRunning = await MainActor.run {
                NSWorkspace.shared.runningApplications.contains { app in
                    app.bundleIdentifier == playCoverBundleID
                }
            }
            
            if isRunning {
                playCoverStarted = true
                Logger.installation("PlayCover started successfully")
                break
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
        
        guard playCoverStarted else {
            throw AppError.installation(String(localized: "PlayCover の起動に失敗しました"), message: "30秒以内に起動しませんでした")
        }
        
        // PlayCover起動確認後、初期状態を取得
        await MainActor.run { currentStatus = String(localized: "PlayCoverでIPAをインストール中") }
        let targetAppURL = getAppURL(for: bundleID, in: applicationsDir)
        let initialMTime = targetAppURL.flatMap { getAppModificationTime($0) } ?? 0
        
        let maxWait = 300 // 5 minutes
        let checkInterval: TimeInterval = 1.0
        var appDetected = false
        
        for i in 0..<maxWait {
            // Check if PlayCover is still running
            let playCoverRunning = await MainActor.run {
                NSWorkspace.shared.runningApplications.contains { app in
                    app.bundleIdentifier == playCoverBundleID
                }
            }
            
            // If PlayCover crashed, retry installation
            if !playCoverRunning {
                Logger.installation("PlayCover terminated unexpectedly")
                
                // Check if installation completed before crash
                // Only check if app was detected (to avoid false positive with existing app)
                if appDetected {
                    if try await isInstallationComplete(bundleID: bundleID) {
                        await MainActor.run {
                            currentStatus = String(localized: "完了")
                            retryCount = 0
                        }
                        Logger.installation("Installation completed before PlayCover termination")
                        return
                    }
                }
                
                // Installation incomplete - retry
                let currentRetry = await MainActor.run { retryCount }
                let maxRetries = await MainActor.run { self.maxRetries }
                
                if currentRetry < maxRetries {
                    await MainActor.run {
                        retryCount += 1
                        currentStatus = String(localized: "PlayCoverがクラッシュしました - 再試行中 (\(retryCount)/\(maxRetries))")
                    }
                    Logger.installation("Retrying installation (\(currentRetry + 1)/\(maxRetries))")
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    throw AppError.installationRetry
                } else {
                    await MainActor.run { retryCount = 0 }
                    throw AppError.installation(String(localized: "PlayCover が終了しました"), message: "\(maxRetries)回の再試行後もインストールが完了しませんでした")
                }
            }
            
            // Step 1: Wait for .app creation or modification
            if !appDetected {
                if let appURL = getAppURL(for: bundleID, in: applicationsDir) {
                    let currentMTime = getAppModificationTime(appURL) ?? 0
                    if currentMTime > initialMTime {
                        appDetected = true
                        await MainActor.run { currentStatus = String(localized: "アプリ検出 - 署名完了を待機中...") }
                        Logger.installation("App detected: \(appURL.path), waiting for signature")
                    }
                }
            }
            
            // Step 2: Once app detected, wait for valid signature
            if appDetected {
                if try await isInstallationComplete(bundleID: bundleID) {
                    await MainActor.run {
                        currentStatus = String(localized: "完了")
                        retryCount = 0
                    }
                    Logger.installation("Installation complete with valid signature")
                    
                    // Terminate PlayCover gracefully
                    await terminatePlayCover()
                    return
                }
            }
            
            // Update status every 5 seconds
            if i % 5 == 0 && i > 0 {
                await MainActor.run { currentStatus = String(localized: "PlayCoverでIPAをインストール中 (\(i)秒経過)") }
            }
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        throw AppError.installation(String(localized: "タイムアウト"), message: "5分以内に完了しませんでした")
    }
    
    /// Get app URL for specific bundle ID
    private nonisolated func getAppURL(for bundleID: String, in directory: URL) -> URL? {
        guard let appDirs = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return nil
        }
        
        for appURL in appDirs where appURL.pathExtension == "app" {
            let infoPlist = appURL.appendingPathComponent("Info.plist")
            guard let plistData = try? Data(contentsOf: infoPlist),
                  let plist = plistData.parsePlist(),
                  let installedBundleID = plist["CFBundleIdentifier"] as? String,
                  installedBundleID == bundleID else {
                continue
            }
            return appURL
        }
        
        return nil
    }
    
    /// Get modification time for app
    private nonisolated func getAppModificationTime(_ appURL: URL) -> TimeInterval? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: appURL.path),
              let modDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return modDate.timeIntervalSince1970
    }
    
    
    // MARK: - Installation Verification
    
    /// Check if installation is complete (app exists with valid signature)
    private nonisolated func isInstallationComplete(bundleID: String) async throws -> Bool {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        // Find app by bundle ID
        guard let appURL = getAppURL(for: bundleID, in: applicationsDir) else {
            return false
        }
        
        // Verify code signature is valid (this is the key check)
        return try await verifyCodeSignature(appPath: appURL.path)
    }
    
    /// Verify that app's code signature is valid and complete using codesign
    private func verifyCodeSignature(appPath: String) async throws -> Bool {
        do {
            // Use codesign -v to verify signature
            // Exit code 0 means signature is valid
            _ = try await processRunner.run("/usr/bin/codesign", ["-v", appPath])
            
            // codesign -v returns empty output on success, error message on failure
            // If it completes without throwing, signature is valid
            Logger.installation("Code signature verification passed for: \(appPath)")
            return true
        } catch {
            // Signature is incomplete or invalid
            Logger.installation("Code signature verification failed for: \(appPath) - \(error)")
            return false
        }
    }
    
    /// Terminate PlayCover gracefully with SIGTERM
    private nonisolated func terminatePlayCover() async {
        let playCoverBundleID = "io.playcover.PlayCover"
        
        // Find PlayCover process
        let runningApps = await MainActor.run {
            NSWorkspace.shared.runningApplications
        }
        
        guard let playCoverApp = runningApps.first(where: { $0.bundleIdentifier == playCoverBundleID }) else {
            Logger.installation("PlayCover not running, cannot terminate")
            return
        }
        
        Logger.installation("Sending SIGTERM to PlayCover (PID: \(playCoverApp.processIdentifier))")
        let success = playCoverApp.terminate()
        Logger.installation("SIGTERM result: \(success)")
    }
    
    
    // MARK: - Batch IPA Analysis
    
    func analyzeIPAs(_ ipaURLs: [URL]) async -> [IPAInfo] {
        var results: [IPAInfo] = []
        
        for ipaURL in ipaURLs {
            await MainActor.run {
                currentStatus = String(localized: "解析中: \(ipaURL.lastPathComponent)")
            }
            
            do {
                let info = try await extractIPAInfo(from: ipaURL)
                results.append(info)
            } catch {
                // Skip failed analysis
                await MainActor.run {
                    failedApps.append(String(localized: "\(ipaURL.lastPathComponent): 解析失敗 - \(error.localizedDescription)"))
                }
            }
        }
        
        return results
    }
    
    // MARK: - Single IPA Installation
    
    enum InstallationError: Error, LocalizedError {
        case diskImageCreationFailed(String)
        case mountFailed(String)
        case playCoverInstallFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .diskImageCreationFailed(let msg): return "ディスクイメージ作成エラー: \(msg)"
            case .mountFailed(let msg): return "マウントエラー: \(msg)"
            case .playCoverInstallFailed(let msg): return "インストールエラー: \(msg)"
            }
        }
    }
    
    nonisolated func installSingleIPA(_ info: IPAInfo) async throws {
        await MainActor.run {
            currentAppName = info.appName
            currentAppIcon = info.icon
            currentStatus = String(localized: "\(info.appName) をインストール中")
        }
        
        // Check if app is running (for upgrade/reinstall cases)
        if info.installType != .newInstall {
            await MainActor.run {
                currentStatus = String(localized: "アプリの実行状態を確認中")
            }
            let isRunning = await MainActor.run { launcherService.isAppRunning(bundleID: info.bundleID) }
            if isRunning {
                throw AppError.installation(String(localized: "アプリが実行中のため、インストールできません"), message: "アプリを終了してから再度お試しください")
            }
        }
        
        // Step 1: Create disk image
        await MainActor.run {
            currentStatus = String(localized: "ディスクイメージ作成中")
        }
        do {
            _ = try await createAppDiskImage(info: info)
        } catch {
            throw InstallationError.diskImageCreationFailed(error.localizedDescription)
        }
        
        // Step 2: Mount disk image
        await MainActor.run {
            currentStatus = String(localized: "マウント中")
        }
        guard let diskImageDir = await settingsStore.diskImageDirectory else {
            throw AppError.diskImage(String(localized: "ディスクイメージの保存先が未設定"), message: "")
        }
        let imageURL = diskImageDir.appendingPathComponent("\(info.bundleID).asif")
        
        do {
            _ = try await mountAppDiskImage(imageURL: imageURL, bundleID: info.bundleID)
        } catch {
            throw InstallationError.mountFailed(error.localizedDescription)
        }
        
        // Step 3: Install via PlayCover
        await MainActor.run {
            currentStatus = String(localized: "インストール中")
        }
        do {
            try await installIPAToPlayCover(info.ipaURL, info: info)
        } catch {
            throw InstallationError.playCoverInstallFailed(error.localizedDescription)
        }
        
        // Step 4: Eject disk image after installation completes
        // Installation is complete and app is not running, so explicitly eject drive
        await MainActor.run {
            currentStatus = String(localized: "ドライブをイジェクト中")
        }
        
        let mountPoint = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers", isDirectory: true)
            .appendingPathComponent(info.bundleID, isDirectory: true)
        
        do {
            try await diskImageService.ejectDiskImage(for: mountPoint, force: false)
            await MainActor.run {
                currentStatus = String(localized: "イジェクト完了")
            }
        } catch {
            // Log error but don't fail installation - eject failure is not critical
            Logger.error("Failed to eject after installation: \(error.localizedDescription)")
            await MainActor.run {
                currentStatus = String(localized: "完了（イジェクト失敗）")
            }
        }
        
        // Step 5: Remove PlayCover shortcut (if exists)
        await removePlayCoverShortcut(for: info)
        
        await MainActor.run {
            currentStatus = String(localized: "完了")
        }
    }
    
    // MARK: - Batch Installation Workflow
    
    func installIPAs(_ ipasInfo: [IPAInfo]) async throws {
        await MainActor.run {
            isInstalling = true
            installedApps.removeAll()
            installedAppDetails.removeAll()
            failedApps.removeAll()
            currentProgress = 0.0
            currentAppName = ""
            currentAppIcon = nil
        }
        
        defer {
            Task { @MainActor in
                isInstalling = false
            }
        }
        
        let totalIPAs = ipasInfo.count
        
        for (index, info) in ipasInfo.enumerated() {
            await MainActor.run {
                currentProgress = Double(index) / Double(totalIPAs)
                currentStatus = "[\(index + 1)/\(totalIPAs)] \(info.appName)"
            }
            
            do {
                try await installSingleIPA(info)
                await MainActor.run {
                    installedApps.append(info.appName)
                }
                
                // Get installed app details (with icon from .app bundle)
                if let detail = await getInstalledAppDetail(bundleID: info.bundleID, appName: info.appName) {
                    await MainActor.run {
                        installedAppDetails.append(detail)
                    }
                } else {
                }
            } catch {
                await MainActor.run {
                    failedApps.append("\(info.appName): \(error.localizedDescription)")
                }
            }
        }
        
        await MainActor.run {
            currentProgress = 1.0
            currentStatus = String(localized: "完了")
            currentAppName = ""  // Clear current app name after all installations complete
            currentAppIcon = nil  // Clear current app icon
            
        }
    }
    
    // MARK: - PlayCover Shortcut Cleanup
    
    /// Remove PlayCover-created shortcut in ~/Applications/PlayCover/
    /// PlayCover creates these shortcuts but they're useless without PlayCoverManager running
    private nonisolated func removePlayCoverShortcut(for info: IPAInfo) async {
        let playCoverAppsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Applications/PlayCover", isDirectory: true)
        
        // Try both English and localized app names
        let possibleShortcutNames = [
            info.appNameEnglish,
            info.appName
        ].filter { !$0.isEmpty }
        
        for appName in possibleShortcutNames {
            let shortcutPath = playCoverAppsDir.appendingPathComponent("\(appName).app")
            
            if FileManager.default.fileExists(atPath: shortcutPath.path) {
                do {
                    try FileManager.default.removeItem(at: shortcutPath)
                    Logger.installation("Removed PlayCover shortcut: \(shortcutPath.path)")
                } catch {
                    Logger.error("Failed to remove PlayCover shortcut at \(shortcutPath.path): \(error)")
                }
            }
        }
    }
    
    // MARK: - Get Installed App Details
    
    // Get app details from installed .app bundle (with icon cache)
    private nonisolated func getInstalledAppDetail(bundleID: String, appName: String) async -> InstalledAppDetail? {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        
        guard let appDirs = try? FileManager.default.contentsOfDirectory(
            at: applicationsDir,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        
        
        for appURL in appDirs where appURL.pathExtension == "app" {
            let infoPlist = appURL.appendingPathComponent("Info.plist")
            guard FileManager.default.fileExists(atPath: infoPlist.path),
                  let plistData = try? Data(contentsOf: infoPlist),
                  let plist = plistData.parsePlist(),
                  let installedBundleID = plist["CFBundleIdentifier"] as? String,
                  installedBundleID == bundleID else {
                continue
            }
            
            
            // Found the app - get icon using helper (512x512 for better quality)
            let icon = await MainActor.run {
                AppIconHelper.loadAppIcon(from: appURL)
            }
            
            
            return InstalledAppDetail(
                appName: appName,
                bundleID: bundleID,
                icon: icon
            )
        }
        
        return nil
    }
}
