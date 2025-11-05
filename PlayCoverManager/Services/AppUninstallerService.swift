//
//  AppUninstallerService.swift
//  PlayCoverManager
//
//  App uninstallation service
//  Handles complete removal of apps, disk images, and associated files
//

import Foundation
import Observation

@MainActor
@Observable
class AppUninstallerService {
    nonisolated(unsafe) let processRunner: ProcessRunner
    let diskImageService: DiskImageService
    let settingsStore: SettingsStore
    
    // Uninstallation state
    var isUninstalling = false
    var currentProgress: Double = 0.0
    var currentStatus: String = ""
    var uninstalledApps: [String] = []
    var failedApps: [String] = []
    
    init(processRunner: ProcessRunner? = nil,
         diskImageService: DiskImageService,
         settingsStore: SettingsStore) {
        self.processRunner = processRunner ?? ProcessRunner()
        self.diskImageService = diskImageService
        self.settingsStore = settingsStore
    }
    
    // MARK: - Installed App Detection
    
    struct InstalledAppInfo: Sendable {
        let appName: String
        let bundleID: String
        let version: String
        let diskImageURL: URL
        let appSize: Int64
        let diskImageSize: Int64
        
        nonisolated init(appName: String, bundleID: String, version: String, diskImageURL: URL, appSize: Int64, diskImageSize: Int64) {
            self.appName = appName
            self.bundleID = bundleID
            self.version = version
            self.diskImageURL = diskImageURL
            self.appSize = appSize
            self.diskImageSize = diskImageSize
        }
    }
    
    func getInstalledApps() async throws -> [InstalledAppInfo] {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        guard FileManager.default.fileExists(atPath: applicationsDir.path) else {
            return []
        }
        
        let appDirs = try FileManager.default.contentsOfDirectory(
            at: applicationsDir,
            includingPropertiesForKeys: [.fileSizeKey, .totalFileSizeKey]
        )
        
        var apps: [InstalledAppInfo] = []
        
        for appURL in appDirs where appURL.pathExtension == "app" {
            let infoPlist = appURL.appendingPathComponent("Info.plist")
            guard FileManager.default.fileExists(atPath: infoPlist.path) else { continue }
            
            do {
                let plistData = try Data(contentsOf: infoPlist)
                guard let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                      let bundleID = plist["CFBundleIdentifier"] as? String else {
                    continue
                }
                
                // Extract app name (try Japanese first, fallback to English)
                var appName = ""
                let jaLproj = appURL.appendingPathComponent("ja.lproj/InfoPlist.strings")
                if FileManager.default.fileExists(atPath: jaLproj.path) {
                    if let stringsData = try? Data(contentsOf: jaLproj),
                       let stringsDict = try? PropertyListSerialization.propertyList(from: stringsData, format: nil) as? [String: String] {
                        appName = stringsDict["CFBundleDisplayName"] ?? stringsDict["CFBundleName"] ?? ""
                    }
                }
                
                if appName.isEmpty {
                    appName = (plist["CFBundleDisplayName"] as? String) ?? (plist["CFBundleName"] as? String) ?? appURL.deletingPathExtension().lastPathComponent
                }
                
                let version = (plist["CFBundleShortVersionString"] as? String) ?? (plist["CFBundleVersion"] as? String) ?? "Unknown"
                
                // Calculate app size
                let appSize = directorySize(at: appURL) ?? 0
                
                // Find corresponding disk image
                let imageName = findDiskImageName(for: bundleID)
                guard let diskImageDir = settingsStore.diskImageDirectory else { continue }
                let imageURL = diskImageDir.appendingPathComponent(imageName)
                let diskImageSize = fileSize(at: imageURL) ?? 0
                
                apps.append(InstalledAppInfo(
                    appName: appName,
                    bundleID: bundleID,
                    version: version,
                    diskImageURL: imageURL,
                    appSize: appSize,
                    diskImageSize: diskImageSize
                ))
            } catch {
                continue
            }
        }
        
        return apps.sorted { $0.appName < $1.appName }
    }
    
    private func findDiskImageName(for bundleID: String) -> String {
        let containerPath = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(bundleID)", isDirectory: true)
        
        // Check if it's currently mounted and get mount device
        do {
            let mountOutput = try processRunner.runSync("/sbin/mount", [])
            let lines = mountOutput.split(separator: "\n")
            
            for line in lines {
                if line.contains(containerPath.path) {
                    // Extract device name from mount output
                    // Format: /dev/diskXsY on /path/to/mount (apfs, ...)
                    if let deviceMatch = line.split(separator: " ").first {
                        // Get volume name from diskutil
                        if let diskutilOutput = try? processRunner.runSync("/usr/sbin/diskutil", ["info", String(deviceMatch)]),
                           let volumeLine = diskutilOutput.split(separator: "\n").first(where: { $0.contains("Volume Name:") }) {
                            let volumeName = volumeLine.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                            return "\(volumeName).asif"
                        }
                    }
                }
            }
        } catch {
            // Fallback: try to guess from bundle ID
        }
        
        // Fallback: generate from bundle ID last segment
        let segments = bundleID.split(separator: ".")
        if let lastSegment = segments.last {
            let volumeName = String(lastSegment).replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression)
            return "\(volumeName).asif"
        }
        
        return "\(bundleID).asif"
    }
    
    private func directorySize(at url: URL) -> Int64? {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        
        return totalSize
    }
    
    private func fileSize(at url: URL) -> Int64? {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            return size
        }
        
        return nil
    }
    
    // MARK: - App Running Check
    
    nonisolated func isAppRunning(bundleID: String) async -> Bool {
        print("🟢 [DEBUG] isAppRunning チェック開始: \(bundleID)")
        do {
            let psOutput = try await processRunner.run("/bin/ps", ["-ax"])
            print("🟢 [DEBUG] ps コマンド完了")
            let lines = psOutput.split(separator: "\n")
            
            for line in lines {
                if line.contains(bundleID) || line.contains(".app/Contents/MacOS/") {
                    print("🟢 [DEBUG] アプリが実行中です")
                    return true
                }
            }
            print("🟢 [DEBUG] アプリは実行されていません")
        } catch {
            print("🟢 [DEBUG] ps コマンドエラー: \(error)")
            return false
        }
        
        return false
    }
    
    // MARK: - Uninstallation
    
    nonisolated func uninstallApp(_ app: InstalledAppInfo) async throws {
        print("🟢 [DEBUG] uninstallApp 開始: \(app.appName)")
        await MainActor.run { 
            currentStatus = "アプリを削除中: \(app.appName)"
            print("🟢 [DEBUG] currentStatus = \(currentStatus)")
        }
        
        // Check if app is running
        if await isAppRunning(bundleID: app.bundleID) {
            throw AppError.installation("アプリが実行中のため、アンインストールできません", message: "アプリを終了してから再度お試しください")
        }
        
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        // Step 1: Remove app from PlayCover Applications/
        // Find actual app by bundle ID (app name might differ from bundle ID)
        await MainActor.run { currentStatus = "アプリを検索中..." }
        if let appDirs = try? FileManager.default.contentsOfDirectory(at: applicationsDir, includingPropertiesForKeys: nil) {
            for appURL in appDirs where appURL.pathExtension == "app" {
                let infoPlist = appURL.appendingPathComponent("Info.plist")
                if let plistData = try? Data(contentsOf: infoPlist),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                   let bundleID = plist["CFBundleIdentifier"] as? String,
                   bundleID == app.bundleID {
                    await MainActor.run { currentStatus = "アプリを削除中..." }
                    try FileManager.default.removeItem(at: appURL)
                    break
                }
            }
        }
        
        // Step 2: Remove app settings
        await MainActor.run { currentStatus = "設定ファイルを削除中..." }
        let settingsFile = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/App Settings/\(app.bundleID).plist")
        
        try? FileManager.default.removeItem(at: settingsFile)
        
        // Step 3: Remove entitlements
        let entitlementsFile = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Entitlements/\(app.bundleID).plist")
        
        try? FileManager.default.removeItem(at: entitlementsFile)
        
        // Step 4: Remove keymapping
        let keymappingFile = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Keymapping/\(app.bundleID).plist")
        
        try? FileManager.default.removeItem(at: keymappingFile)
        
        // Step 4.5: Remove PlayChain files (if they exist)
        let playChainDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/PlayChain")
        let playChainFile = playChainDir.appendingPathComponent(app.bundleID)
        let playChainEncrypted = playChainDir.appendingPathComponent("\(app.bundleID).keyCover")
        
        try? FileManager.default.removeItem(at: playChainFile)
        try? FileManager.default.removeItem(at: playChainEncrypted)
        
        // Step 4.6: Remove external caches (various locations)
        await MainActor.run { currentStatus = "キャッシュを削除中..." }
        let libraryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library")
        let cacheDirs = [
            "Application Scripts",
            "Caches",
            "HTTPStorages",
            "Saved Application State"
        ]
        
        for cacheDir in cacheDirs {
            let cachePath = libraryURL.appendingPathComponent(cacheDir)
            if let contents = try? FileManager.default.contentsOfDirectory(at: cachePath, includingPropertiesForKeys: nil) {
                for item in contents {
                    if item.lastPathComponent.contains(app.bundleID) {
                        try? FileManager.default.removeItem(at: item)
                    }
                }
            }
        }
        
        // Step 5: Unmount and remove container (this is what we mounted during installation)
        let internalContainer = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(app.bundleID)", isDirectory: true)
        
        await MainActor.run { currentStatus = "コンテナ確認中..." }
        
        // Check if it's a mount point
        do {
            let mountOutput = try await processRunner.run("/sbin/mount", [])
            if mountOutput.contains(internalContainer.path) {
                // It's mounted - unmount it
                await MainActor.run { currentStatus = "ディスクイメージをアンマウント中..." }
                try await diskImageService.detach(volumeURL: internalContainer)
                
                // After unmounting, the mount point directory should be removed automatically by the system
                // But sometimes it remains as an empty directory - clean it up
                try await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 sec for system to clean up
                
                if FileManager.default.fileExists(atPath: internalContainer.path) {
                    try? FileManager.default.removeItem(at: internalContainer)
                }
            } else if FileManager.default.fileExists(atPath: internalContainer.path) {
                // Not mounted but directory exists - this shouldn't happen in normal cases
                // but remove it anyway (might be leftover from previous failed uninstall)
                await MainActor.run { currentStatus = "残存ディレクトリを削除中..." }
                try? FileManager.default.removeItem(at: internalContainer)
            }
        } catch {
            // If mount check fails, try to remove directory anyway
            try? FileManager.default.removeItem(at: internalContainer)
        }
        
        // Step 6: Delete disk image file (this is what we created during installation)
        if FileManager.default.fileExists(atPath: app.diskImageURL.path) {
            await MainActor.run { currentStatus = "ディスクイメージを削除中..." }
            try FileManager.default.removeItem(at: app.diskImageURL)
        }
        
        // Step 7: Remove from BundleID Cache (PlayCover's app registry)
        await MainActor.run { currentStatus = "キャッシュを更新中..." }
        let bundleIDCacheURL = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/CACHE")
        
        if FileManager.default.fileExists(atPath: bundleIDCacheURL.path) {
            do {
                let cacheContent = try String(contentsOf: bundleIDCacheURL, encoding: .utf8)
                let bundleIDs = cacheContent.split(separator: "\n").map(String.init)
                let filteredIDs = bundleIDs.filter { $0 != app.bundleID }
                let newContent = filteredIDs.joined(separator: "\n") + "\n"
                try newContent.write(to: bundleIDCacheURL, atomically: false, encoding: .utf8)
            } catch {
                // Ignore cache update errors
            }
        }
        
        await MainActor.run { currentStatus = "✅ \(app.appName) をアンインストールしました" }
    }
    
    nonisolated func uninstallApps(_ apps: [InstalledAppInfo]) async throws {
        print("🔴 [DEBUG] uninstallApps 開始: \(apps.count) 個")
        
        await MainActor.run {
            print("🔴 [DEBUG] MainActor: isUninstalling = true")
            isUninstalling = true
            uninstalledApps.removeAll()
            failedApps.removeAll()
            currentProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                print("🔴 [DEBUG] defer: isUninstalling = false")
                isUninstalling = false
            }
        }
        
        let totalApps = apps.count
        print("🔴 [DEBUG] totalApps = \(totalApps)")
        
        for (index, app) in apps.enumerated() {
            print("🔴 [DEBUG] アプリ処理開始 [\(index + 1)/\(totalApps)]: \(app.appName)")
            
            await MainActor.run {
                currentProgress = Double(index) / Double(totalApps)
                currentStatus = "[\(index + 1)/\(totalApps)] \(app.appName)"
                print("🔴 [DEBUG] MainActor: currentStatus = \(currentStatus)")
            }
            
            do {
                print("🔴 [DEBUG] uninstallApp 呼び出し: \(app.appName)")
                try await uninstallApp(app)
                print("🔴 [DEBUG] uninstallApp 完了: \(app.appName)")
                await MainActor.run {
                    uninstalledApps.append(app.appName)
                }
            } catch {
                print("🔴 [DEBUG] uninstallApp エラー: \(app.appName) - \(error)")
                await MainActor.run {
                    failedApps.append("\(app.appName): \(error.localizedDescription)")
                }
            }
        }
        
        print("🔴 [DEBUG] すべて完了")
        await MainActor.run {
            currentProgress = 1.0
            currentStatus = "完了"
            print("🔴 [DEBUG] MainActor: currentStatus = 完了")
        }
    }
    
    // MARK: - Size Formatting
    
    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
