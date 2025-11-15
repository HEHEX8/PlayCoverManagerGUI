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
    let isMounted: Bool  // Container is mounted
    
    // Helper computed property to get the last component of bundle ID
    var bundleShortName: String {
        bundleIdentifier.split(separator: ".").last.map(String.init) ?? bundleIdentifier
    }

    // Include all properties in equality check so SwiftUI detects changes
    static func == (lhs: PlayCoverApp, rhs: PlayCoverApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier &&
        lhs.appURL == rhs.appURL &&
        lhs.lastLaunchedFlag == rhs.lastLaunchedFlag &&
        lhs.isRunning == rhs.isRunning &&
        lhs.isMounted == rhs.isMounted
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
        hasher.combine(appURL)
        hasher.combine(lastLaunchedFlag)
        hasher.combine(isRunning)
        hasher.combine(isMounted)
    }
}

final class LauncherService {
    private let fileManager: FileManager
    private let iconCache = NSCache<NSString, NSImage>()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        
        // Configure icon cache with optimal settings
        iconCache.countLimit = 100  // Maximum 100 icons
        iconCache.totalCostLimit = 50 * 1024 * 1024  // 50MB limit
        iconCache.evictsObjectsWithDiscardedContent = true  // Auto-evict on memory pressure
        iconCache.name = "PlayCoverManager.IconCache"  // For debugging and instruments
    }

    // Swift 6.2: Use async/await with TaskGroup for parallel app processing
    func fetchInstalledApps(at applicationsRoot: URL) async throws -> [PlayCoverApp] {
        // Create Applications directory if it doesn't exist
        if !fileManager.fileExists(atPath: applicationsRoot.path) {
            try fileManager.createDirectory(at: applicationsRoot, withIntermediateDirectories: true)
        }
        
        let contents = try fileManager.contentsOfDirectory(at: applicationsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        
        // Swift 6.2: Parallel processing with TaskGroup
        return try await withThrowingTaskGroup(of: PlayCoverApp?.self) { group in
            for url in contents where url.pathExtension == "app" {
                group.addTask { [self] in
                    try? await self.processApp(url: url)
                }
            }
            
            var apps: [PlayCoverApp] = []
            for try await app in group {
                if let app { apps.append(app) }
            }
            
            return apps.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        }
    }
    
    // Swift 6.2: Extract app processing for parallel execution with async let for concurrent operations
    private func processApp(url: URL) async throws -> PlayCoverApp? {
        guard let bundle = Bundle(url: url) else { return nil }
        let bundleID = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
        let info = bundle.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        
        // Swift 6.2: Use async let for concurrent property fetching
        async let displayName = getLocalizedAppName(for: bundle, url: url)
        async let standardName = getStandardAppName(for: bundle)
        async let icon = getCachedIcon(for: bundleID, appURL: url)
        async let lastLaunchFlag = readLastLaunchFlag(for: bundleID)
        async let isRunning = isAppRunning(bundleID: bundleID)
        
        return PlayCoverApp(
            bundleIdentifier: bundleID,
            displayName: await displayName,
            standardName: await standardName,
            version: version,
            appURL: url,
            icon: await icon,
            lastLaunchedFlag: await lastLaunchFlag,
            isRunning: await isRunning,
            isMounted: false
        )
    }

    private func getLocalizedAppName(for bundle: Bundle, url: URL) async -> String {
        // Get app's configured language (respects user's language setting in app)
        let appLanguages = UserDefaults.standard.stringArray(forKey: "AppleLanguages") ?? []
        let primaryLanguage = appLanguages.first ?? Locale.preferredLanguages.first ?? "en"
        
        // Try to find localized strings for current language
        // Check .lproj directories inside the app bundle
        
        // Try full language code first (e.g., zh-Hans.lproj)
        if primaryLanguage != "en" {
            if let localizedName = getLocalizedName(from: url, languageCode: primaryLanguage) {
                return localizedName
            }
            
            // If not found, try base language code (e.g., zh.lproj)
            let baseLanguageCode = String(primaryLanguage.prefix(2))
            if baseLanguageCode != primaryLanguage {
                if let localizedName = getLocalizedName(from: url, languageCode: baseLanguageCode) {
                    return localizedName
                }
            }
        }
        
        // CRITICAL: Fallback to English if current language not found
        // This ensures we show English names instead of potentially Japanese Info.plist defaults
        if primaryLanguage != "en" {
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
    
    private func getStandardAppName(for bundle: Bundle) async -> String? {
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
    private func getCachedIcon(for bundleID: String, appURL: URL) async -> NSImage? {
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
    
    func openApp(_ app: PlayCoverApp, preferredLanguage: String? = nil, shouldLaunchFullscreen: Bool = false) async throws {
        // Set or clear app-specific language preference
        if let language = preferredLanguage {
            setAppLanguage(bundleID: app.bundleIdentifier, language: language)
        } else {
            // Clear language preference to use system default
            clearAppLanguage(bundleID: app.bundleIdentifier)
        }
        
        // Use 'open' command for compatibility with PlayCover apps
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [app.appURL.path]
        
        try process.run()
        // Don't wait for exit - return immediately like Finder double-click
        
        writeLastLaunchFlag(for: app.bundleIdentifier)
        
        // If fullscreen requested, wait for app to start and send fullscreen keystroke
        if shouldLaunchFullscreen {
            Task.detached {
                await self.waitAndToggleFullscreen(bundleID: app.bundleIdentifier)
            }
        }
    }
    
    /// Wait for app to launch and toggle fullscreen using AppleScript
    private func waitAndToggleFullscreen(bundleID: String) async {
        Logger.debug("Waiting for \(bundleID) to launch for fullscreen toggle")
        
        // Poll for app launch (max 10 seconds)
        var attempts = 0
        let maxAttempts = 40  // 10 seconds (250ms intervals)
        
        while attempts < maxAttempts {
            if await isAppRunning(bundleID: bundleID) {
                Logger.debug("\(bundleID) is now running, sending fullscreen keystroke")
                
                // Wait a bit for window to initialize
                try? await Task.sleep(for: .milliseconds(2000))
                
                // Send Cmd+Ctrl+F keystroke via AppleScript
                sendFullscreenKeystroke(bundleID: bundleID)
                return
            }
            
            try? await Task.sleep(for: .milliseconds(250))
            attempts += 1
        }
        
        Logger.debug("Timeout waiting for \(bundleID) to launch")
    }
    
    /// Send fullscreen keystroke to app using AppleScript
    private func sendFullscreenKeystroke(bundleID: String) {
        // AppleScript to send Cmd+Ctrl+F to the app
        let script = """
        tell application "System Events"
            tell (first process whose bundle identifier is "\(bundleID)")
                keystroke "f" using {command down, control down}
            end tell
        end tell
        """
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                Logger.debug("Successfully sent fullscreen keystroke to \(bundleID)")
            } else {
                Logger.error("Failed to send fullscreen keystroke to \(bundleID), exit code: \(process.terminationStatus)")
            }
        } catch {
            Logger.error("Failed to execute AppleScript for fullscreen: \(error)")
        }
    }
    
    /// Set app-specific language preference using defaults write
    private func setAppLanguage(bundleID: String, language: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        // Write AppleLanguages array to app's preference domain
        process.arguments = ["write", bundleID, "AppleLanguages", "-array", language]
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                Logger.debug("Successfully set language \(language) for \(bundleID)")
            } else {
                Logger.error("Failed to set language preference: exit code \(process.terminationStatus)")
            }
        } catch {
            Logger.error("Failed to execute defaults write: \(error)")
        }
    }
    
    /// Clear app-specific language preference to use system default
    private func clearAppLanguage(bundleID: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        // Delete AppleLanguages key to revert to system language
        process.arguments = ["delete", bundleID, "AppleLanguages"]
        
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                Logger.debug("Successfully cleared language preference for \(bundleID)")
            } else {
                // Exit code 1 just means the key didn't exist, which is fine
                Logger.debug("Language preference key didn't exist for \(bundleID) (or delete failed)")
            }
        } catch {
            Logger.error("Failed to execute defaults delete: \(error)")
        }
    }
    


    private func mapDataURL() -> URL {
        let supportURL = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return supportURL?.appendingPathComponent("PlayCoverManager", isDirectory: true).appendingPathComponent("map.dat") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/PlayCoverManager/map.dat")
    }

    // MARK: - App Runtime State
    
    /// Check if an app is currently running
    /// - Parameter bundleID: The bundle identifier of the app to check
    /// - Returns: true if the app is running and not terminated
    public func isAppRunning(bundleID: String) async -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == bundleID && !app.isTerminated
        }
    }
    
    /// Check if app is running (synchronous version)
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: true if the app is currently running
    public func isAppRunningSync(bundleID: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == bundleID && !app.isTerminated
        }
    }
    
    /// Get running app instance
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: NSRunningApplication if the app is running
    public func getRunningApp(bundleID: String) -> NSRunningApplication? {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.first { app in
            app.bundleIdentifier == bundleID && !app.isTerminated
        }
    }
    
    /// Terminate app normally (SIGTERM)
    /// - Parameter bundleID: The bundle identifier of the app to terminate
    /// - Returns: true if terminate signal was sent successfully
    public func terminateApp(bundleID: String) -> Bool {
        guard let app = getRunningApp(bundleID: bundleID) else {
            Logger.debug("Cannot terminate \(bundleID): app not running")
            return false
        }
        
        Logger.debug("Sending SIGTERM to \(bundleID) (PID: \(app.processIdentifier))")
        let success = app.terminate()
        Logger.debug("SIGTERM result for \(bundleID): \(success)")
        return success
    }
    
    /// Force terminate app (SIGKILL)
    /// - Parameter bundleID: The bundle identifier of the app to force terminate
    /// - Returns: true if force terminate signal was sent successfully
    public func forceTerminateApp(bundleID: String) -> Bool {
        guard let app = getRunningApp(bundleID: bundleID) else {
            Logger.debug("Cannot force terminate \(bundleID): app not running")
            return false
        }
        
        Logger.debug("Sending SIGKILL to \(bundleID) (PID: \(app.processIdentifier))")
        let success = app.forceTerminate()
        Logger.debug("SIGKILL result for \(bundleID): \(success)")
        return success
    }
    
    private func readLastLaunchFlag(for bundleID: String) async -> Bool {
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
        // Swift 6.2: Use FileManager extension
        try? FileManager.default.createDirectoryIfNeeded(at: url.deletingLastPathComponent())
        try? content.data(using: .utf8)?.write(to: url)
    }
}
