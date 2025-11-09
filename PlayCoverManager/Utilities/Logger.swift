import Foundation
import os.log

/// Centralized logging utility for PlayCover Manager
/// Provides structured logging with different severity levels
/// All methods are nonisolated for Swift 6 compatibility
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.playcover.manager"
    
    // MARK: - Log Categories
    
    private static let lifecycle = OSLog(subsystem: subsystem, category: "Lifecycle")
    private static let unmount = OSLog(subsystem: subsystem, category: "Unmount")
    private static let diskImage = OSLog(subsystem: subsystem, category: "DiskImage")
    private static let general = OSLog(subsystem: subsystem, category: "General")
    private static let performance = OSLog(subsystem: subsystem, category: "Performance")
    private static let installation = OSLog(subsystem: subsystem, category: "Installation")
    
    // MARK: - Logging Methods
    
    /// Log lifecycle-related events (app launch, termination, etc.)
    nonisolated static func lifecycle(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: lifecycle, type: .info, message)
        #endif
    }
    
    /// Log unmount-related events
    nonisolated static func unmount(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: unmount, type: .info, message)
        #endif
    }
    
    /// Log disk image operations
    nonisolated static func diskImage(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: diskImage, type: .debug, message)
        #endif
    }
    
    /// Log installation/uninstallation operations
    nonisolated static func installation(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: installation, type: .info, message)
        #endif
    }
    
    /// Log performance metrics
    nonisolated static func performance(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: performance, type: .debug, message)
        #endif
    }
    
    /// Log general debug information
    nonisolated static func debug(_ message: String) {
        #if DEBUG
        os_log("%{public}@", log: general, type: .debug, message)
        #endif
    }
    
    /// Log errors (always logged, even in release builds)
    nonisolated static func error(_ message: String) {
        os_log("%{public}@", log: general, type: .error, message)
    }
    
    /// Log warnings (always logged, even in release builds)
    nonisolated static func warning(_ message: String) {
        os_log("%{public}@", log: general, type: .fault, message)
    }
    
    // MARK: - Performance Measurement
    
    /// Measure execution time of a block and log the result
    /// - Parameters:
    ///   - label: Description of the operation being measured
    ///   - block: The code block to measure
    /// - Returns: The result of the block
    nonisolated static func measure<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            performance("\(label): \(String(format: "%.3f", timeElapsed * 1000))ms")
        }
        #endif
        return try block()
    }
    
    /// Measure execution time of an async block and log the result
    /// - Parameters:
    ///   - label: Description of the operation being measured
    ///   - block: The async code block to measure
    /// - Returns: The result of the block
    nonisolated static func measureAsync<T>(_ label: String, _ block: () async throws -> T) async rethrows -> T {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            performance("\(label): \(String(format: "%.3f", timeElapsed * 1000))ms")
        }
        #endif
        return try await block()
    }
}
