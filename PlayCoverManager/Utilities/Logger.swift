import Foundation
import os.log

/// Centralized logging utility for PlayCover Manager
/// Provides structured logging with different severity levels
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.playcover.manager"
    
    // MARK: - Logging Methods
    
    /// Log lifecycle-related events (app launch, termination, etc.)
    static func lifecycle(_ message: String) {
        #if DEBUG
        let log = OSLog(subsystem: subsystem, category: "Lifecycle")
        os_log("%{public}@", log: log, type: .info, message)
        #endif
    }
    
    /// Log unmount-related events
    static func unmount(_ message: String) {
        #if DEBUG
        let log = OSLog(subsystem: subsystem, category: "Unmount")
        os_log("%{public}@", log: log, type: .info, message)
        #endif
    }
    
    /// Log disk image operations
    static func diskImage(_ message: String) {
        #if DEBUG
        let log = OSLog(subsystem: subsystem, category: "DiskImage")
        os_log("%{public}@", log: log, type: .debug, message)
        #endif
    }
    
    /// Log installation/uninstallation operations
    static func installation(_ message: String) {
        #if DEBUG
        let log = OSLog(subsystem: subsystem, category: "Installation")
        os_log("%{public}@", log: log, type: .info, message)
        #endif
    }
    
    /// Log performance metrics
    static func performance(_ message: String) {
        #if DEBUG
        let log = OSLog(subsystem: subsystem, category: "Performance")
        os_log("%{public}@", log: log, type: .debug, message)
        #endif
    }
    
    /// Log general debug information
    static func debug(_ message: String) {
        #if DEBUG
        let log = OSLog(subsystem: subsystem, category: "General")
        os_log("%{public}@", log: log, type: .debug, message)
        #endif
    }
    
    /// Log errors (always logged, even in release builds)
    static func error(_ message: String) {
        let log = OSLog(subsystem: subsystem, category: "General")
        os_log("%{public}@", log: log, type: .error, message)
    }
    
    /// Log warnings (always logged, even in release builds)
    static func warning(_ message: String) {
        let log = OSLog(subsystem: subsystem, category: "General")
        os_log("%{public}@", log: log, type: .fault, message)
    }
    
    // MARK: - Performance Measurement
    
    /// Measure execution time of a block and log the result
    static func measure<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
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
    static func measureAsync<T>(_ label: String, _ block: () async throws -> T) async rethrows -> T {
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
