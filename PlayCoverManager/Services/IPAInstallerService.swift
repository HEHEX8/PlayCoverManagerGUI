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

@MainActor
@Observable
class IPAInstallerService {
    let processRunner: ProcessRunner
    let diskImageService: DiskImageService
    let settingsStore: SettingsStore
    
    // Installation state
    var isInstalling = false
    var currentProgress: Double = 0.0
    var currentStatus: String = ""
    var installedApps: [String] = []
    var failedApps: [String] = []
    
    nonisolated init(processRunner: ProcessRunner = ProcessRunner(),
         diskImageService: DiskImageService,
         settingsStore: SettingsStore) {
        self.processRunner = processRunner
        self.diskImageService = diskImageService
        self.settingsStore = settingsStore
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
        
        // Volume name is always Bundle ID
        var volumeName: String { bundleID }
        
        nonisolated init(id: UUID = UUID(), ipaURL: URL, bundleID: String, appName: String, appNameEnglish: String, version: String, icon: NSImage?, fileSize: Int64) {
            self.id = id
            self.ipaURL = ipaURL
            self.bundleID = bundleID
            self.appName = appName
            self.appNameEnglish = appNameEnglish
            self.version = version
            self.icon = icon
            self.fileSize = fileSize
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
        
        // Try system language first (if not en/ja)
        if systemLanguage != "en" && systemLanguage != "ja" {
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
        
        // Fallback to Japanese if system language didn't work
        if appName == appNameEn {
            let jaStringsURL = tempDir.appendingPathComponent("InfoPlist.strings")
            if FileManager.default.fileExists(atPath: jaStringsURL.path),
               let stringsData = try? Data(contentsOf: jaStringsURL),
               let stringsDict = try? PropertyListSerialization.propertyList(from: stringsData, format: nil) as? [String: String] {
                if let displayName = stringsDict["CFBundleDisplayName"], !displayName.isEmpty {
                    appName = displayName
                } else if let bundleName = stringsDict["CFBundleName"], !bundleName.isEmpty {
                    appName = bundleName
                }
            }
        }
        
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
        
        return IPAInfo(
            ipaURL: ipaURL,
            bundleID: bundleID,
            appName: appName,
            appNameEnglish: appNameEn,
            version: version,
            icon: icon,
            fileSize: fileSize
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
    
    private nonisolated func monitorInstallationProgress(bundleID: String, appName: String) async throws {
        let maxWait: TimeInterval = 300 // 5 minutes
        let checkInterval: TimeInterval = 2
        let stabilityThreshold: TimeInterval = 4
        
        let playCoverBundleID = "io.playcover.PlayCover"
        let appSettingsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/App Settings", isDirectory: true)
        let settingsFile = appSettingsDir.appendingPathComponent("\(bundleID).plist")
        
        var elapsed: TimeInterval = 0
        var settingsUpdateCount = 0
        var lastSettingsMTime: TimeInterval = 0
        var lastStableMTime: TimeInterval = 0
        var stableDuration: TimeInterval = 0
        var firstUpdateTime: TimeInterval = 0
        
        // Initial settings file check
        if FileManager.default.fileExists(atPath: settingsFile.path),
           let attributes = try? FileManager.default.attributesOfItem(atPath: settingsFile.path),
           let modDate = attributes[.modificationDate] as? Date {
            lastSettingsMTime = modDate.timeIntervalSince1970
        }
        
        while elapsed < maxWait {
            // Check if PlayCover is still running (use pgrep for reliability)
            let pgrepOutput = try? await processRunner.run("/usr/bin/pgrep", ["-x", "PlayCover"])
            let isPlayCoverRunning = pgrepOutput != nil && !pgrepOutput!.isEmpty
            
            if !isPlayCoverRunning {
                // PlayCover crashed or closed - verify installation
                if try await verifyInstallationComplete(bundleID: bundleID) {
                    await MainActor.run { currentStatus = "完了" }
                    return
                } else {
                    throw AppError.installation("PlayCover が終了しました", message: "")
                }
            }
            
            // Check settings file updates
            if FileManager.default.fileExists(atPath: settingsFile.path),
               let attributes = try? FileManager.default.attributesOfItem(atPath: settingsFile.path),
               let modDate = attributes[.modificationDate] as? Date {
                let currentMTime = modDate.timeIntervalSince1970
                
                // Detect settings file update
                if currentMTime != lastSettingsMTime && lastSettingsMTime > 0 {
                    settingsUpdateCount += 1
                    lastSettingsMTime = currentMTime
                    
                    if settingsUpdateCount == 1 {
                        firstUpdateTime = elapsed
                    }
                }
                
                // Two-phase detection: 2nd update + stability check
                if settingsUpdateCount >= 2 {
                    // Verify file stability
                    if currentMTime == lastStableMTime {
                        stableDuration += checkInterval
                        
                        if stableDuration >= stabilityThreshold {
                            // Check if PlayCover is still writing
                            let lsofOutput = try? await processRunner.run("/usr/sbin/lsof", [settingsFile.path])
                            let isPlayCoverWriting = lsofOutput?.contains("PlayCover") ?? false
                            
                            if !isPlayCoverWriting {
                                // Final verification: check app actually exists
                                if try await verifyInstallationComplete(bundleID: bundleID) {
                                    await MainActor.run { currentStatus = "完了" }
                                    return
                                } else {
                                    // Settings stable but app not installed - reset and continue
                                    stableDuration = 0
                                }
                            } else {
                                stableDuration = 0
                            }
                        }
                    } else {
                        lastStableMTime = currentMTime
                        stableDuration = 0
                    }
                }
                // Fallback: Single-update pattern (for very small apps)
                else if settingsUpdateCount == 1 && firstUpdateTime > 0 {
                    let timeSinceFirstUpdate = elapsed - firstUpdateTime
                    if timeSinceFirstUpdate >= 8 {
                        if currentMTime == lastStableMTime {
                            stableDuration += checkInterval
                            
                            if stableDuration >= stabilityThreshold {
                                // Final verification: check app actually exists
                                if try await verifyInstallationComplete(bundleID: bundleID) {
                                    await MainActor.run { currentStatus = "完了" }
                                    return
                                } else {
                                    stableDuration = 0
                                }
                            }
                        } else {
                            lastStableMTime = currentMTime
                            stableDuration = 0
                        }
                    }
                }
                
                lastSettingsMTime = currentMTime
            }
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            elapsed += checkInterval
        }
        
        throw AppError.installation("タイムアウト", message: "")
    }
    
    private func verifyInstallationComplete(bundleID: String) async throws -> Bool {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
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
                // Verify structure integrity
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
            currentStatus = "\(info.appName) をインストール中"
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
            failedApps.removeAll()
            currentProgress = 0.0
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
            } catch {
                await MainActor.run {
                    failedApps.append("\(info.appName): \(error.localizedDescription)")
                }
            }
        }
        
        await MainActor.run {
            currentProgress = 1.0
            currentStatus = "完了"
        }
    }
}
