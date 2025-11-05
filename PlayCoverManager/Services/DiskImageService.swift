import Foundation

enum DiskImageServiceError: Error {
    case diskImageNotFound(URL)
    case mountPointMissing(URL)
    case invalidBundleIdentifier
}

struct DiskImageDescriptor: Identifiable, Equatable {
    let id = UUID()
    let bundleIdentifier: String
    let imageURL: URL
    let mountPoint: URL
    let isMounted: Bool
    let volumePath: URL?
    let sizeOnDisk: UInt64?
}

final class DiskImageService {
    private let fileManager: FileManager
    private let processRunner: ProcessRunner
    private let settings: SettingsStore

    init(fileManager: FileManager = .default, processRunner: ProcessRunner = ProcessRunner(), settings: SettingsStore) {
        self.fileManager = fileManager
        self.processRunner = processRunner
        self.settings = settings
    }

    private func diskImageURL(for bundleIdentifier: String) throws -> URL {
        guard let base = settings.diskImageDirectory else {
            throw AppError.diskImage("ディスクイメージの保存先が未設定", message: "設定画面から保存先を指定してください。")
        }
        return base.appendingPathComponent("\(bundleIdentifier).asif")
    }

    func diskImageDescriptor(for bundleIdentifier: String, containerURL: URL) throws -> DiskImageDescriptor {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        let exists = fileManager.fileExists(atPath: imageURL.path)
        let mountPoint = containerURL
        var resourceValues = try? mountPoint.resourceValues(forKeys: [.volumeURLKey])
        var isMounted = resourceValues?.volumeURL != nil
        if !isMounted {
            // Fallback: check if mount point is currently a disk image device by checking system attributes
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: mountPoint.path, isDirectory: &isDirectory), isDirectory.boolValue {
                // Directory exists but no volume info; treat as not mounted
            } else {
                isMounted = false
            }
        }
        let volumePath: URL? = isMounted ? mountPoint : nil
        return DiskImageDescriptor(bundleIdentifier: bundleIdentifier,
                                   imageURL: imageURL,
                                   mountPoint: mountPoint,
                                   isMounted: isMounted,
                                   volumePath: volumePath,
                                   sizeOnDisk: exists ? (try? imageURL.totalAllocatedSize()) : nil)
    }

    func ensureDiskImageExists(for bundleIdentifier: String, volumeName: String? = nil) async throws -> URL {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        if fileManager.fileExists(atPath: imageURL.path) {
            return imageURL
        }
        try fileManager.createDirectory(at: imageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let volName = volumeName ?? bundleIdentifier
        let args = [
            "image", "create", "blank",
            "--format", "ASIF",
            "--size", "50G",
            "--volumeName", volName,
            imageURL.path
        ]
        _ = try await processRunner.run("/usr/sbin/diskutil", args)
        return imageURL
    }

    func mountDiskImage(for bundleIdentifier: String, at mountPoint: URL, nobrowse: Bool) async throws {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        guard fileManager.fileExists(atPath: imageURL.path) else {
            throw AppError.diskImage("ディスクイメージが見つかりません", message: imageURL.path)
        }
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        var args: [String] = ["attach", imageURL.path, "-mountpoint", mountPoint.path, "-owners", "on"]
        if nobrowse {
            args.append("-nobrowse")
        }
        _ = try await processRunner.run("/usr/bin/hdiutil", args)
    }

    func mountTemporarily(for bundleIdentifier: String, temporaryMountBase: URL) async throws -> URL {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        let tempMountPoint = temporaryMountBase.appendingPathComponent(bundleIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: tempMountPoint, withIntermediateDirectories: true)
        var args: [String] = ["attach", imageURL.path, "-mountpoint", tempMountPoint.path, "-owners", "on", "-nobrowse"]
        _ = try await processRunner.run("/usr/bin/hdiutil", args)
        return tempMountPoint
    }

    func detach(volumeURL: URL) async throws {
        _ = try await processRunner.run("/usr/bin/hdiutil", ["detach", volumeURL.path])
    }

    func detachAll(volumeURLs: [URL]) async throws {
        for url in volumeURLs {
            do {
                try await detach(volumeURL: url)
            } catch {
                throw AppError.diskImage("ディスクイメージのアンマウントに失敗", message: url.path, underlying: error)
            }
        }
    }
}

private extension URL {
    func totalAllocatedSize() throws -> UInt64 {
        let resourceValues = try resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
        if let total = resourceValues.totalFileAllocatedSize {
            return UInt64(total)
        }
        if let single = resourceValues.fileAllocatedSize {
            return UInt64(single)
        }
        return 0
    }
}
