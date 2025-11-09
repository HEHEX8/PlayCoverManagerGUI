//
//  AppUninstallerService.swift
//  PlayCoverManager
//
//  App uninstallation service
//  Handles complete removal of apps, disk images, and associated files
//

import Foundation
import AppKit
import Observation

@MainActor
@Observable
class AppUninstallerService {
    let processRunner: ProcessRunner
    let diskImageService: DiskImageService
    let settingsStore: SettingsStore
    let perAppSettingsStore: PerAppSettingsStore
    let launcherService: LauncherService
    
    // Uninstallation state
    var isUninstalling = false
    var currentProgress: Double = 0.0
    var currentStatus: String = ""
    var uninstalledApps: [String] = []
    var failedApps: [String] = []
    
    init(processRunner: ProcessRunner? = nil,
         diskImageService: DiskImageService,
         settingsStore: SettingsStore,
         perAppSettingsStore: PerAppSettingsStore,
         launcherService: LauncherService) {
        self.processRunner = processRunner ?? ProcessRunner()
        self.diskImageService = diskImageService
        self.settingsStore = settingsStore
        self.perAppSettingsStore = perAppSettingsStore
        self.launcherService = launcherService
    }
    
    // MARK: - Installed App Detection
    
    struct InstalledAppInfo: Sendable {
        let appName: String
        let bundleID: String
        let version: String
        let diskImageURL: URL
        let appSize: Int64
        let diskImageSize: Int64
        let icon: NSImage?
        
        nonisolated init(appName: String, bundleID: String, version: String, diskImageURL: URL, appSize: Int64, diskImageSize: Int64, icon: NSImage?) {
            self.appName = appName
            self.bundleID = bundleID
            self.version = version
            self.diskImageURL = diskImageURL
            self.appSize = appSize
            self.diskImageSize = diskImageSize
            self.icon = icon
        }
    }
    
    func getInstalledApps() async throws -> [InstalledAppInfo] {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = PlayCoverPaths.playCoverApplicationsURL(playCoverBundleID: playCoverBundleID)
        
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
                guard let plist = plistData.parsePlist(),
                      let bundleID = plist["CFBundleIdentifier"] as? String else {
                    continue
                }
                
                // Extract app name (try app's configured language, fallback to English)
                var appName = ""
                
                // Get app's configured language (respects user's language setting in app)
                let appLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
                let primaryLang = appLanguages.first ?? Locale.preferredLanguages.first ?? "en"
                
                // Try configured language (try both full code and base code)
                if primaryLang != "en" {
                    // Try full language code first (e.g., zh-Hans.lproj)
                    var langLproj = appURL.appendingPathComponent("\(primaryLang).lproj/InfoPlist.strings")
                    if FileManager.default.fileExists(atPath: langLproj.path) {
                        if let stringsData = try? Data(contentsOf: langLproj),
                           let stringsDict = stringsData.parsePlist() as? [String: String] {
                            appName = stringsDict["CFBundleDisplayName"] ?? stringsDict["CFBundleName"] ?? ""
                        }
                    }
                    
                    // If not found, try base language code (e.g., zh.lproj)
                    if appName.isEmpty {
                        let baseLang = String(primaryLang.prefix(2))
                        langLproj = appURL.appendingPathComponent("\(baseLang).lproj/InfoPlist.strings")
                        if FileManager.default.fileExists(atPath: langLproj.path) {
                            if let stringsData = try? Data(contentsOf: langLproj),
                               let stringsDict = stringsData.parsePlist() as? [String: String] {
                                appName = stringsDict["CFBundleDisplayName"] ?? stringsDict["CFBundleName"] ?? ""
                            }
                        }
                    }
                }
                
                // Fallback to English if configured language not found
                if appName.isEmpty && primaryLang != "en" {
                    let enLproj = appURL.appendingPathComponent("en.lproj/InfoPlist.strings")
                    if FileManager.default.fileExists(atPath: enLproj.path) {
                        if let stringsData = try? Data(contentsOf: enLproj),
                           let stringsDict = stringsData.parsePlist() as? [String: String] {
                            appName = stringsDict["CFBundleDisplayName"] ?? stringsDict["CFBundleName"] ?? ""
                        }
                    }
                }
                
                // Final fallback to Info.plist
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
                
                // Get app icon - request larger size for better quality
                let icon = AppIconHelper.loadAppIcon(from: appURL)
                
                apps.append(InstalledAppInfo(
                    appName: appName,
                    bundleID: bundleID,
                    version: version,
                    diskImageURL: imageURL,
                    appSize: appSize,
                    diskImageSize: diskImageSize,
                    icon: icon
                ))
            } catch {
                continue
            }
        }
        
        return apps.sorted { $0.appName < $1.appName }
    }
    
    private func findDiskImageName(for bundleID: String) -> String {
        // Disk image is always named after the bundle ID (this is how we create it)
        // Format: bundleID.asif (e.g., "com.example.app.asif")
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
    
    // MARK: - Uninstallation
    
    nonisolated func uninstallApp(_ app: InstalledAppInfo) async throws {
        Logger.installation("Starting uninstallation of \(app.appName) (\(app.bundleID))")
        await MainActor.run { 
            currentStatus = "アプリを削除中: \(app.appName)"
        }
        
        // Check if app is running using NSRunningApplication
        let isRunning = await MainActor.run { launcherService.isAppRunning(bundleID: app.bundleID) }
        if isRunning {
            Logger.warning("Cannot uninstall running app: \(app.bundleID)")
            throw AppError.installation("アプリが実行中のため、アンインストールできません", message: "アプリを終了してから再度お試しください")
        }
        Logger.debug("App is not running, proceeding with uninstallation")
        
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = await MainActor.run { PlayCoverPaths.playCoverApplicationsURL(playCoverBundleID: playCoverBundleID) }
        
        // Step 1: Remove app from PlayCover Applications/
        // Find actual app by bundle ID (app name might differ from bundle ID)
        await MainActor.run { currentStatus = "アプリを検索中..." }
        if let appDirs = try? FileManager.default.contentsOfDirectory(at: applicationsDir, includingPropertiesForKeys: nil) {
            for appURL in appDirs where appURL.pathExtension == "app" {
                let infoPlist = appURL.appendingPathComponent("Info.plist")
                if let plistData = try? Data(contentsOf: infoPlist),
                   let plist = plistData.parsePlist(),
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
        let settingsFile = await MainActor.run { PlayCoverPaths.appSettingsURL(playCoverBundleID: playCoverBundleID, appBundleID: app.bundleID) }
        try? FileManager.default.removeItem(at: settingsFile)
        
        // Step 3: Remove entitlements
        let entitlementsFile = await MainActor.run { PlayCoverPaths.entitlementsURL(playCoverBundleID: playCoverBundleID, appBundleID: app.bundleID) }
        try? FileManager.default.removeItem(at: entitlementsFile)
        
        // Step 4: Remove keymapping
        let keymappingFile = await MainActor.run { PlayCoverPaths.keymappingURL(playCoverBundleID: playCoverBundleID, appBundleID: app.bundleID) }
        try? FileManager.default.removeItem(at: keymappingFile)
        
        // Step 4.5: Remove PlayChain files (if they exist)
        let playChainDir = await MainActor.run { PlayCoverPaths.playChainURL(playCoverBundleID: playCoverBundleID) }
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
        let internalContainer = await MainActor.run { PlayCoverPaths.containerURL(for: app.bundleID) }
        
        await MainActor.run { currentStatus = "コンテナ確認中..." }
        
        // Check if it's a mount point
        do {
            let mountOutput = try await processRunner.run("/sbin/mount", [])
            if mountOutput.contains(internalContainer.path) {
                // It's mounted - eject the disk image (unmounts and detaches in one operation)
                await MainActor.run { currentStatus = "ディスクイメージをアンマウント中..." }
                try await diskImageService.ejectDiskImage(for: internalContainer)
                
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
        
        // Step 8: Remove per-app settings
        await MainActor.run { 
            currentStatus = "アプリ設定を削除中..."
            perAppSettingsStore.removeSettings(for: app.bundleID)
        }
        
        await MainActor.run { currentStatus = "✅ \(app.appName) をアンインストールしました" }
    }
    
    nonisolated func uninstallApps(_ apps: [InstalledAppInfo]) async throws {
        await MainActor.run {
            isUninstalling = true
            uninstalledApps.removeAll()
            failedApps.removeAll()
            currentProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isUninstalling = false
            }
        }
        
        let totalApps = apps.count
        
        for (index, app) in apps.enumerated() {
            await MainActor.run {
                currentProgress = Double(index) / Double(totalApps)
                currentStatus = "[\(index + 1)/\(totalApps)] \(app.appName)"
            }
            
            do {
                try await uninstallApp(app)
                await MainActor.run {
                    uninstalledApps.append(app.appName)
                }
            } catch {
                await MainActor.run {
                    failedApps.append("\(app.appName): \(error.localizedDescription)")
                }
            }
        }
        
        await MainActor.run {
            currentProgress = 1.0
            currentStatus = "完了"
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
