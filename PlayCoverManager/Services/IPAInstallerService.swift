//
//  IPAInstallerService.swift
//  PlayCoverManager
//
//  IPA installation service
//  Handles IPA file parsing, volume creation, PlayCover integration, and installation monitoring
//

import Foundation
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
    
    init(processRunner: ProcessRunner = ProcessRunner(),
         diskImageService: DiskImageService,
         settingsStore: SettingsStore) {
        self.processRunner = processRunner
        self.diskImageService = diskImageService
        self.settingsStore = settingsStore
    }
    
    // MARK: - IPA Information Extraction
    
    struct IPAInfo {
        let bundleID: String
        let appName: String
        let appNameEnglish: String
        let version: String
        let volumeName: String
    }
    
    func extractIPAInfo(from ipaURL: URL) async throws -> IPAInfo {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Find Info.plist path in IPA
        let unzipListOutput = try await processRunner.run("/usr/bin/unzip", ["-l", ipaURL.path])
        let lines = unzipListOutput.split(separator: "\n")
        
        guard let plistLine = lines.first(where: { $0.contains("Payload/") && $0.contains(".app/Info.plist") }),
              let plistPath = plistLine.split(separator: " ").last.map(String.init) else {
            throw AppError.installation("IPA 内に Info.plist が見つかりません", message: "")
        }
        
        // Extract Info.plist
        _ = try await processRunner.run("/usr/bin/unzip", ["-q", ipaURL.path, plistPath, "-d", tempDir.path])
        
        let infoPlistURL = tempDir.appendingPathComponent(plistPath)
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            throw AppError.installation("Info.plist の解凍に失敗しました", message: "")
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
        
        // Try to extract Japanese app name
        var appName: String = appNameEn
        let jaStringsPath = lines.first(where: { $0.contains("Payload/") && $0.contains(".app/ja.lproj/InfoPlist.strings") })
            .flatMap { $0.split(separator: " ").last.map(String.init) }
        
        if let jaPath = jaStringsPath {
            do {
                _ = try await processRunner.run("/usr/bin/unzip", ["-q", ipaURL.path, jaPath, "-d", tempDir.path])
                let jaStringsURL = tempDir.appendingPathComponent(jaPath)
                
                if FileManager.default.fileExists(atPath: jaStringsURL.path) {
                    let stringsData = try Data(contentsOf: jaStringsURL)
                    if let stringsDict = try PropertyListSerialization.propertyList(from: stringsData, format: nil) as? [String: String] {
                        if let displayName = stringsDict["CFBundleDisplayName"], !displayName.isEmpty {
                            appName = displayName
                        } else if let bundleName = stringsDict["CFBundleName"], !bundleName.isEmpty {
                            appName = bundleName
                        }
                    }
                }
            } catch {
                // Fallback to English name
            }
        }
        
        // Generate volume name (ASCII-only)
        var volumeName = appNameEn.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
        
        // Fallback: use last segment of Bundle ID if volume name is empty
        if volumeName.isEmpty {
            let bundleSegments = bundleID.split(separator: ".")
            if let lastSegment = bundleSegments.last {
                volumeName = String(lastSegment).replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
            }
        }
        
        return IPAInfo(
            bundleID: bundleID,
            appName: appName,
            appNameEnglish: appNameEn,
            version: version,
            volumeName: volumeName
        )
    }
    
    // MARK: - Volume Creation and Mounting
    
    func createAppDiskImage(info: IPAInfo) async throws -> URL {
        currentStatus = "💾 ディスクイメージを作成中: \(info.volumeName)"
        
        guard let diskImageDir = settingsStore.diskImageDirectory else {
            throw AppError.diskImage("ディスクイメージの保存先が未設定", message: "設定画面から保存先を指定してください。")
        }
        
        let imageName = "\(info.volumeName).asif"
        let imageURL = diskImageDir.appendingPathComponent(imageName)
        
        // Check if image already exists
        if FileManager.default.fileExists(atPath: imageURL.path) {
            currentStatus = "✅ ディスクイメージは既に存在します"
            return imageURL
        }
        
        // Create ASIF disk image
        try await diskImageService.createDiskImage(
            at: imageURL,
            volumeName: info.volumeName,
            size: "50G"
        )
        
        currentStatus = "✅ ディスクイメージを作成しました"
        return imageURL
    }
    
    func mountAppDiskImage(imageURL: URL, bundleID: String) async throws -> URL {
        currentStatus = "📌 ディスクイメージをマウント中..."
        
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
                currentStatus = "✅ 既に正しい場所にマウントされています"
                return mountPoint
            }
        }
        
        // Mount with nobrowse option
        try await diskImageService.mountDiskImage(imageURL, at: mountPoint, nobrowse: true)
        
        currentStatus = "✅ マウント完了: \(mountPoint.path)"
        return mountPoint
    }
    
    // MARK: - PlayCover Integration
    
    func installIPAToPlayCover(_ ipaURL: URL, info: IPAInfo) async throws {
        currentStatus = "PlayCover でインストール中（完了まで待機）..."
        
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
    
    private func monitorInstallationProgress(bundleID: String, appName: String) async throws {
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
        if FileManager.default.fileExists(atPath: settingsFile.path) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: settingsFile.path),
               let modDate = attributes[.modificationDate] as? Date {
                lastSettingsMTime = modDate.timeIntervalSince1970
            }
        }
        
        while elapsed < maxWait {
            // Check if PlayCover is still running
            let psOutput = try await processRunner.run("/bin/ps", ["-ax"])
            let isPlayCoverRunning = psOutput.contains("PlayCover.app")
            
            if !isPlayCoverRunning {
                // PlayCover crashed or closed - verify installation
                if try await verifyInstallationComplete(bundleID: bundleID) {
                    currentStatus = "✅ インストールが完了しました（PlayCover終了後に検知）"
                    return
                } else {
                    throw AppError.installation("PlayCover が終了しました", message: "インストール中にクラッシュした可能性があります")
                }
            }
            
            // Check settings file updates
            if FileManager.default.fileExists(atPath: settingsFile.path) {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: settingsFile.path),
                   let modDate = attributes[.modificationDate] as? Date {
                    let currentMTime = modDate.timeIntervalSince1970
                    
                    // Detect settings file update
                    if currentMTime != lastSettingsMTime && lastSettingsMTime > 0 {
                        settingsUpdateCount += 1
                        lastSettingsMTime = currentMTime
                        
                        if settingsUpdateCount == 1 {
                            firstUpdateTime = elapsed
                            currentStatus = "◆ 1回目の更新検知（2回目待ち）..."
                        } else if settingsUpdateCount >= 2 {
                            currentStatus = "◇ 2回目の更新検知（安定性チェック開始）..."
                        }
                    }
                    
                    // Two-phase detection: 2nd update + stability check
                    if settingsUpdateCount >= 2 {
                        // Phase 2: Verify file stability
                        if currentMTime == lastStableMTime {
                            stableDuration += checkInterval
                            
                            if stableDuration >= stabilityThreshold {
                                // Check if PlayCover is still writing
                                let lsofOutput = try? await processRunner.run("/usr/sbin/lsof", [settingsFile.path])
                                let isPlayCoverWriting = lsofOutput?.contains("PlayCover") ?? false
                                
                                if !isPlayCoverWriting {
                                    currentStatus = "✅ インストールが完了しました"
                                    return
                                } else {
                                    // Reset stability counter
                                    stableDuration = 0
                                }
                            } else {
                                currentStatus = "⏳ 安定性検証中... (\(Int(stableDuration))s/\(Int(stabilityThreshold))s)"
                            }
                        } else {
                            // mtime changed - reset stability
                            lastStableMTime = currentMTime
                            stableDuration = 0
                        }
                    }
                    // Fallback: Single-update pattern (for very small apps)
                    else if settingsUpdateCount == 1 && firstUpdateTime > 0 {
                        let timeSinceFirstUpdate = elapsed - firstUpdateTime
                        if timeSinceFirstUpdate >= 8 {
                            // Check stability for single-update pattern
                            if currentMTime == lastStableMTime {
                                stableDuration += checkInterval
                                
                                if stableDuration >= stabilityThreshold {
                                    currentStatus = "✅ インストールが完了しました（極小アプリ）"
                                    return
                                }
                            } else {
                                lastStableMTime = currentMTime
                                stableDuration = 0
                            }
                        }
                    }
                    
                    lastSettingsMTime = currentMTime
                } else {
                    lastSettingsMTime = 0
                }
            }
            
            try await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
            elapsed += checkInterval
        }
        
        throw AppError.installation("インストール完了の自動検知がタイムアウトしました", message: "手動で確認してください")
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
    
    // MARK: - Complete Installation Workflow
    
    func installIPAs(_ ipaURLs: [URL]) async throws {
        isInstalling = true
        installedApps.removeAll()
        failedApps.removeAll()
        currentProgress = 0.0
        
        defer {
            isInstalling = false
        }
        
        let totalIPAs = ipaURLs.count
        
        for (index, ipaURL) in ipaURLs.enumerated() {
            currentProgress = Double(index) / Double(totalIPAs)
            currentStatus = "[\(index + 1)/\(totalIPAs)] \(ipaURL.lastPathComponent)"
            
            do {
                // Step 1: Extract IPA info
                let info = try await extractIPAInfo(from: ipaURL)
                
                // Step 2: Create disk image
                let imageURL = try await createAppDiskImage(info: info)
                
                // Step 3: Mount disk image
                _ = try await mountAppDiskImage(imageURL: imageURL, bundleID: info.bundleID)
                
                // Step 4: Install to PlayCover
                try await installIPAToPlayCover(ipaURL, info: info)
                
                installedApps.append(info.appName)
                
            } catch {
                failedApps.append(ipaURL.lastPathComponent + ": \(error.localizedDescription)")
            }
        }
        
        currentProgress = 1.0
        currentStatus = "完了"
    }
}
