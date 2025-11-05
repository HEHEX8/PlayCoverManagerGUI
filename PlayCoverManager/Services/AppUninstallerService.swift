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
    let processRunner: ProcessRunner
    let diskImageService: DiskImageService
    let settingsStore: SettingsStore
    
    // Uninstallation state
    var isUninstalling = false
    var currentProgress: Double = 0.0
    var currentStatus: String = ""
    var uninstalledApps: [String] = []
    var failedApps: [String] = []
    
    init(processRunner: ProcessRunner = ProcessRunner(),
         diskImageService: DiskImageService,
         settingsStore: SettingsStore) {
        self.processRunner = processRunner
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
    
    func isAppRunning(bundleID: String) async -> Bool {
        do {
            let psOutput = try await processRunner.run("/bin/ps", ["-ax"])
            let lines = psOutput.split(separator: "\n")
            
            for line in lines {
                if line.contains(bundleID) || line.contains(".app/Contents/MacOS/") {
                    return true
                }
            }
        } catch {
            return false
        }
        
        return false
    }
    
    // MARK: - Uninstallation
    
    func uninstallApp(_ app: InstalledAppInfo) async throws {
        currentStatus = "アプリを削除中: \(app.appName)"
        
        // Check if app is running
        if await isAppRunning(bundleID: app.bundleID) {
            throw AppError.installation("アプリが実行中のため、アンインストールできません", message: "アプリを終了してから再度お試しください")
        }
        
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(playCoverBundleID)/Applications", isDirectory: true)
        
        // Step 1: Remove app from PlayCover Applications/
        // Find actual app by bundle ID (app name might differ from bundle ID)
        if let appDirs = try? FileManager.default.contentsOfDirectory(at: applicationsDir, includingPropertiesForKeys: nil) {
            for appURL in appDirs where appURL.pathExtension == "app" {
                let infoPlist = appURL.appendingPathComponent("Info.plist")
                if let plistData = try? Data(contentsOf: infoPlist),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                   let bundleID = plist["CFBundleIdentifier"] as? String,
                   bundleID == app.bundleID {
                    currentStatus = "アプリを削除中..."
                    try FileManager.default.removeItem(at: appURL)
                    break
                }
            }
        }
        
        // Step 2: Remove app settings
        currentStatus = "設定ファイルを削除中..."
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
        
        // Step 5: Remove internal container if exists
        let internalContainer = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(app.bundleID)", isDirectory: true)
        
        currentStatus = "コンテナを削除中..."
        
        // Check if it's a mount point
        let mountOutput = try await processRunner.run("/sbin/mount", [])
        if mountOutput.contains(internalContainer.path) {
            // Unmount first
            currentStatus = "ディスクイメージをアンマウント中..."
            try await diskImageService.detach(volumeURL: internalContainer)
        } else if FileManager.default.fileExists(atPath: internalContainer.path) {
            // Remove regular directory
            try? FileManager.default.removeItem(at: internalContainer)
        }
        
        // Step 6: Delete disk image
        if FileManager.default.fileExists(atPath: app.diskImageURL.path) {
            currentStatus = "ディスクイメージを削除中..."
            try FileManager.default.removeItem(at: app.diskImageURL)
        }
        
        currentStatus = "✅ \(app.appName) をアンインストールしました"
    }
    
    func uninstallApps(_ apps: [InstalledAppInfo]) async throws {
        isUninstalling = true
        uninstalledApps.removeAll()
        failedApps.removeAll()
        currentProgress = 0.0
        
        defer {
            isUninstalling = false
        }
        
        let totalApps = apps.count
        
        for (index, app) in apps.enumerated() {
            currentProgress = Double(index) / Double(totalApps)
            currentStatus = "[\(index + 1)/\(totalApps)] \(app.appName)"
            
            do {
                try await uninstallApp(app)
                uninstalledApps.append(app.appName)
            } catch {
                failedApps.append("\(app.appName): \(error.localizedDescription)")
            }
        }
        
        currentProgress = 1.0
        currentStatus = "完了"
    }
    
    // MARK: - Size Formatting
    
    func formatSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
