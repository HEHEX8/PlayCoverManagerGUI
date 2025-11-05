import Foundation
import AppKit

struct PlayCoverApp: Identifiable, Equatable, Hashable {
    let id = UUID()
    let bundleIdentifier: String
    let displayName: String
    let localizedName: String?
    let version: String?
    let appURL: URL
    let icon: NSImage?
    let lastLaunchedFlag: Bool

    static func == (lhs: PlayCoverApp, rhs: PlayCoverApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier && lhs.appURL == rhs.appURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
        hasher.combine(appURL)
    }
}

final class LauncherService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
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
            
            let info = bundle.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let lastLaunchFlag = readLastLaunchFlag(for: bundleID)
            let app = PlayCoverApp(bundleIdentifier: bundleID, displayName: displayName, localizedName: nil, version: version, appURL: url, icon: icon, lastLaunchedFlag: lastLaunchFlag)
            apps.append(app)
        }
        return apps.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    private func getLocalizedAppName(for bundle: Bundle, url: URL) -> String {
        // Get current system language
        let preferredLanguages = Locale.preferredLanguages
        let primaryLanguage = preferredLanguages.first ?? "en"
        
        // Try to find localized strings for current language
        // Check .lproj directories inside the app bundle
        let languageCode = String(primaryLanguage.prefix(2)) // "ja" from "ja-JP"
        
        // Try language-specific lproj (e.g., ja.lproj)
        if let localizedName = getLocalizedName(from: url, languageCode: languageCode) {
            return localizedName
        }
        
        // Try bundle's localizedInfoDictionary as fallback
        if let localizedDict = bundle.localizedInfoDictionary {
            if let displayName = localizedDict["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                return displayName
            }
            if let name = localizedDict["CFBundleName"] as? String, !name.isEmpty {
                return name
            }
        }
        
        // Try main Info.plist
        if let info = bundle.infoDictionary {
            if let displayName = info["CFBundleDisplayName"] as? String, !displayName.isEmpty {
                return displayName
            }
            if let name = info["CFBundleName"] as? String, !name.isEmpty {
                return name
            }
        }
        
        // Fallback: Use filename
        return url.deletingPathExtension().lastPathComponent
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
                if let name = dict["CFBundleName"], !displayName.isEmpty {
                    return name
                }
            }
        }
        
        return nil
    }
    
    func openApp(_ app: PlayCoverApp) async throws {
        // Use 'open' command - same as Finder double-click
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [app.appURL.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "LauncherService", code: Int(process.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: "アプリの起動に失敗しました"])
        }
        
        writeLastLaunchFlag(for: app.bundleIdentifier)
    }

    private func mapDataURL() -> URL {
        let supportURL = try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return supportURL?.appendingPathComponent("PlayCoverManager", isDirectory: true).appendingPathComponent("map.dat") ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/PlayCoverManager/map.dat")
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
        var lines: [String] = []
        if let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
            lines = text.split(separator: "\n").map(String.init)
        }
        var updated = false
        for index in lines.indices {
            var parts = lines[index].split(separator: "\t").map(String.init)
            guard parts.count >= 4 else { continue }
            if parts[0] == bundleID {
                parts[3] = "1"
                lines[index] = parts.joined(separator: "\t")
                updated = true
            } else {
                parts[3] = "0"
                lines[index] = parts.joined(separator: "\t")
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
