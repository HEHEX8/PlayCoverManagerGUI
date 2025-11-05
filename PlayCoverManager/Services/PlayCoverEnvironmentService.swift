import Foundation

final class PlayCoverEnvironmentService {
    private let processRunner: ProcessRunner
    private let fileManager: FileManager

    init(processRunner: ProcessRunner = ProcessRunner(), fileManager: FileManager = .default) {
        self.processRunner = processRunner
        self.fileManager = fileManager
    }
    
    /// Check if the current macOS version supports ASIF format (Tahoe 26.0+)
    func checkASIFSupport() throws {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        
        // macOS Tahoe is version 26.0
        guard osVersion.majorVersion >= 26 else {
            let versionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
            throw AppError.environment(
                "macOS のバージョンが古すぎます",
                message: "このアプリは macOS Tahoe 26.0 以降が必要です。\n\n現在のバージョン: macOS \(versionString)\n必要なバージョン: macOS Tahoe 26.0 以降\n\nシステムをアップデートしてから再度お試しください。"
            )
        }
    }

    func detectPlayCover() throws -> PlayCoverPaths {
        let appURL = PlayCoverPaths.defaultApplicationURL
        guard fileManager.fileExists(atPath: appURL.path) else {
            throw AppError.environment("PlayCover.app が見つかりません", message: "PlayCover を /Applications にインストールしてください。")
        }

        let infoPlistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let plistData = try? Data(contentsOf: infoPlistURL) else {
            throw AppError.environment("PlayCover の Info.plist を読み込めません", message: "PlayCover.app を確認してください。")
        }
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: &format) as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String else {
            throw AppError.environment("PlayCover の Bundle ID を取得できません", message: "PlayCover.app を再インストールしてください。")
        }

        let containerURL = PlayCoverPaths.playCoverContainerURL()
        return PlayCoverPaths(applicationURL: appURL, bundleIdentifier: bundleIdentifier, containerRootURL: containerURL)
    }

    func ensureMount(of diskImageURL: URL, mountPoint: URL, nobrowse: Bool) async throws {
        let expectedVolumeName = diskImageURL.deletingPathExtension().lastPathComponent
        if await isVolumeMounted(at: mountPoint, expectedVolumeName: expectedVolumeName) {
            return
        }

        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        
        // Mount ASIF image using diskutil (macOS Tahoe 26.0+)
        var args = ["image", "attach", diskImageURL.path, "--mountPoint", mountPoint.path]
        if nobrowse {
            args.append("--nobrowse")
        }
        _ = try await processRunner.run("/usr/sbin/diskutil", args)
    }

    private func isVolumeMounted(at mountPoint: URL, expectedVolumeName: String) async -> Bool {
        do {
            let result = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", mountPoint.path])
            guard let data = result.stdout.data(using: .utf8) else { return false }
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            if let dict = plist as? [String: Any], let volumeName = dict["VolumeName"] as? String {
                return volumeName == expectedVolumeName
            }
        } catch {
            return false
        }
        return false
    }
}
