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
            throw AppError.diskImage("ディスクイメージが見つかりません", message: "先にディスクイメージを作成してください。")
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
            throw AppError.diskImage("ディスクイメージが見つかりません", message: "Bundle ID: \(bundleID)")
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
        NSLog("[DEBUG] DiskImageHelper: unmountDiskImageSafely called for \(bundleID)")
        
        // Release our lock first
        await lockService.unlockContainer(for: bundleID)
        NSLog("[DEBUG] DiskImageHelper: Released our lock for \(bundleID)")
        
        // Check if mounted
        let descriptor = try? diskImageService.diskImageDescriptor(for: bundleID, containerURL: containerURL)
        guard let descriptor = descriptor, descriptor.isMounted else {
            NSLog("[DEBUG] DiskImageHelper: Container not mounted, nothing to do")
            return
        }
        
        NSLog("[DEBUG] DiskImageHelper: Container is mounted, checking locks...")
        
        // Check if another process has a lock (unless forcing)
        if !force {
            let canLock = await lockService.canLockContainer(for: bundleID, at: containerURL)
            if !canLock {
                NSLog("[DEBUG] DiskImageHelper: Another process has a lock, aborting unmount")
                // Another process is using this container
                return
            }
            NSLog("[DEBUG] DiskImageHelper: No other locks, proceeding with unmount")
        }
        
        // Unmount
        NSLog("[DEBUG] DiskImageHelper: Calling ejectDiskImage...")
        try await diskImageService.ejectDiskImage(for: containerURL, force: force)
        NSLog("[DEBUG] DiskImageHelper: ejectDiskImage completed successfully")
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
