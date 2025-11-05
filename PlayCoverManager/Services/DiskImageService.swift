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
        let ext: String
        switch settings.diskImageFormat {
        case .sparse:
            ext = "sparseimage"
        case .sparseBundle:
            ext = "sparsebundle"
        case .asif:
            ext = "asif"
        }
        return base.appendingPathComponent("\(bundleIdentifier).\(ext)")
    }

    func diskImageDescriptor(for bundleIdentifier: String, containerURL: URL) throws -> DiskImageDescriptor {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        let exists = fileManager.fileExists(atPath: imageURL.path)
        let mountPoint = containerURL

        // Determine if mountPoint is currently a mounted volume by asking diskutil synchronously
        var isMounted = false
        var volumePath: URL? = nil
        do {
            let result = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", mountPoint.path])
            if let data = result.stdout.data(using: .utf8),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let volumeName = plist["VolumeName"] as? String {
                // Compare expected volume name with the image file name (without extension)
                let expected = imageURL.deletingPathExtension().lastPathComponent
                isMounted = (volumeName == expected)
                volumePath = isMounted ? mountPoint : nil
            }
        } catch {
            // If diskutil fails, we conservatively treat it as not mounted
            isMounted = false
            volumePath = nil
        }

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
        
        // Use diskutil for ASIF, hdiutil for legacy formats
        if settings.diskImageFormat == .asif {
            // diskutil image create blank --format ASIF --size 50G --volumeName <name> <path>
            let args = [
                "image", "create", "blank",
                "--format", "ASIF",
                "--size", "50G",
                "--volumeName", volName,
                imageURL.path
            ]
            _ = try await processRunner.run("/usr/sbin/diskutil", args)
        } else {
            // hdiutil create for sparse/sparsebundle
            let typeFlag: String
            switch settings.diskImageFormat {
            case .sparse:
                typeFlag = "SPARSE"
            case .sparseBundle:
                typeFlag = "SPARSEBUNDLE"
            case .asif:
                typeFlag = "ASIF" // unreachable
            }
            var args: [String] = [
                "create",
                "-size", "50g",
                "-type", typeFlag,
                "-fs", "APFS",
                "-volname", volName,
                imageURL.path
            ]
            if settings.diskImageFormat == .sparseBundle {
                args.insert(contentsOf: ["-imagekey", "sparse-band-size=33554432"], at: 1)
            }
            _ = try await processRunner.run("/usr/bin/hdiutil", args)
        }
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
