import Foundation
import AppKit

struct PlayCoverApp: Identifiable, Equatable, Hashable {
    // Use bundleIdentifier as stable ID for SwiftUI identity
    // This ensures the same app keeps the same view identity across refreshes
    var id: String { bundleIdentifier }
    
    let bundleIdentifier: String
    let displayName: String
    let standardName: String?  // English/standard name from Info.plist
    let version: String?
    let appURL: URL
    let icon: NSImage?
    let lastLaunchedFlag: Bool
    let isRunning: Bool
    
    // Helper computed property to get the last component of bundle ID
    var bundleShortName: String {
        bundleIdentifier.split(separator: ".").last.map(String.init) ?? bundleIdentifier
    }

    // Include all properties in equality check so SwiftUI detects changes
    static func == (lhs: PlayCoverApp, rhs: PlayCoverApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.appURL == rhs.appURL &&
        lhs.lastLaunchedFlag == rhs.lastLaunchedFlag &&
        lhs.isRunning == rhs.isRunning
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
        hasher.combine(appURL)
        hasher.combine(lastLaunchedFlag)
        hasher.combine(isRunning)
    }
}

final class LauncherService {
    private let fileManager: FileManager
    private let iconCache = NSCache<NSString, NSImage>()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        // Configure icon cache
        iconCache.countLimit = 100  // Maximum 100 icons
        iconCache.totalCostLimit = 50 * 1024 * 1024  // 50MB limit
    }

    func fetchInstalledApps(at applicationsRoot: URL) throws -> [PlayCoverApp] {
        // Create Applications directory if it doesn't exist
        if !fileManager.fileExists(atPath: applicationsRoot.path) {
            try fileManager.createDirectory(at: applicationsRoot, withIntermediateDirectories: true)
        }
        
        let contents = try fileManager.contentsOfDirectory(at: applicationsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        var apps: [PlayCoverApp] = []
        for url in contents where url.pathExtension == "app" {
            guard let bundle = Bundle(url: url) else { continue }
            let bundleID = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
            
            // Get display name with proper localization
            // Try multiple methods to get the best localized name
            let displayName = getLocalizedAppName(for: bundle, url: url)
            
            // Get standard (English) name from Info.plist
            let standardName = getStandardAppName(for: bundle)
            
            let info = bundle.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String
            let icon = getCachedIcon(for: bundleID, appURL: url)
            let lastLaunchFlag = readLastLaunchFlag(for: bundleID)
            let isRunning = isAppRunning(bundleID: bundleID)
            let app = PlayCoverApp(bundleIdentifier: bundleID, displayName: displayName, standardName: standardName, version: version, appURL: url, icon: icon, lastLaunchedFlag: lastLaunchFlag, isRunning: isRunning)
            apps.append(app)
        }
        return apps.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private func getLocalizedAppName(for bundle: Bundle, url: URL) -> String {
        // Get app's configured language (respects user's language setting in app)
        let appLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
        let primaryLanguage = appLanguages.first ?? Locale.preferredLanguages.first ?? "en"
        
        // Try to find localized strings for current language
        // Check .lproj directories inside the app bundle
        let languageCode = String(primaryLanguage.prefix(2)) // "ja" from "ja-JP"
        
        // Try language-specific lproj (e.g., ja.lproj)
        if let localizedName = getLocalizedName(from: url, languageCode: languageCode) {
            return localizedName
        }
        
        // CRITICAL: Fallback to English if current language not found
        // This ensures we show English names instead of potentially Japanese Info.plist defaults
        if languageCode != "en" {
            if let englishName = getLocalizedName(from: url, languageCode: "en") {
                return englishName
            }
        }
        
        // Last resort: Try main Info.plist (may contain default language, often English but could be any language)
        if let info = bundle.infoDictionary {
            if let displayName = info["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                return displayName
            }
            if let name = info["CFBundleName"] as? String, !name.isEmpty {
                return name
            }
        }
        
        // Final fallback: Use filename
        return url.deletingPathExtension().lastPathComponent
    }
    
    private func getStandardAppName(for bundle: Bundle) -> String? {
        // Get English/standard name from en.lproj (iOS apps typically have English as base language)
        // Note: bundle.infoDictionary may return localized values based on system language
        
        // Try English localization first (most iOS apps have this)
        if let englishName = getLocalizedName(from: bundle.bundleURL, languageCode: "en") {
            return englishName
        }
        
        // Fallback: Try base.lproj
        if let baseName = getLocalizedName(from: bundle.bundleURL, languageCode: "Base") {
            return baseName
        }
        
        // Last resort: Use infoDictionary (may be localized but better than nothing)
        guard let info = bundle.infoDictionary else { return nil }
        
        if let displayName = info["CFBundleDisplayName"] as? String, !displayName.isEmpty {
            return displayName
        }
        
        if let name = info["CFBundleName"] as? String, !name.isEmpty {
            return name
        }
        
        return nil
    }
    
    private func getLocalizedName(from appURL: URL, languageCode: String) -> String? {
        // Try language.lproj/InfoPlist.strings
        let lprojURL = appURL.appendingPathComponent("\(languageCode).lproj")
        let infoPlistStringsURL = lprojURL.appendingPathComponent("InfoPlist.strings")
        
        if fileManager.fileExists(atPath: infoPlistStringsURL.path) {
            if let dict = NSDictionary(contentsOf: infoPlistStringsURL) as? [String: String] {
                if let displayName = dict["CFBundleDisplayName"], !displayName.isEmpty {
                    return displayName
                }
                if let name = dict["CFBundleName"], !name.isEmpty {
                    return name
                }
            }
        }
        
        return nil
    }
    
    /// Get cached icon for an app, loading it only if not already cached
    /// - Parameters:
    ///   - bundleID: The bundle identifier to use as cache key
    ///   - appURL: The app URL to load the icon from if not cached
    /// - Returns: The cached or newly loaded icon
    private func getCachedIcon(for bundleID: String, appURL: URL) -> NSImage? {
        let cacheKey = bundleID as NSString
        
        // Return cached icon if available
        if let cachedIcon = iconCache.object(forKey: cacheKey) {
            return cachedIcon
        }
        
        // Load icon and cache it - request larger size for better quality
        let icon = AppIconHelper.loadAppIcon(from: appURL)
        iconCache.setObject(icon, forKey: cacheKey)
        return icon
    }
    
    func openApp(_ app: PlayCoverApp) async throws {
        // Use 'open' command for compatibility with PlayCover apps
        // NSWorkspace.open() doesn't work correctly with PlayCover-wrapped iOS apps
        // The 'open' command handles the app bundle correctly, just like Finder
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [app.appURL.path]
        
        try process.run()
        // Don't wait for exit - return immediately like Finder double-click
        
        writeLastLaunchFlag(for: app.bundleIdentifier)
    }

    private func mapDataURL() -> URL {
        let supportURL = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return supportURL?.appendingPathComponent("PlayCoverManager", isDirectory: true).appendingPathComponent("map.dat") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/PlayCoverManager/map.dat")
    }

    // MARK: - App Runtime State
    
    /// Check if an app is currently running
    /// - Parameter bundleID: The bundle identifier of the app to check
    /// - Returns: true if the app is running and not terminated
    public func isAppRunning(bundleID: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == bundleID && !app.isTerminated
        }
    }
    
    private func readLastLaunchFlag(for bundleID: String) -> Bool {
        guard let data = try? Data(contentsOf: mapDataURL()), let text = String(data: data, encoding: .utf8) else {
            return false
        }
        let lines = text.split(separator: "\n")
        for line in lines {
            let parts = line.split(separator: "\t")
            guard parts.count >= 4 else { continue }
            if parts[0] == bundleID {
                return parts[3] == "1"
            }
        }
        return false
    }

    private func writeLastLaunchFlag(for bundleID: String) {
        let url = mapDataURL()
        
        // Read existing entries and deduplicate
        var bundleIDs: Set<String> = []
        var lines: [String] = []
        
        if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
            let existingLines = text.split(separator: "\n").map(String.init)
            for line in existingLines {
                let parts = line.split(separator: "\t").map(String.init)
                guard parts.count >= 1 else { continue }
                let bid = parts[0]
                if !bundleIDs.contains(bid) {
                    bundleIDs.insert(bid)
                    // Ensure 4 columns
                    let normalized = [
                        bid,
                        parts.count > 1 ? parts[1] : "",
                        parts.count > 2 ? parts[2] : "",
                        "0" // Reset all to 0
                    ].joined(separator: "\t")
                    lines.append(normalized)
                }
            }
        }
        
        // Update or add the launched app
        var updated = false
        for index in lines.indices {
            let parts = lines[index].split(separator: "\t").map(String.init)
            if parts[0] == bundleID {
                lines[index] = [parts[0], parts[1], parts[2], "1"].joined(separator: "\t")
                updated = true
                break
            }
        }
        
        if !updated {
            let entry = [bundleID, "", "", "1"].joined(separator: "\t")
            lines.append(entry)
        }
        
        let content = lines.joined(separator: "\n")
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? content.data(using: .utf8)?.write(to: url)
    }
}
