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
        case .sparse, .sparseHFS:
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
        
        // Verify parent directory is accessible and writable
        let parentDir = imageURL.deletingLastPathComponent()
        
        // Try to create directory - this will fail if we don't have access
        do {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && (error.code == NSFileWriteNoPermissionError || error.code == NSFileNoSuchFileError) {
                throw AppError.permissionDenied(
                    "保存先へのアクセス権限がありません",
                    message: "macOS のセキュリティ設定により、保存先ディレクトリへのアクセスが拒否されました。\n\n対処方法：\n1. システム設定 > プライバシーとセキュリティ > フルディスクアクセス\n2. 「+」ボタンをクリックし、PlayCover Manager を追加\n3. アプリを再起動してください\n\nパス: \(parentDir.path)"
                )
            }
            throw error
        }
        
        // Test write permission by creating a temp file
        let testFile = parentDir.appendingPathComponent(".playcover_test_\(UUID().uuidString)")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
        } catch {
            throw AppError.permissionDenied(
                "保存先に書き込み権限がありません",
                message: "ディレクトリは作成できましたが、ファイルの書き込みテストに失敗しました。\n\n対処方法：\n• 設定画面で別の保存先を選択してください\n• 外部ドライブの場合、マウントされているか確認してください\n• ドライブが読み取り専用でないか確認してください\n\nパス: \(parentDir.path)\nエラー: \(error.localizedDescription)"
            )
        }
        
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
            let filesystem: String
            switch settings.diskImageFormat {
            case .sparse:
                typeFlag = "SPARSE"
                filesystem = "APFS"
            case .sparseBundle:
                typeFlag = "SPARSEBUNDLE"
                filesystem = "APFS"
            case .sparseHFS:
                typeFlag = "SPARSE"
                filesystem = "HFS+J"
            case .asif:
                typeFlag = "ASIF" // unreachable
                filesystem = "APFS"
            }
            
            // Check if parent directory filesystem is APFS (required for APFS sparse images)
            if settings.diskImageFormat.requiresAPFS {
                let parentURL = imageURL.deletingLastPathComponent()
                do {
                    let resourceValues = try parentURL.resourceValues(forKeys: [.volumeURLKey])
                    if let volumeURL = resourceValues.volume as? URL {
                        let result = try? processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", volumeURL.path])
                        if let data = result?.stdout.data(using: String.Encoding.utf8),
                           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                           let filesystemType = plist["FilesystemType"] as? String {
                            
                            if filesystemType != "apfs" {
                                throw AppError.diskImage(
                                    "APFS ディスクイメージを作成できません",
                                    message: "保存先のファイルシステムが \(filesystemType) です。APFS 形式が選択されていますが、保存先が APFS でないため作成できません。設定で「スパース HFS+（互換性重視）」を選択するか、APFS ボリュームを保存先に指定してください。"
                                )
                            }
                        }
                    }
                } catch {
                    // Volume info not available, proceed anyway
                }
            }
            
            var args: [String] = [
                "create",
                "-size", "50g",
                "-type", typeFlag,
                "-fs", filesystem,
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
        
        // ASIF requires diskutil, legacy formats use hdiutil
        let command: String
        var args: [String]
        
        if settings.diskImageFormat == .asif {
            // diskutil image attach <image> --mountPoint <path> --mountOptions owners [--nobrowse]
            command = "/usr/sbin/diskutil"
            args = ["image", "attach", imageURL.path, "--mountPoint", mountPoint.path, "--mountOptions", "owners"]
            if nobrowse {
                args.append("--nobrowse")
            }
        } else {
            // hdiutil attach <image> -mountpoint <path> -owners on [-nobrowse]
            command = "/usr/bin/hdiutil"
            args = ["attach", imageURL.path, "-mountpoint", mountPoint.path, "-owners", "on"]
            if nobrowse {
                args.append("-nobrowse")
            }
        }
        
        do {
            _ = try await processRunner.run(command, args)
        } catch let error as ProcessRunnerError {
            if case .commandFailed(_, let exitCode, let stderr) = error, exitCode == 1 && stderr.contains("アクセス権がありません") {
                throw AppError.permissionDenied(
                    "マウント先へのアクセス権限がありません",
                    message: "~/Library/Containers/ へのマウントには「フルディスクアクセス」権限が必要です。\n\n対処方法：\n1. システム設定を開く（⌘Space で「システム設定」を検索）\n2. プライバシーとセキュリティ > フルディスクアクセス\n3. 「+」ボタンで PlayCover Manager を追加\n4. アプリを再起動してください\n\nマウント先: \(mountPoint.path)"
                )
            }
            throw error
        }
    }

    func mountTemporarily(for bundleIdentifier: String, temporaryMountBase: URL) async throws -> URL {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        let tempMountPoint = temporaryMountBase.appendingPathComponent(bundleIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: tempMountPoint, withIntermediateDirectories: true)
        
        // ASIF requires diskutil, legacy formats use hdiutil
        let command: String
        let args: [String]
        
        if settings.diskImageFormat == .asif {
            command = "/usr/sbin/diskutil"
            args = ["image", "attach", imageURL.path, "--mountPoint", tempMountPoint.path, "--mountOptions", "owners", "--nobrowse"]
        } else {
            command = "/usr/bin/hdiutil"
            args = ["attach", imageURL.path, "-mountpoint", tempMountPoint.path, "-owners", "on", "-nobrowse"]
        }
        
        _ = try await processRunner.run(command, args)
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
