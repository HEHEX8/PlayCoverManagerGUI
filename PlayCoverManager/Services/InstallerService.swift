import Foundation
import AppKit

final class InstallerService {
    enum InstallerState: Equatable {
        case idle
        case parsing
        case installing(bundleIdentifier: String, progress: Double)
        case completed
    }

    struct IPAInfo: Identifiable, Equatable {
        let id = UUID()
        let fileURL: URL
        let bundleIdentifier: String
        let displayName: String
        let version: String?
    }

    private let processRunner: ProcessRunner
    private let fileManager: FileManager
    private let launcherService: LauncherService

    init(processRunner: ProcessRunner = ProcessRunner(), 
         fileManager: FileManager = .default,
         launcherService: LauncherService) {
        self.processRunner = processRunner
        self.fileManager = fileManager
        self.launcherService = launcherService
    }

    func parseIPA(at url: URL) throws -> IPAInfo {
        let bundleID = try extractBundleIdentifier(from: url)
        let displayName = try extractDisplayName(from: url) ?? bundleID
        let version = try extractVersion(from: url)
        return IPAInfo(fileURL: url, bundleIdentifier: bundleID, displayName: displayName, version: version)
    }

    private func extractBundleIdentifier(from url: URL) throws -> String {
        if let value = try extractInfoPlistValue(from: url, key: "CFBundleIdentifier") as? String {
            return value
        }
        throw AppError.installation("Bundle ID を取得できません", message: url.lastPathComponent)
    }

    private func extractDisplayName(from url: URL) throws -> String? {
        if let value = try extractInfoPlistValue(from: url, key: "CFBundleDisplayName") as? String {
            return value
        }
        return try extractInfoPlistValue(from: url, key: "CFBundleName") as? String
    }

    private func extractVersion(from url: URL) throws -> String? {
        try extractInfoPlistValue(from: url, key: "CFBundleShortVersionString") as? String
    }

    private func extractInfoPlistValue(from url: URL, key: String) throws -> Any? {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDirectory) }
        _ = try processRunner.runSync("/usr/bin/unzip", ["-qq", url.path, "-d", tempDirectory.path])
        let payloadURL = tempDirectory.appendingPathComponent("Payload")
        guard let appBundleURL = try fileManager.contentsOfDirectory(at: payloadURL, includingPropertiesForKeys: nil, options: []).first(where: { $0.pathExtension == "app" }) else {
            throw AppError.installation("IPA の構造が不正です", message: url.lastPathComponent)
        }
        let infoPlistURL = appBundleURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: Any] else {
            throw AppError.installation("Info.plist を解析できません", message: infoPlistURL.lastPathComponent)
        }
        return plist[key]
    }

    func installIPA(_ ipa: IPAInfo, via playCoverApp: URL) async throws {
        // Check if app is already running
        if launcherService.isAppRunning(bundleID: ipa.bundleIdentifier) {
            throw AppError.installation(
                "アプリが実行中のため、インストールできません",
                message: "\(ipa.displayName) を終了してから再度お試しください"
            )
        }
        
        // Placeholder: Future implementation to automate PlayCover CLI / AppleScript
        // For now, we open PlayCover and let user complete installation manually.
        try await NSWorkspace.shared.open([ipa.fileURL], withApplicationAt: playCoverApp, configuration: NSWorkspace.OpenConfiguration())
    }
}

