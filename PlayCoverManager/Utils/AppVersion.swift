//
//  AppVersion.swift
//  PlayCoverManager
//
//  Created on 2025-11-13.
//  Version management utility - single source of truth
//

import Foundation

/// Centralized version management
/// Version is defined here and synced to project.pbxproj via build script
enum AppVersion {
    /// Marketing version (semantic versioning)
    static let version = "1.2.2"
    
    /// Build number (incremental)
    static let build = "1"
    
    /// Full version string
    static var fullVersion: String {
        "\(version) (Build \(build))"
    }
    
    /// Short version string
    static var shortVersion: String {
        "v\(version)"
    }
    
    /// Bundle version (from Info.plist, fallback to static version)
    static var bundleVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? version
    }
    
    /// Bundle build number (from Info.plist, fallback to static build)
    static var bundleBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? build
    }
    
    /// Check if bundle version matches defined version
    static var isSynced: Bool {
        bundleVersion == version && bundleBuild == build
    }
}
