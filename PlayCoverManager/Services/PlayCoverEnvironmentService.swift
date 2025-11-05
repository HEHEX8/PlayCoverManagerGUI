import Foundation

final class PlayCoverEnvironmentService {
    private let processRunner: ProcessRunner
    private let fileManager: FileManager

    init(processRunner: ProcessRunner = ProcessRunner(), fileManager: FileManager = .default) {
        self.processRunner = processRunner
        self.fileManager = fileManager
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
        let attachArgs = buildAttachArguments(for: diskImageURL, mountPoint: mountPoint, nobrowse: nobrowse)
        _ = try await processRunner.run("/usr/bin/hdiutil", attachArgs)
    }

    func buildAttachArguments(for diskImageURL: URL, mountPoint: URL, nobrowse: Bool) -> [String] {
        var args = ["attach", diskImageURL.path, "-mountpoint", mountPoint.path, "-owners", "on"]
        if nobrowse {
            args.append("-nobrowse")
        }
        return args
    }

    private func isVolumeMounted(at mountPoint: URL, expectedVolumeName: String) async -> Bool {
        do {
            let result = try await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", mountPoint.path])
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
