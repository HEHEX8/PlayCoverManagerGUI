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
        let contents = try fileManager.contentsOfDirectory(at: applicationsRoot, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        var apps: [PlayCoverApp] = []
        for url in contents where url.pathExtension == "app" {
            guard let bundle = Bundle(url: url) else { continue }
            let bundleID = bundle.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
            let info = bundle.infoDictionary
            let displayName = info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String ?? url.deletingPathExtension().lastPathComponent
            let localizedName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ?? bundle.localizedInfoDictionary?["CFBundleName"] as? String
            let version = info?["CFBundleShortVersionString"] as? String
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            let lastLaunchFlag = readLastLaunchFlag(for: bundleID)
            let app = PlayCoverApp(bundleIdentifier: bundleID, displayName: displayName, localizedName: localizedName, version: version, appURL: url, icon: icon, lastLaunchedFlag: lastLaunchFlag)
            apps.append(app)
        }
        return apps.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
    }

    func openApp(_ app: PlayCoverApp) throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.promptsUserIfNeeded = true
        try NSWorkspace.shared.openApplication(at: app.appURL, configuration: configuration)
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
