import Foundation

/// Swift 6.2: Actor-based service for managing file locks on containers
/// Provides thread-safe lock management using Swift's actor model
actor ContainerLockService {
    private let fileManager: FileManager
    
    // Track locks by bundle identifier (actor-isolated state)
    private var activeLocks: [String: FileHandle] = [:]
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    // Swift 6.2: isolated deinit runs on actor's executor
    isolated deinit {
        // Release all locks on cleanup
        // Safe to access actor-isolated state in isolated deinit
        releaseAllLocksUnsafe()
    }
    
    /// Swift 6.2: Actor-isolated lock method (no manual queue sync needed)
    /// - Parameters:
    ///   - bundleID: The bundle identifier of the app
    ///   - containerURL: The container directory URL
    /// - Returns: true if lock was successfully acquired, false if already locked
    func lockContainer(for bundleID: String, at containerURL: URL) -> Bool {
        // If already locked, return true
        if activeLocks[bundleID] != nil {
            return true
        }
            
            // Create lock file path
            let lockFileURL = containerURL.appendingPathComponent(".playcover_lock")
            
            do {
                // Ensure container directory exists
                if !fileManager.fileExists(atPath: containerURL.path) {
                    try fileManager.createDirectory(at: containerURL, withIntermediateDirectories: true)
                }
                
                // Create lock file if it doesn't exist
                if !fileManager.fileExists(atPath: lockFileURL.path) {
                    fileManager.createFile(atPath: lockFileURL.path, contents: Data(), attributes: nil)
                }
                
                // Open file with exclusive lock
                let fileHandle = try FileHandle(forUpdating: lockFileURL)
                
                // Try to acquire exclusive lock (non-blocking)
                // flock with LOCK_EX | LOCK_NB for non-blocking exclusive lock
                let fd = fileHandle.fileDescriptor
                let result = flock(fd, LOCK_EX | LOCK_NB)
                
                if result == 0 {
                    // Lock acquired successfully
                    activeLocks[bundleID] = fileHandle
                    return true
                } else {
                    // Lock failed (another process has it)
                    try? fileHandle.close()
                    return false
                }
            } catch {
                // Failed to create lock
                return false
            }
    }
    
    /// Swift 6.2: Actor-isolated unlock (automatic serialization)
    /// - Parameter bundleID: The bundle identifier of the app
    func unlockContainer(for bundleID: String) {
        guard let fileHandle = activeLocks[bundleID] else {
            return
        }
        
        // Release lock
        let fd = fileHandle.fileDescriptor
        flock(fd, LOCK_UN)
        
        // Close file handle
        try? fileHandle.close()
        
        // Remove from active locks
        activeLocks.removeValue(forKey: bundleID)
    }
    
    /// Swift 6.2: Actor-isolated lock check (thread-safe by default)
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: true if locked by this instance
    func isLocked(for bundleID: String) -> Bool {
        return activeLocks[bundleID] != nil
    }
    
    /// Swift 6.2: Actor-isolated lock test method
    /// - Parameters:
    ///   - bundleID: The bundle identifier of the app
    ///   - containerURL: The container directory URL
    /// - Returns: true if lock can be acquired (no other process holds it)
    func canLockContainer(for bundleID: String, at containerURL: URL) -> Bool {
        // If we already have the lock, return true
        if activeLocks[bundleID] != nil {
            return true
        }
        
        let lockFileURL = containerURL.appendingPathComponent(".playcover_lock")
        
        // If lock file doesn't exist, we can lock it
        guard fileManager.fileExists(atPath: lockFileURL.path) else {
            return true
        }
        
        do {
            let fileHandle = try FileHandle(forUpdating: lockFileURL)
            let fd = fileHandle.fileDescriptor
            
            // Try non-blocking lock
            let result = flock(fd, LOCK_EX | LOCK_NB)
            
            if result == 0 {
                // Can acquire lock, but release it immediately (just testing)
                flock(fd, LOCK_UN)
                try? fileHandle.close()
                return true
            } else {
                // Cannot acquire lock (another process has it)
                try? fileHandle.close()
                return false
            }
        } catch {
            // Error accessing file
            return false
        }
    }
    
    /// Swift 6.2: Actor-isolated cleanup (safe to call in isolated deinit)
    private func releaseAllLocksUnsafe() {
        for (_, fileHandle) in activeLocks {
            let fd = fileHandle.fileDescriptor
            flock(fd, LOCK_UN)
            try? fileHandle.close()
        }
        activeLocks.removeAll()
    }
    
    // MARK: - Cleanup
    
    /// Clean up stale lock files from containers
    /// Removes lock files that are not currently held by any process
    /// - Parameter containerURLs: Array of container URLs to check
    func cleanupStaleLocks(in containerURLs: [URL]) {
        for containerURL in containerURLs {
            let lockFileURL = containerURL.appendingPathComponent(".playcover_lock")
            
            // Skip if lock file doesn't exist
            guard fileManager.fileExists(atPath: lockFileURL.path) else {
                continue
            }
            
            // Try to acquire lock to see if it's stale
            do {
                let fileHandle = try FileHandle(forUpdating: lockFileURL)
                let fd = fileHandle.fileDescriptor
                
                // Try non-blocking lock
                let result = flock(fd, LOCK_EX | LOCK_NB)
                
                if result == 0 {
                    // Lock acquired = no one is using it = stale lock file
                    // Release lock immediately
                    flock(fd, LOCK_UN)
                    try? fileHandle.close()
                    
                    // Delete stale lock file
                    try? fileManager.removeItem(at: lockFileURL)
                } else {
                    // Lock failed = someone is using it = keep it
                    try? fileHandle.close()
                }
            } catch {
                // Failed to check lock, leave it alone
                continue
            }
        }
    }
}
