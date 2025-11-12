//
//  FileManagerExtensions.swift
//  PlayCoverManager
//
//  Swift 6.2 optimizations: FileManager convenience extensions
//  Reduces boilerplate and improves code readability
//

import Foundation

extension FileManager {
    // MARK: - Directory Creation
    
    /// Swift 6.2: Simplified directory creation with intermediate directories
    /// Eliminates need to specify withIntermediateDirectories every time
    /// nonisolated to allow calling from any isolation context
    nonisolated func createDirectoryIfNeeded(at url: URL, attributes: [FileAttributeKey: Any]? = nil) throws {
        guard !fileExists(atPath: url.path) else { return }
        try createDirectory(at: url, withIntermediateDirectories: true, attributes: attributes)
    }
    
    // MARK: - File Size
    
    /// Swift 6.2: Get file size with optional handling
    /// Returns nil instead of throwing for missing files
    func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }
    
    /// Swift 6.2: Calculate directory size recursively
    /// Uses enumerator for efficient traversal
    func directorySize(at url: URL) -> Int64 {
        guard let enumerator = enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        return totalSize
    }
    
    // MARK: - Safe Operations
    
    /// Swift 6.2: Safe file removal that doesn't throw if file doesn't exist
    func removeItemIfExists(at url: URL) throws {
        guard fileExists(atPath: url.path) else { return }
        try removeItem(at: url)
    }
    
    /// Swift 6.2: Check if path is directory
    func isDirectory(at url: URL) -> Bool {
        var isDir: ObjCBool = false
        guard fileExists(atPath: url.path, isDirectory: &isDir) else {
            return false
        }
        return isDir.boolValue
    }
}
