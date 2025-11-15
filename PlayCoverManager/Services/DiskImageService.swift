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
            // Swift 6.2: Use FileManager extension
            try fileManager.createDirectoryIfNeeded(at: parentDir)
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
        // Swift 6.2: Use FileManager extension
        try fileManager.createDirectoryIfNeeded(at: mountPoint)
        
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
        // Swift 6.2: Use FileManager extension
        try fileManager.createDirectoryIfNeeded(at: tempMountPoint)
        
        // Mount ASIF image using diskutil
        let args = ["image", "attach", imageURL.path, "--mountPoint", tempMountPoint.path, "--nobrowse"]
        _ = try await processRunner.run("/usr/sbin/diskutil", args)
        return tempMountPoint
    }

    func detach(volumeURL: URL) async throws {
        // Use diskutil unmount for ASIF images with force flag
        _ = try await processRunner.run("/usr/sbin/diskutil", ["unmount", "force", volumeURL.path])
    }

    // Swift 6.2: Parallel detach with TaskGroup for performance
    func detachAll(volumeURLs: [URL]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in volumeURLs {
                group.addTask { [self] in
                    do {
                        try await self.detach(volumeURL: url)
                    } catch {
                        throw AppError.diskImage(String(localized: "ディスクイメージのアンマウントに失敗"), message: url.path, underlying: error)
                    }
                }
            }
            
            // Wait for all detach operations to complete
            try await group.waitForAll()
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
        // Swift 6.2: Use FileManager extension
        try fileManager.createDirectoryIfNeeded(at: mountPoint)
        
        // Mount ASIF disk image using diskutil (mounts read-write by default)
        // Use longer timeout for slow storage (180s)
        let timeout: TimeInterval = 180
        
        var args = ["image", "attach", imageURL.path, "--mountPoint", mountPoint.path]
        if nobrowse {
            args.append("--nobrowse")
        }
        
        Logger.diskImage("Running: diskutil \(args.joined(separator: " ")) (timeout: \(Int(timeout))s)")
        
        do {
            _ = try await processRunner.run("/usr/sbin/diskutil", args, timeout: timeout)
        } catch let error as ProcessRunnerError {
            if case .timeout(let seconds) = error {
                Logger.error("Mount timed out after \(seconds)s - storage may be too slow")
                throw AppError.diskImage(
                    String(localized: "マウントがタイムアウトしました"),
                    message: String(localized: "ストレージの応答が遅すぎます。\n\nより高速なストレージ（SSD）の使用を推奨します。"),
                    underlying: error
                )
            }
            throw error
        }
    }
    
    func unmountVolume(_ volumeURL: URL) async throws {
        try await detach(volumeURL: volumeURL)
    }
    
    // MARK: - External Drive Operations
    
    /// Check if a volume is mounted
    /// - Parameter url: URL to check
    /// - Returns: true if the volume is mounted
    func isMounted(at url: URL) throws -> Bool {
        // Use statfs to check mount status - more reliable than diskutil
        var stat = statfs()
        let result = statfs(url.path, &stat)
        
        if result == 0 {
            // Successfully got file system stats
            // Check if this is a mount point by comparing device IDs with parent
            let parentURL = url.deletingLastPathComponent()
            var parentStat = statfs()
            let parentResult = statfs(parentURL.path, &parentStat)
            
            if parentResult == 0 {
                // If device IDs differ, this is a mount point
                return stat.f_fsid.val.0 != parentStat.f_fsid.val.0 || 
                       stat.f_fsid.val.1 != parentStat.f_fsid.val.1
            }
        }
        
        // Fallback to diskutil if statfs fails
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
        
        // Get device identifier for the volume (with timeout)
        let infoOutput = try? await processRunner.run("/usr/sbin/diskutil", ["info", "-plist", volumePath.path], timeout: 30)
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
        // Use longer timeout for slow storage (180s) vs fast storage (60s)
        let timeout: TimeInterval = 180
        
        do {
            var args = ["eject", parentDevice]
            if force {
                args.append("-force")
            }
            Logger.diskImage("Running: diskutil \(args.joined(separator: " ")) (timeout: \(Int(timeout))s)")
            let output = try await processRunner.run("/usr/sbin/diskutil", args, timeout: timeout)
            Logger.diskImage("Eject succeeded: \(output)")
        } catch let error as ProcessRunnerError {
            if case .timeout(let seconds) = error {
                Logger.error("Eject timed out after \(seconds)s - storage may be too slow")
                throw AppError.diskImage(
                    String(localized: "アンマウントがタイムアウトしました"),
                    message: String(localized: "ストレージの応答が遅すぎます。\n\nより高速なストレージ（SSD）の使用を推奨します。"),
                    underlying: error
                )
            }
            Logger.error("Eject failed: \(error)")
            throw error
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
    
    // MARK: - Storage Type Detection
    
    /// Detect storage type (SSD, HDD, etc.) for a given path
    func detectStorageType(for url: URL) async throws -> StorageType {
        // Get device path for the volume
        guard let devicePath = try? await getDevicePath(for: url) else {
            return .unknown
        }
        
        // Extract disk identifier (e.g., disk1 from /dev/disk1s1)
        let diskID = devicePath.replacingOccurrences(of: "/dev/", with: "").replacingOccurrences(of: "s[0-9]+$", with: "", options: .regularExpression)
        
        // Use diskutil info to get device characteristics
        let output = try await processRunner.run("/usr/sbin/diskutil", ["info", diskID])
        
        // Extract protocol information
        let protocolInfo = extractProtocolInfo(from: output)
        
        // Check if it's a network volume first
        if output.contains("Protocol:") && (output.contains("SMB") || output.contains("NFS") || output.contains("AFP")) {
            return .network(protocol: protocolInfo)
        }
        
        // Check USB connection speed (reject USB 2.0 or lower)
        if output.contains("USB") {
            let usbSpeed = try? await detectUSBSpeed(for: diskID)
            if usbSpeed == .usb1 || usbSpeed == .usb2 {
                return .usbSlow(usbSpeed ?? .usb2)
            }
        }
        
        // Check if it's SSD
        if output.contains("Solid State:") {
            if output.range(of: "Solid State:\\s+Yes", options: .regularExpression) != nil {
                return .ssd(protocol: protocolInfo)
            } else if output.range(of: "Solid State:\\s+No", options: .regularExpression) != nil {
                return .hdd(protocol: protocolInfo)
            }
        }
        
        // Default to HDD for unknown solid state status
        return .hdd(protocol: protocolInfo)
    }
    
    /// Extract protocol information from diskutil output
    private func extractProtocolInfo(from output: String) -> String? {
        // Look for "Protocol:" line
        // Examples: "Protocol: SATA", "Protocol: USB", "Protocol: PCI-Express"
        if let range = output.range(of: "Protocol:\\s*(.+)", options: .regularExpression) {
            let line = String(output[range])
            let protocolValue = line.replacingOccurrences(of: "Protocol:", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            return protocolValue.isEmpty ? nil : protocolValue
        }
        return nil
    }
    
    /// Detect USB connection speed using system_profiler
    /// - Parameter diskID: Disk identifier (e.g., disk2, disk11)
    /// - Returns: USB speed classification
    private func detectUSBSpeed(for diskID: String) async throws -> USBSpeed {
        // Use system_profiler to get accurate USB speed information
        // This provides "Speed: 480 Mb/s" (USB 2.0) or "Speed: 5 Gb/s" (USB 3.0) etc.
        let output = try await processRunner.run("/usr/sbin/system_profiler", ["SPUSBDataType"])
        
        Logger.storage("USB速度検出開始: デバイス \(diskID)")
        
        // Look for the device entry and its associated speed
        // Example output:
        //   Portable SSD:
        //     ...
        //     BSD Name: disk2
        //     Speed: Up to 5 Gb/s
        
        // Split output into lines
        let lines = output.components(separatedBy: .newlines)
        var speedMbps: Double = 0
        var deviceIndex: Int? = nil
        var deviceSection: [String] = []
        
        // Debug: Log all lines containing "BSD Name:" or the disk ID
        Logger.storage("デバッグ: BSD Name を含む行を検索中...")
        for (index, line) in lines.enumerated() {
            if line.contains("BSD Name:") {
                Logger.storage("  行\(index): \(line.trimmingCharacters(in: .whitespaces))")
            }
        }
        
        // First, find the line with BSD Name
        for (index, line) in lines.enumerated() {
            if line.contains("BSD Name:") && line.contains(diskID) {
                deviceIndex = index
                Logger.storage("デバイス発見: \(line.trimmingCharacters(in: .whitespaces))")
                break
            }
        }
        
        guard let devIndex = deviceIndex else {
            Logger.storage("警告: デバイスが見つかりませんでした。検索対象: '\(diskID)'")
            // Try alternative: search for any mass storage device with Speed info
            return try await detectUSBSpeedFallback(from: output)
        }
        
        // Search backwards from device to find the parent USB bus speed
        // The speed is typically listed in the parent device or bus section
        for index in stride(from: devIndex, through: 0, by: -1) {
            let line = lines[index]
            deviceSection.insert(line, at: 0)
            
            if line.contains("Speed:") {
                Logger.storage("速度情報発見: \(line.trimmingCharacters(in: .whitespaces))")
                
                // Extract speed value
                // Patterns: "Speed: 480 Mb/s", "Speed: Up to 5 Gb/s", "Speed: 10 Gb/s"
                if let speedRange = line.range(of: "([0-9.]+)\\s*(Mb/s|Gb/s)", options: .regularExpression) {
                    let speedString = String(line[speedRange])
                    Logger.storage("抽出した速度文字列: \(speedString)")
                    
                    if speedString.contains("Gb/s") {
                        // Convert Gb/s to Mb/s
                        let numericString = speedString.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
                        if let value = Double(numericString) {
                            speedMbps = value * 1000
                            Logger.storage("Gb/s -> Mb/s 変換: \(value) Gb/s = \(speedMbps) Mb/s")
                        }
                    } else if speedString.contains("Mb/s") {
                        let numericString = speedString.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
                        if let value = Double(numericString) {
                            speedMbps = value
                            Logger.storage("Mb/s 速度: \(speedMbps) Mb/s")
                        }
                    }
                }
                break
            }
        }
        
        // Log device section if speed not found
        if speedMbps == 0 {
            Logger.storage("警告: 速度情報が見つかりませんでした。デバイスセクション:")
            deviceSection.forEach { Logger.storage("  \($0)") }
            // If speed not found, assume USB 3.0+ (better to allow than block)
            return .usb3OrHigher
        }
        
        // Classify based on speed
        // USB 1.x: up to 12 Mb/s
        // USB 2.0: 480 Mb/s
        // USB 3.0: 5000 Mb/s (5 Gb/s)
        // USB 3.1+: 10000+ Mb/s (10+ Gb/s)
        
        Logger.storage("最終速度: \(speedMbps) Mb/s")
        
        if speedMbps < 100 {
            Logger.storage("判定: USB 1.x")
            return .usb1
        } else if speedMbps <= 480 {
            Logger.storage("判定: USB 2.0")
            return .usb2
        } else {
            Logger.storage("判定: USB 3.0以上")
            return .usb3OrHigher
        }
    }
    
    /// Fallback USB speed detection when BSD Name is not found
    /// Looks for any USB Mass Storage device with Speed information
    private func detectUSBSpeedFallback(from output: String) async throws -> USBSpeed {
        Logger.storage("フォールバック: 全USBストレージデバイスの速度を確認")
        
        let lines = output.components(separatedBy: .newlines)
        var maxSpeedMbps: Double = 0
        
        // Look for any "Mass Storage" or similar device with Speed info
        var inStorageDevice = false
        for line in lines {
            // Check if we're in a storage-related device section
            if line.range(of: "Mass Storage|Storage|SSD|USB.*Disk", options: .regularExpression) != nil {
                inStorageDevice = true
                Logger.storage("ストレージデバイスセクション発見: \(line.trimmingCharacters(in: .whitespaces))")
            }
            
            // Reset when we move to a new top-level device
            if !line.hasPrefix(" ") && !line.isEmpty && !line.contains("USB") {
                inStorageDevice = false
            }
            
            // Extract speed if we're in a storage device section
            if inStorageDevice && line.contains("Speed:") {
                if let speedRange = line.range(of: "([0-9.]+)\\s*(Mb/s|Gb/s)", options: .regularExpression) {
                    let speedString = String(line[speedRange])
                    var speedMbps: Double = 0
                    
                    if speedString.contains("Gb/s") {
                        let numericString = speedString.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
                        if let value = Double(numericString) {
                            speedMbps = value * 1000
                        }
                    } else if speedString.contains("Mb/s") {
                        let numericString = speedString.components(separatedBy: CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ".")).inverted).joined()
                        if let value = Double(numericString) {
                            speedMbps = value
                        }
                    }
                    
                    if speedMbps > maxSpeedMbps {
                        maxSpeedMbps = speedMbps
                        Logger.storage("フォールバック速度更新: \(speedMbps) Mb/s")
                    }
                }
            }
        }
        
        if maxSpeedMbps == 0 {
            Logger.storage("フォールバック失敗: 速度情報が見つかりません。USB 3.0+と仮定")
            return .usb3OrHigher
        }
        
        Logger.storage("フォールバック最終速度: \(maxSpeedMbps) Mb/s")
        
        if maxSpeedMbps < 100 {
            return .usb1
        } else if maxSpeedMbps <= 480 {
            return .usb2
        } else {
            return .usb3OrHigher
        }
    }
    
    /// USB connection speed
    enum USBSpeed {
        case usb1
        case usb2
        case usb3OrHigher
        case unknown
    }
    
    /// Storage type enumeration
    enum StorageType {
        case ssd(protocol: String?)  // SSD with optional protocol info
        case hdd(protocol: String?)  // HDD with optional protocol info
        case network(protocol: String?)  // Network drive with protocol
        case usbSlow(USBSpeed)  // USB 1.0 or 2.0 (prohibited)
        case unknown
        
        var localizedDescription: String {
            switch self {
            case .ssd(let proto):
                if let proto = proto {
                    return "SSD (\(proto))"
                }
                return "SSD"
            case .hdd(let proto):
                if let proto = proto {
                    return "HDD (\(proto))"
                }
                return "HDD"
            case .network(let proto):
                if let proto = proto {
                    return "ネットワークドライブ (\(proto))"
                }
                return "ネットワークドライブ"
            case .usbSlow(let speed):
                switch speed {
                case .usb1:
                    return "USB 1.0（非対応）"
                case .usb2:
                    return "USB 2.0（非対応）"
                default:
                    return "USB（低速・非対応）"
                }
            case .unknown:
                return "不明"
            }
        }
        
        var isSlow: Bool {
            switch self {
            case .ssd:
                return false
            case .hdd, .network, .usbSlow, .unknown:
                return true
            }
        }
        
        var isProhibited: Bool {
            switch self {
            case .usbSlow(let speed):
                return speed == .usb1 || speed == .usb2
            default:
                return false
            }
        }
        
        var prohibitedReason: String? {
            switch self {
            case .usbSlow(let speed):
                if speed == .usb1 || speed == .usb2 {
                    return String(localized: "USB 2.0以下の接続は遅すぎるため使用できません。\n\nUSB 3.0以上の接続、または内蔵ストレージをご使用ください。")
                }
            default:
                break
            }
            return nil
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
