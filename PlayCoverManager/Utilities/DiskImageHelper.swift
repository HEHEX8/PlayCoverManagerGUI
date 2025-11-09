//
//  DiskImageHelper.swift
//  PlayCoverManager
//
//  Common utilities for disk image operations
//

import Foundation

/// Utility class for common disk image operations
@MainActor
final class DiskImageHelper {
    
    // MARK: - Nobrowse Settings
    
    /// Get nobrowse setting for a specific app, falling back to global default
    static func getNobrowseSetting(
        for bundleID: String,
        perAppSettings: PerAppSettingsStore,
        globalSettings: SettingsStore
    ) -> Bool {
        return perAppSettings.getNobrowse(for: bundleID, globalDefault: globalSettings.nobrowseEnabled)
    }
    
    // MARK: - Disk Image State
    
    /// Check if disk image exists and is mounted
    static func checkDiskImageState(
        for bundleID: String,
        containerURL: URL,
        diskImageService: DiskImageService
    ) throws -> DiskImageState {
        let descriptor = try diskImageService.diskImageDescriptor(for: bundleID, containerURL: containerURL)
        
        let imageExists = FileManager.default.fileExists(atPath: descriptor.imageURL.path)
        
        return DiskImageState(
            descriptor: descriptor,
            imageExists: imageExists,
            isMounted: descriptor.isMounted
        )
    }
    
    // MARK: - Mount Preparation
    
    /// Prepare and mount disk image with internal data detection
    /// Returns true if ready to launch, false if user interaction needed
    static func prepareAndMountDiskImage(
        for bundleID: String,
        containerURL: URL,
        diskImageService: DiskImageService,
        perAppSettings: PerAppSettingsStore,
        globalSettings: SettingsStore,
        detectInternalData: (URL) throws -> [URL],
        onInternalDataFound: ([URL]) -> Void
    ) async throws -> Bool {
        let state = try checkDiskImageState(
            for: bundleID,
            containerURL: containerURL,
            diskImageService: diskImageService
        )
        
        guard state.imageExists else {
            throw AppError.diskImage(String(localized: "ディスクイメージが見つかりません"), message: "先にディスクイメージを作成してください。")
        }
        
        // Check for internal data if not mounted
        if !state.isMounted {
            let internalItems = try detectInternalData(containerURL)
            if !internalItems.isEmpty {
                onInternalDataFound(internalItems)
                return false // Need user interaction
            }
        }
        
        // Mount if not already mounted
        if !state.isMounted {
            let nobrowse = getNobrowseSetting(
                for: bundleID,
                perAppSettings: perAppSettings,
                globalSettings: globalSettings
            )
            try await diskImageService.mountDiskImage(for: bundleID, at: containerURL, nobrowse: nobrowse)
        }
        
        return true // Ready to launch
    }
    
    // MARK: - Simple Mount
    
    /// Mount disk image without internal data detection (for debug console, etc.)
    static func mountDiskImageIfNeeded(
        for bundleID: String,
        containerURL: URL,
        diskImageService: DiskImageService,
        perAppSettings: PerAppSettingsStore,
        globalSettings: SettingsStore
    ) async throws {
        let state = try checkDiskImageState(
            for: bundleID,
            containerURL: containerURL,
            diskImageService: diskImageService
        )
        
        guard state.imageExists else {
            throw AppError.diskImage(String(localized: "ディスクイメージが見つかりません"), message: "Bundle ID: \(bundleID)")
        }
        
        if !state.isMounted {
            let nobrowse = getNobrowseSetting(
                for: bundleID,
                perAppSettings: perAppSettings,
                globalSettings: globalSettings
            )
            try await diskImageService.mountDiskImage(for: bundleID, at: containerURL, nobrowse: nobrowse)
        }
    }
    
    // MARK: - Unmount with Lock Check
    
    /// Safely unmount disk image with lock checking
    static func unmountDiskImageSafely(
        for bundleID: String,
        containerURL: URL,
        diskImageService: DiskImageService,
        lockService: ContainerLockService,
        force: Bool = false
    ) async throws {
        Logger.diskImage("unmountDiskImageSafely called for \(bundleID)")
        
        // Release our lock first
        await lockService.unlockContainer(for: bundleID)
        Logger.diskImage("Released our lock for \(bundleID)")
        
        // Check if mounted
        let descriptor = try? diskImageService.diskImageDescriptor(for: bundleID, containerURL: containerURL)
        guard let descriptor = descriptor, descriptor.isMounted else {
            Logger.diskImage("Container not mounted, nothing to do")
            return
        }
        
        Logger.diskImage("Container is mounted, checking locks...")
        
        // Check if another process has a lock (unless forcing)
        if !force {
            let canLock = await lockService.canLockContainer(for: bundleID, at: containerURL)
            if !canLock {
                Logger.diskImage("Another process has a lock, aborting unmount")
                // Another process is using this container
                return
            }
            Logger.diskImage("No other locks, proceeding with unmount")
        }
        
        // Unmount
        Logger.diskImage("Calling ejectDiskImage...")
        try await diskImageService.ejectDiskImage(for: containerURL, force: force)
        Logger.diskImage("ejectDiskImage completed successfully")
    }
    
    // MARK: - Two-Stage Unmount
    
    /// Result of unmount operation
    enum UnmountResult {
        case success
        case failed(Error)  // Simplified: both normal and force failed
    }
    
    /// Try two-stage unmount with app termination: 
    /// 1. Try normal eject
    /// 2. If fails, terminate app normally (SIGTERM) and retry
    /// 3. If still fails, force terminate app (SIGKILL) and force eject
    /// Returns result indicating success or failure
    static func unmountWithTwoStageEject(
        containerURL: URL,
        diskImageService: DiskImageService,
        bundleID: String? = nil,
        launcherService: LauncherService? = nil
    ) async -> UnmountResult {
        // Synchronize preferences if bundleID provided
        if let bundleID = bundleID {
            Logger.diskImage("Synchronizing preferences for \(bundleID)")
            CFPreferencesAppSynchronize(bundleID as CFString)
        }
        
        // Stage 1: Try normal eject
        Logger.diskImage("Stage 1 - Attempting normal eject for \(containerURL.path)")
        do {
            try await diskImageService.ejectDiskImage(for: containerURL, force: false)
            Logger.diskImage("Stage 1 - Normal eject succeeded")
            return .success
        } catch let normalError {
            Logger.diskImage("Stage 1 - Normal eject failed: \(normalError)")
            
            // Stage 2: If app is provided and running, terminate it normally
            if let bundleID = bundleID, 
               let launcherService = launcherService,
               launcherService.isAppRunning(bundleID: bundleID) {
                Logger.diskImage("Stage 2 - App \(bundleID) is running, sending SIGTERM")
                _ = launcherService.terminateApp(bundleID: bundleID)
                
                // Wait a bit for graceful shutdown
                try? await Task.sleep(for: .seconds(2))
                
                // Retry normal eject after app termination
                Logger.diskImage("Stage 2 - Retrying normal eject after SIGTERM")
                do {
                    try await diskImageService.ejectDiskImage(for: containerURL, force: false)
                    Logger.diskImage("Stage 2 - Normal eject succeeded after SIGTERM")
                    return .success
                } catch {
                    Logger.diskImage("Stage 2 - Normal eject still failed after SIGTERM: \(error)")
                }
            }
            
            // Stage 3: Force terminate app if still running, then force eject
            if let bundleID = bundleID,
               let launcherService = launcherService,
               launcherService.isAppRunning(bundleID: bundleID) {
                Logger.diskImage("Stage 3 - App \(bundleID) still running, sending SIGKILL")
                _ = launcherService.forceTerminateApp(bundleID: bundleID)
                
                // Wait a bit for forced shutdown
                try? await Task.sleep(for: .seconds(1))
            }
            
            // Final attempt: Force eject
            Logger.diskImage("Stage 3 - Attempting force eject")
            do {
                try await diskImageService.ejectDiskImage(for: containerURL, force: true)
                Logger.diskImage("Stage 3 - Force eject succeeded")
                return .success
            } catch let forceError {
                Logger.error("Stage 3 - Force eject also failed: \(forceError)")
                return .failed(forceError)
            }
        }
    }
    
    // MARK: - App Directory Discovery
    
    /// Find all .app directories in a given directory
    static func findAppDirectories(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return []
        }
        
        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        
        return contents.filter { $0.pathExtension == "app" }
    }
}

// MARK: - Supporting Types

struct DiskImageState {
    let descriptor: DiskImageDescriptor
    let imageExists: Bool
    let isMounted: Bool
}
