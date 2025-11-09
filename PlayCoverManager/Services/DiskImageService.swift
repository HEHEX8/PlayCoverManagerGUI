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

/// Swift 6.2 Optimizations:
/// - Service architecture follows Swift 6.2 best practices for non-actor services
/// - Methods are designed to work with caller's execution context
/// - Heavy I/O operations can be wrapped with @concurrent when needed
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
            throw AppError.diskImage(String(localized: "ディスクイメージの保存先が未設定"), message: "設定画面から保存先を指定してください。")
        }
        // ASIF format only (macOS Tahoe 26.0+)
        return base.appendingPathComponent("\(bundleIdentifier).asif")
    }

    func diskImageDescriptor(for bundleIdentifier: String, containerURL: URL) throws -> DiskImageDescriptor {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        let exists = fileManager.fileExists(atPath: imageURL.path)
        let mountPoint = containerURL

        // Determine if mountPoint is currently a mounted volume by asking diskutil synchronously
        var isMounted = false
        var volumePath: URL? = nil
        do {
            let output = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", mountPoint.path])
            if let plist = output.parsePlist(),
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

    func ensureDiskImageExists(for bundleIdentifier: String, volumeName: String? = nil, customSizeGB: Int? = nil) async throws -> URL {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        Logger.diskImage("Checking disk image existence: \(imageURL.path)")
        if fileManager.fileExists(atPath: imageURL.path) {
            Logger.diskImage("Disk image already exists")
            return imageURL
        }
        Logger.diskImage("Disk image not found, creating new image")
        
        // Verify parent directory is accessible and writable
        let parentDir = imageURL.deletingLastPathComponent()
        Logger.debug("Verifying parent directory: \(parentDir.path)")
        
        // Try to create directory - this will fail if we don't have access
        do {
            try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        } catch let error as NSError {
            Logger.error("Failed to create parent directory: \(error)")
            if error.domain == NSCocoaErrorDomain && (error.code == NSFileWriteNoPermissionError || error.code == NSFileNoSuchFileError) {
                throw AppError.permissionDenied(
                    String(localized: "保存先へのアクセス権限がありません"),
                    message: String(localized: "macOS のセキュリティ設定により、保存先ディレクトリへのアクセスが拒否されました。\n\n対処方法：\n1. システム設定 > プライバシーとセキュリティ > フルディスクアクセス\n2. 「+」ボタンをクリックし、PlayCover Manager を追加\n3. アプリを再起動してください\n\nパス: \(parentDir.path)")
                )
            }
            throw error
        }
        
        // Test write permission by creating a temp file
        let testFile = parentDir.appendingPathComponent(".playcover_test_\(UUID().uuidString)")
        Logger.debug("Testing write permission with temp file")
        do {
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try fileManager.removeItem(at: testFile)
            Logger.debug("Write permission test passed")
        } catch {
            Logger.error("Write permission test failed: \(error)")
            throw AppError.permissionDenied(
                String(localized: "保存先に書き込み権限がありません"),
                message: String(localized: "ディレクトリは作成できましたが、ファイルの書き込みテストに失敗しました。\n\n対処方法：\n• 設定画面で別の保存先を選択してください\n• 外部ドライブの場合、マウントされているか確認してください\n• ドライブが読み取り専用でないか確認してください\n\nパス: \(parentDir.path)\nエラー: \(error.localizedDescription)")
            )
        }
        
        let volName = volumeName ?? bundleIdentifier
        
        // Fixed 1TB size for all disk images (ASIF cannot be resized after creation)
        // Use customSizeGB only if explicitly provided (for special cases)
        let imageSize: String
        if let customSize = customSizeGB {
            imageSize = "\(customSize)G"
        } else {
            imageSize = "1T"  // 1 TB for all containers (unified size)
        }
        
        // Create ASIF disk image using diskutil (macOS Tahoe 26.0+ only)
        Logger.diskImage("Creating ASIF disk image: size=\(imageSize), volume=\(volName)")
        let args = [
            "image", "create", "blank",
            "--format", "ASIF",
            "--size", imageSize,
            "--volumeName", volName,
            imageURL.path
        ]
        _ = try await Logger.measureAsync("Create disk image") {
            try await processRunner.run("/usr/sbin/diskutil", args)
        }
        Logger.diskImage("Successfully created disk image at \(imageURL.path)")
        return imageURL
    }

    func mountDiskImage(for bundleIdentifier: String, at mountPoint: URL, nobrowse: Bool) async throws {
        Logger.diskImage("Mounting disk image for \(bundleIdentifier) at \(mountPoint.path)")
        let imageURL = try diskImageURL(for: bundleIdentifier)
        guard fileManager.fileExists(atPath: imageURL.path) else {
            Logger.error("Disk image not found: \(imageURL.path)")
            throw AppError.diskImage(String(localized: "ディスクイメージが見つかりません"), message: imageURL.path)
        }
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        
        // Mount ASIF disk image using diskutil (mounts read-write by default)
        var args = ["image", "attach", imageURL.path, "--mountPoint", mountPoint.path]
        if nobrowse {
            args.append("--nobrowse")
            Logger.debug("Mount with nobrowse option")
        }
        
        do {
            _ = try await Logger.measureAsync("Mount disk image") {
                try await processRunner.run("/usr/sbin/diskutil", args)
            }
            Logger.diskImage("Successfully mounted disk image")
        } catch let error as ProcessRunnerError {
            if case .commandFailed(_, let exitCode, let stderr) = error, exitCode == 1 && stderr.contains("アクセス権がありません") {
                throw AppError.permissionDenied(
                    String(localized: "マウント先へのアクセス権限がありません"),
                    message: String(localized: "~/Library/Containers/ へのマウントには「フルディスクアクセス」権限が必要です。\n\n対処方法：\n1. システム設定を開く（⌘Space で「システム設定」を検索）\n2. プライバシーとセキュリティ > フルディスクアクセス\n3. 「+」ボタンで PlayCover Manager を追加\n4. アプリを再起動してください\n\nマウント先: \(mountPoint.path)")
                )
            }
            throw error
        }
    }

    func mountTemporarily(for bundleIdentifier: String, temporaryMountBase: URL) async throws -> URL {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        let tempMountPoint = temporaryMountBase.appendingPathComponent(bundleIdentifier, isDirectory: true)
        try fileManager.createDirectory(at: tempMountPoint, withIntermediateDirectories: true)
        
        // Mount ASIF image using diskutil
        let args = ["image", "attach", imageURL.path, "--mountPoint", tempMountPoint.path, "--nobrowse"]
        _ = try await processRunner.run("/usr/sbin/diskutil", args)
        return tempMountPoint
    }

    func detach(volumeURL: URL) async throws {
        // Use diskutil unmount for ASIF images with force flag
        _ = try await processRunner.run("/usr/sbin/diskutil", ["unmount", "force", volumeURL.path])
    }

    func detachAll(volumeURLs: [URL]) async throws {
        for url in volumeURLs {
            do {
                try await detach(volumeURL: url)
            } catch {
                throw AppError.diskImage(String(localized: "ディスクイメージのアンマウントに失敗"), message: url.path, underlying: error)
            }
        }
    }
    
    // Convenience methods for IPAInstallerService compatibility
    func createDiskImage(at imageURL: URL, volumeName: String, size: String? = nil, sizeGB: Int? = nil) async throws {
        let parentDir = imageURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        // Determine size: explicit size string > sizeGB parameter > default from settings
        let finalSize: String
        if let size = size {
            finalSize = size
        } else if let sizeGB = sizeGB {
            finalSize = "\(sizeGB)G"
        } else {
            finalSize = "\(settings.defaultDiskImageSizeGB)G"
        }
        
        // Create ASIF disk image using diskutil (macOS Tahoe 26.0+ only)
        let args = [
            "image", "create", "blank",
            "--format", "ASIF",
            "--size", finalSize,
            "--volumeName", volumeName,
            imageURL.path
        ]
        _ = try await processRunner.run("/usr/sbin/diskutil", args)
    }
    
    func mountDiskImage(_ imageURL: URL, at mountPoint: URL, nobrowse: Bool) async throws {
        guard fileManager.fileExists(atPath: imageURL.path) else {
            throw AppError.diskImage(String(localized: "ディスクイメージが見つかりません"), message: imageURL.path)
        }
        try fileManager.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        
        // Mount ASIF disk image using diskutil (mounts read-write by default)
        var args = ["image", "attach", imageURL.path, "--mountPoint", mountPoint.path]
        if nobrowse {
            args.append("--nobrowse")
        }
        
        _ = try await processRunner.run("/usr/sbin/diskutil", args)
    }
    
    func unmountVolume(_ volumeURL: URL) async throws {
        try await detach(volumeURL: volumeURL)
    }
    
    // MARK: - External Drive Operations
    
    /// Check if a volume is mounted
    /// - Parameter url: URL to check
    /// - Returns: true if the volume is mounted
    func isMounted(at url: URL) throws -> Bool {
        do {
            let output = try processRunner.runSync("/usr/sbin/diskutil", ["info", "-plist", url.path])
            if let plist = output.parsePlist(),
               let _ = plist["VolumeName"] as? String {
                return true
            }
        } catch {
            return false
        }
        return false
    }
    
    /// Check if a volume is on external/removable media
    /// - Parameter url: URL to check
    /// - Returns: true if the volume is external
    func isExternalDrive(_ url: URL) async throws -> Bool {
        // If the path is a subdirectory, find the mount point first
        var currentPath = url
        
        // Walk up the directory tree to find the actual mount point
        while currentPath.path != "/" {
            let output = try? await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", currentPath.path])
            if let output = output,
               let plist = output.parsePlist() {
                
                // Check if it's removable media
                if let isInternal = plist["Internal"] as? Bool {
                    return !isInternal
                }
            }
            
            // Move up one directory
            currentPath = currentPath.deletingLastPathComponent()
        }
        
        return false
    }
    
    /// Get device path for a volume
    /// - Parameter url: URL to check
    /// - Returns: Device path (e.g., /dev/disk2) or nil
    func getDevicePath(for url: URL) async throws -> String? {
        // If the path is a subdirectory, find the mount point first
        var currentPath = url
        var deviceNode: String?
        
        // Walk up the directory tree to find the actual mount point
        while currentPath.path != "/" {
            let output = try? await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", currentPath.path])
            if let output = output,
               let plist = output.parsePlist(),
               let node = plist["DeviceNode"] as? String {
                deviceNode = node
                break
            }
            
            // Move up one directory
            currentPath = currentPath.deletingLastPathComponent()
        }
        
        return deviceNode
    }
    
    /// Information about a volume and its parent device
    struct VolumeInfo {
        let volumeName: String
        let deviceName: String?
        let mediaName: String?
        
        /// Display name prioritizing device/media name over volume name
        var displayName: String {
            // Prefer media name (e.g., "WD_BLACK SN7100 4TB Media")
            if let media = mediaName, !media.isEmpty {
                return media
            }
            // Fall back to device name
            if let device = deviceName, !device.isEmpty {
                return device
            }
            // Last resort: volume name
            return volumeName
        }
    }
    
    /// Get volume info for a path (walks up directory tree to find actual mount point)
    /// - Parameter url: Path to check (can be subdirectory)
    /// - Returns: VolumeInfo with volume name and device name, or nil if not found
    func getVolumeInfo(for url: URL) async throws -> VolumeInfo? {
        var currentPath = url
        
        // Walk up the directory tree to find the actual mount point
        while currentPath.path != "/" {
            let output = try? await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", currentPath.path])
            if let output = output,
               let plist = output.parsePlist(),
               let volumeName = plist["VolumeName"] as? String {
                
                // Get device identifier (e.g., "disk5s2")
                let deviceIdentifier = plist["DeviceIdentifier"] as? String
                
                // Get media name from partition's plist
                var mediaName = plist["MediaName"] as? String
                
                // If MediaName is not in partition info, get it from parent disk
                if mediaName == nil || mediaName?.isEmpty == true,
                   let devId = deviceIdentifier {
                    // Extract parent disk (e.g., "disk5" from "disk5s2")
                    let parentDisk: String
                    if let sRange = devId.range(of: "s\\d+$", options: .regularExpression) {
                        parentDisk = String(devId[..<sRange.lowerBound])
                    } else {
                        parentDisk = devId
                    }
                    
                    // Query parent disk for media name
                    if let parentOutput = try? await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", parentDisk]),
                       let parentPlist = parentOutput.parsePlist() {
                        mediaName = parentPlist["MediaName"] as? String
                        
                        // Also try IORegistryEntryName as fallback
                        if mediaName == nil || mediaName?.isEmpty == true {
                            mediaName = parentPlist["IORegistryEntryName"] as? String
                        }
                    }
                }
                
                
                return VolumeInfo(volumeName: volumeName, deviceName: deviceIdentifier, mediaName: mediaName)
            }
            
            // Move up one directory
            currentPath = currentPath.deletingLastPathComponent()
        }
        
        return nil
    }
    
    /// Get volume name for a path (walks up directory tree to find actual mount point)
    /// - Parameter url: Path to check (can be subdirectory)
    /// - Returns: Volume name or nil if not found
    @available(*, deprecated, message: "Use getVolumeInfo(for:) instead")
    func getVolumeName(for url: URL) async throws -> String? {
        return try await getVolumeInfo(for: url)?.volumeName
    }
    
    /// Detach all Apple Disk Image Media devices
    /// This removes the virtual disk devices created by mounted ASIF/DMG images
    /// - Returns: Number of disk images detached
    /// Eject disk image for a specific volume (unmounts all volumes and detaches device)
    /// - Parameters:
    ///   - volumePath: The path of the volume on the disk image
    ///   - force: If true, force unmount even if files are in use (dangerous, use with caution)
    func ejectDiskImage(for volumePath: URL, force: Bool = false) async throws {
        Logger.diskImage("ejectDiskImage called for: \(volumePath.path)")
        
        // Get device identifier for the volume
        let infoOutput = try? await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", volumePath.path])
        guard let infoPlist = infoOutput?.parsePlist(),
              let deviceId = infoPlist["DeviceIdentifier"] as? String else {
            Logger.error("Failed to get device identifier")
            throw AppError.diskImage(String(localized: "デバイスIDの取得に失敗"), message: volumePath.path, underlying: nil)
        }
        
        Logger.diskImage("Device ID: \(deviceId)")
        
        // Get the parent disk image device (e.g., disk4 from disk4s1)
        let parentDevice = deviceId.replacingOccurrences(of: "s\\d+$", with: "", options: [.regularExpression])
        Logger.diskImage("Parent device: \(parentDevice), force: \(force)")
        
        // Eject the parent device (unmounts all volumes and detaches device)
        do {
            var args = ["eject", parentDevice]
            if force {
                args.append("-force")
            }
            Logger.diskImage("Running: diskutil \(args.joined(separator: " "))")
            let output = try await processRunner.run("/usr/sbin/diskutil", args)
            Logger.diskImage("Eject succeeded: \(output)")
        } catch {
            Logger.error("Eject failed: \(error)")
            throw error
        }
    }
    
    func detachAllDiskImages() async throws -> Int {
        // Get list of all disks
        let output = try await processRunner.run("/usr/sbin/diskutil", ["list", "-plist"])
        guard let plist = output.parsePlist(),
              let allDisks = plist["AllDisksAndPartitions"] as? [[String: Any]] else {
            return 0
        }
        
        var detachedCount = 0
        
        // Find all Apple Disk Image Media devices
        for disk in allDisks {
            // Check if this is a disk image
            if let content = disk["Content"] as? String,
               content.contains("Apple") || content.contains("Disk Image"),
               let deviceId = disk["DeviceIdentifier"] as? String {
                
                // Get detailed info to confirm it's a disk image
                let infoOutput = try? await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", deviceId])
                if let infoPlist = infoOutput?.parsePlist() {
                    
                    // Check for Virtual/DiskImage indicators
                    let isVirtual = infoPlist["Virtual"] as? Bool ?? false
                    let mediaName = infoPlist["MediaName"] as? String ?? ""
                    let isDiskImage = mediaName.contains("Disk Image") || isVirtual
                    
                    if isDiskImage {
                        
                        // Try to eject/detach the disk image
                        do {
                            _ = try await processRunner.run("/usr/sbin/diskutil", ["eject", deviceId])
                            detachedCount += 1
                        } catch {
                            // Continue with other disk images
                        }
                    }
                }
            }
        }
        
        return detachedCount
    }
    
    /// Eject a drive
    /// - Parameter devicePath: Device path (e.g., /dev/disk2)
    func ejectDrive(devicePath: String, force: Bool = false) async throws {
        var args = ["eject"]
        if force {
            args.append("-force")
        }
        args.append(devicePath)
        _ = try await processRunner.run("/usr/sbin/diskutil", args)
    }
    
    /// Count mounted volumes under a specific path
    /// - Parameter basePath: Base path to search for mounted volumes (e.g., /Volumes/DATA/PlayCover)
    /// - Returns: Number of mounted volumes found under the base path
    func countMountedVolumes(under basePath: URL) async -> Int {
        do {
            // Get list of all mounted volumes using diskutil
            let output = try await processRunner.run("/usr/sbin/diskutil", ["list", "-plist"])
            guard let plist = output.parsePlist(),
                  let allDisksAndPartitions = plist["AllDisksAndPartitions"] as? [[String: Any]] else {
                return 0
            }
            
            var count = 0
            let basePathString = basePath.path
            
            // Iterate through all disks and their partitions
            for disk in allDisksAndPartitions {
                if let partitions = disk["Partitions"] as? [[String: Any]] {
                    for partition in partitions {
                        if let mountPoint = partition["MountPoint"] as? String,
                           !mountPoint.isEmpty,
                           mountPoint.hasPrefix(basePathString) {
                            count += 1
                        }
                    }
                }
                // Some disks might have direct mount points without partitions array
                if let mountPoint = disk["MountPoint"] as? String,
                   !mountPoint.isEmpty,
                   mountPoint.hasPrefix(basePathString) {
                    count += 1
                }
            }
            
            return count
        } catch {
            return 0
        }
    }
    
    /// Resize an ASIF disk image
    /// - Parameters:
    ///   - bundleIdentifier: Bundle identifier of the app
    ///   - newSizeGB: New size in GB
    /// - Throws: Error if resize fails

    /// Get current size of a disk image
    /// - Parameter bundleIdentifier: Bundle identifier of the app
    /// - Returns: Current size in bytes, or nil if image doesn't exist
    func getDiskImageSize(for bundleIdentifier: String) throws -> UInt64? {
        let imageURL = try diskImageURL(for: bundleIdentifier)
        guard fileManager.fileExists(atPath: imageURL.path) else {
            return nil
        }
        return try? imageURL.totalAllocatedSize()
    }
    
    /// Parse eject error to extract user-friendly information
    /// - Parameter stderr: Standard error output from diskutil eject command
    /// - Returns: Tuple of (volume names, process info) or nil if parsing failed
    func parseEjectError(_ stderr: String) async -> (volumeNames: [String], blockingProcess: String?)? {
        var volumeNames: [String] = []
        var blockingProcess: String? = nil
        
        // Extract PID from error message (e.g., "PID 43014 (/usr/libexec/diskimagesiod)")
        if let pidRange = stderr.range(of: #"PID (\d+) \(([^)]+)\)"#, options: .regularExpression) {
            let match = stderr[pidRange]
            if let processRange = match.range(of: #"\(([^)]+)\)"#, options: .regularExpression) {
                let processPath = match[processRange].dropFirst().dropLast()
                blockingProcess = String(processPath.split(separator: "/").last ?? processPath)
            }
        }
        
        // Extract disk identifier (e.g., "disk5" from "Unmount of disk5 failed")
        var diskIdentifier: String?
        if let diskRange = stderr.range(of: #"Unmount of (disk\d+)"#, options: .regularExpression) {
            let match = stderr[diskRange]
            if let diskMatch = match.split(separator: " ").last {
                diskIdentifier = String(diskMatch)
            }
        }
        
        // If we found a disk identifier, query diskutil to get volume names
        if let diskID = diskIdentifier {
            do {
                let output = try await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", diskID])
                if let plist = output.parsePlist(),
                   let volumeName = plist["VolumeName"] as? String {
                    volumeNames.append(volumeName)
                }
                
                // Also check for partitions on this disk
                let listOutput = try await processRunner.run("/usr/sbin/diskutil", ["list", "-plist", diskID])
                if let listPlist = listOutput.parsePlist(),
                   let allDisks = listPlist["AllDisksAndPartitions"] as? [[String: Any]] {
                    for disk in allDisks {
                        if let partitions = disk["Partitions"] as? [[String: Any]] {
                            for partition in partitions {
                                if let volName = partition["VolumeName"] as? String,
                                   !volName.isEmpty,
                                   !volumeNames.contains(volName) {
                                    volumeNames.append(volName)
                                }
                            }
                        }
                    }
                }
            } catch {
            }
        }
        
        return volumeNames.isEmpty && blockingProcess == nil ? nil : (volumeNames, blockingProcess)
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
