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
            case .newInstall: return "新規インストール"
            case .upgrade: return "アップグレード"
            case .downgrade: return "ダウングレード"
            case .reinstall: return "上書き"
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
        
        // Get system language for localization
        let preferredLanguages = Locale.preferredLanguages
        let systemLanguage = preferredLanguages.first?.split(separator: "-").first.map(String.init) ?? "en"
        
        // Extract Info.plist and localized strings using wildcards (FAST - no listing needed)
        // Use wildcards to extract: Payload/*.app/Info.plist, ja.lproj, system language .lproj, and app icon
        var extractPatterns = [
            "Payload/*.app/Info.plist",
            "Payload/*.app/ja.lproj/InfoPlist.strings",
            "Payload/*.app/AppIcon60x60@2x.png",  // Most common iOS app icon
            "Payload/*.app/AppIcon76x76@2x~ipad.png"  // iPad icon
        ]
        if systemLanguage != "en" && systemLanguage != "ja" {
            extractPatterns.append("Payload/*.app/\(systemLanguage).lproj/InfoPlist.strings")
        }
        
        // Extract with wildcards - unzip handles pattern matching internally (much faster)
        // -j flag flattens directory structure, so files are extracted directly to tempDir
        _ = try? await processRunner.run("/usr/bin/unzip", ["-q", "-j", ipaURL.path] + extractPatterns + ["-d", tempDir.path])
        
        // Info.plist is now directly in tempDir (flattened with -j)
        let infoPlistURL = tempDir.appendingPathComponent("Info.plist")
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw AppError.installation("IPA 内に Info.plist が見つかりません", message: "")
        }
        
        // Read plist data
        let plistData = try Data(contentsOf: infoPlistURL)
        guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw AppError.installation("Info.plist の読み取りに失敗しました", message: "")
        }
        
        // Extract Bundle ID
        guard let bundleID = plist["CFBundleIdentifier"] as? String else {
            throw AppError.installation("Bundle Identifier の取得に失敗しました", message: "")
        }
        
        // Extract version
        let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "Unknown"
        
        // Extract app name (English)
        var appNameEnglish = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String)
        guard let appNameEn = appNameEnglish else {
            throw AppError.installation("アプリ名の取得に失敗しました", message: "")
        }
        appNameEnglish = appNameEn
        
        // Try to extract localized app name (system language first, then Japanese fallback)
        var appName: String = appNameEn
        
        // Try system language first (if not en)
        if systemLanguage != "en" {
            let langStringsURL = tempDir.appendingPathComponent("InfoPlist.strings")
            if FileManager.default.fileExists(atPath: langStringsURL.path),
               let stringsData = try? Data(contentsOf: langStringsURL),
               let stringsDict = try? PropertyListSerialization.propertyList(from: stringsData, format: nil) as? [String: String] {
                if let displayName = stringsDict["CFBundleDisplayName"], !displayName.isEmpty {
                    appName = displayName
                } else if let bundleName = stringsDict["CFBundleName"], !bundleName.isEmpty {
                    appName = bundleName
                }
            }
        }
        
        // If system language didn't work, appName stays as English (appNameEn)
        // No fallback to Japanese - English is the universal fallback
        
        // Try to load extracted icon (already extracted with Info.plist in one command)
        var icon: NSImage? = nil
        let possibleIconNames = ["AppIcon60x60@2x.png", "AppIcon76x76@2x~ipad.png"]
        for iconName in possibleIconNames {
            let iconURL = tempDir.appendingPathComponent(iconName)
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
                   let appPlist = try? PropertyListSerialization.propertyList(from: appPlistData, format: nil) as? [String: Any],
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
            appNameEnglish: appNameEn,
            version: version,
            icon: icon,
            fileSize: fileSize,
            existingVersion: existingVersion,
            installType: installType
        )
    }
    
    // MARK: - Volume Creation and Mounting
    
    nonisolated func createAppDiskImage(info: IPAInfo) async throws -> URL {
        await MainActor.run {
            currentStatus = "ディスクイメージ作成中"
        }
        
        guard let diskImageDir = await settingsStore.diskImageDirectory else {
            throw AppError.diskImage("ディスクイメージの保存先が未設定", message: "設定画面から保存先を指定してください。")
        }
        
        let imageName = "\(info.volumeName).asif"
        let imageURL = diskImageDir.appendingPathComponent(imageName)
        
        // Check if image already exists
        if FileManager.default.fileExists(atPath: imageURL.path) {
            await MainActor.run {
                currentStatus = "既存のディスクイメージを使用"
            }
            return imageURL
        }
        
        // Create ASIF disk image
        try await diskImageService.createDiskImage(
            at: imageURL,
            volumeName: info.volumeName,
            size: "50G"
        )
        
        await MainActor.run {
            currentStatus = "作成完了"
        }
        return imageURL
    }
    
    nonisolated func mountAppDiskImage(imageURL: URL, bundleID: String) async throws -> URL {
        await MainActor.run {
            currentStatus = "マウント中"
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
                    currentStatus = "既にマウント済み"
                }
                return mountPoint
            }
        }
        
        // Mount with nobrowse option
        try await diskImageService.mountDiskImage(imageURL, at: mountPoint, nobrowse: true)
        
        await MainActor.run {
            currentStatus = "マウント完了"
        }
        return mountPoint
    }
    
    // MARK: - PlayCover Integration
    
    nonisolated func installIPAToPlayCover(_ ipaURL: URL, info: IPAInfo) async throws {
        await MainActor.run {
            currentStatus = "PlayCover でインストール中"
        }
        
        // Open IPA with PlayCover
        let openTask = Process()
        openTask.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        openTask.arguments = ["-a", "PlayCover", ipaURL.path]
        
        try openTask.run()
        openTask.waitUntilExit()
        
        guard openTask.terminationStatus == 0 else {
            throw AppError.installation("PlayCover の起動に失敗しました", message: "")
        }
        
        // Monitor installation progress
        try await monitorInstallationProgress(bundleID: info.bundleID, appName: info.appName)
    }
    
    // MARK: - Installation Progress Monitoring
    
    // Monitor installation completion by watching Applications directory
    private nonisolated func monitorInstallationProgress(bundleID: String, appName: String) async throws {
        await MainActor.run { currentStatus = "PlayCoverでIPAをインストール中" }
        
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        // Record initial app count and app modification times
        let initialAppURLs = getAppURLs(in: applicationsDir)
        let initialAppMTimes = getAppModificationTimes(initialAppURLs)
        
        await MainActor.run { currentStatus = "PlayCoverでIPAをインストール中" }
        
        let maxWait = 300 // 5 minutes
        let checkInterval: TimeInterval = 1.0
        
        for i in 0..<maxWait {
            // Check if PlayCover is still running using both pgrep and NSWorkspace
            let pgrepOutput = try? await processRunner.run("/usr/bin/pgrep", ["-x", "PlayCover"])
            
            // Also check via NSWorkspace (more reliable)
            let runningApps = await MainActor.run {
                NSWorkspace.shared.runningApplications
            }
            let playCoverRunning = runningApps.contains { app in
                app.bundleIdentifier == "io.playcover.PlayCover"
            }
            
            // Debug logging
            if i % 10 == 0 {
            }
            
            // Check both nil case and empty string case
            let isPlayCoverRunning: Bool
            if let output = pgrepOutput {
                // pgrep returns process IDs (one per line), or empty if not running
                let pgrepSaysRunning = !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                // Use NSWorkspace as primary check, pgrep as backup
                isPlayCoverRunning = playCoverRunning || pgrepSaysRunning
            } else {
                // Command failed - rely on NSWorkspace
                isPlayCoverRunning = playCoverRunning
            }
            
            if !isPlayCoverRunning {
                // PlayCover crashed or closed - verify installation
                await MainActor.run { currentStatus = "PlayCover終了検知 - 検証中..." }
                try await Task.sleep(nanoseconds: 1_000_000_000)
                
                if try await verifyInstallationComplete(bundleID: bundleID) {
                    await MainActor.run { currentStatus = "完了（PlayCover終了後）" }
                    return
                } else {
                    throw AppError.installation("PlayCover が終了しました", message: "インストールが完了していません")
                }
            }
            
            // Check for new or modified apps
            let currentAppURLs = getAppURLs(in: applicationsDir)
            let currentAppMTimes = getAppModificationTimes(currentAppURLs)
            
            // Look for our specific app by bundle ID
            for appURL in currentAppURLs {
                let infoPlist = appURL.appendingPathComponent("Info.plist")
                guard FileManager.default.fileExists(atPath: infoPlist.path),
                      let plistData = try? Data(contentsOf: infoPlist),
                      let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                      let installedBundleID = plist["CFBundleIdentifier"] as? String else {
                    continue
                }
                
                if installedBundleID == bundleID {
                    let currentMTime = currentAppMTimes[appURL.path] ?? 0
                    let initialMTime = initialAppMTimes[appURL.path] ?? 0
                    
                    // App was created or updated
                    if currentMTime > initialMTime {
                        // Verify _CodeSignature exists (installation complete)
                        let codeSignatureDir = appURL.appendingPathComponent("_CodeSignature")
                        if FileManager.default.fileExists(atPath: codeSignatureDir.path) {
                            await MainActor.run { currentStatus = "完了検知 - 最終確認中..." }
                            
                            // Wait for stability
                            try await Task.sleep(nanoseconds: 2_000_000_000)
                            
                            // Re-verify
                            if try await verifyInstallationComplete(bundleID: bundleID) {
                                await MainActor.run { currentStatus = "完了" }
                                
                                // Don't quit PlayCover - let user close it manually
                                // Automatically quitting can cause incomplete installations
                                return
                            }
                        }
                    }
                }
            }
            
            // Update status every 5 seconds
            if i % 5 == 0 {
                await MainActor.run { currentStatus = "PlayCoverでIPAをインストール中 (\(i)秒経過)" }
            }
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
        }
        
        throw AppError.installation("タイムアウト", message: "5分以内に完了しませんでした")
    }
    
    // Get all app URLs in directory
    private nonisolated func getAppURLs(in directory: URL) -> [URL] {
        guard let appDirs = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        ) else {
            return []
        }
        
        return appDirs.filter { $0.pathExtension == "app" }
    }
    
    // Get modification times for all apps
    private nonisolated func getAppModificationTimes(_ appURLs: [URL]) -> [String: TimeInterval] {
        var mtimes: [String: TimeInterval] = [:]
        
        for appURL in appURLs {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: appURL.path),
               let modDate = attributes[.modificationDate] as? Date {
                mtimes[appURL.path] = modDate.timeIntervalSince1970
            }
        }
        
        return mtimes
    }
    
    
    // MARK: - Installation Verification
    
    private func verifyInstallationComplete(bundleID: String) async throws -> Bool {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        let appSettingsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/App Settings", isDirectory: true)
        let settingsFile = appSettingsDir.appendingPathComponent("\(bundleID).plist")
        
        // Settings file must exist
        guard FileManager.default.fileExists(atPath: settingsFile.path) else {
            return false
        }
        
        guard let appDirs = try? FileManager.default.contentsOfDirectory(
            at: applicationsDir,
            includingPropertiesForKeys: nil
        ) else {
            return false
        }
        
        for appURL in appDirs where appURL.pathExtension == "app" {
            let infoPlist = appURL.appendingPathComponent("Info.plist")
            guard FileManager.default.fileExists(atPath: infoPlist.path) else { continue }
            
            let plistData = try Data(contentsOf: infoPlist)
            guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                  let installedBundleID = plist["CFBundleIdentifier"] as? String else {
                continue
            }
            
            if installedBundleID == bundleID {
                // Verify structure integrity: both _CodeSignature and settings file must exist
                let codeSignatureDir = appURL.appendingPathComponent("_CodeSignature")
                if FileManager.default.fileExists(atPath: codeSignatureDir.path) {
                    return true
                }
            }
        }
        
        return false
    }
    
    
    // MARK: - Batch IPA Analysis
    
    func analyzeIPAs(_ ipaURLs: [URL]) async -> [IPAInfo] {
        var results: [IPAInfo] = []
        
        for ipaURL in ipaURLs {
            await MainActor.run {
                currentStatus = "解析中: \(ipaURL.lastPathComponent)"
            }
            
            do {
                let info = try await extractIPAInfo(from: ipaURL)
                results.append(info)
            } catch {
                // Skip failed analysis
                await MainActor.run {
                    failedApps.append("\(ipaURL.lastPathComponent): 解析失敗 - \(error.localizedDescription)")
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
            currentStatus = "\(info.appName) をインストール中"
        }
        
        // Check if app is running (for upgrade/reinstall cases)
        if info.installType != .newInstall {
            await MainActor.run {
                currentStatus = "アプリの実行状態を確認中"
            }
            let isRunning = await MainActor.run { launcherService.isAppRunning(bundleID: info.bundleID) }
            if isRunning {
                throw AppError.installation("アプリが実行中のため、インストールできません", message: "アプリを終了してから再度お試しください")
            }
        }
        
        // Step 1: Create disk image
        await MainActor.run {
            currentStatus = "ディスクイメージ作成中"
        }
        do {
            _ = try await createAppDiskImage(info: info)
        } catch {
            throw InstallationError.diskImageCreationFailed(error.localizedDescription)
        }
        
        // Step 2: Mount disk image
        await MainActor.run {
            currentStatus = "マウント中"
        }
        guard let diskImageDir = await settingsStore.diskImageDirectory else {
            throw AppError.diskImage("ディスクイメージの保存先が未設定", message: "")
        }
        let imageURL = diskImageDir.appendingPathComponent("\(info.bundleID).asif")
        
        do {
            _ = try await mountAppDiskImage(imageURL: imageURL, bundleID: info.bundleID)
        } catch {
            throw InstallationError.mountFailed(error.localizedDescription)
        }
        
        // Step 3: Install via PlayCover
        await MainActor.run {
            currentStatus = "インストール中"
        }
        do {
            try await installIPAToPlayCover(info.ipaURL, info: info)
        } catch {
            throw InstallationError.playCoverInstallFailed(error.localizedDescription)
        }
        
        await MainActor.run {
            currentStatus = "完了"
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
            currentStatus = "完了"
            currentAppName = ""  // Clear current app name after all installations complete
            currentAppIcon = nil  // Clear current app icon
            
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
                  let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
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
