import Foundation
import AppKit

/// Helper for loading high-quality app icons
enum AppIconHelper {
    /// Load app icon from .app bundle with high resolution (512x512)
    /// - Parameter appURL: URL to the .app bundle
    /// - Returns: NSImage with 512x512 size for crisp display
    static func loadAppIcon(from appURL: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        icon.size = NSSize(width: 512, height: 512)
        return icon
    }
    
    /// Load app icon from bundle ID (searches in PlayCover Applications directory)
    /// - Parameter bundleID: The app's bundle identifier
    /// - Returns: NSImage if found, nil otherwise
    static func loadAppIcon(forBundleID bundleID: String) -> NSImage? {
        let playCoverBundleID = "io.playcover.PlayCover"
        let applicationsDir = PlayCoverPaths.playCoverApplicationsURL(playCoverBundleID: playCoverBundleID)
        
        guard let appDirs = try? FileManager.default.contentsOfDirectory(
            at: applicationsDir,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        
        for appURL in appDirs where appURL.pathExtension == "app" {
            let infoPlist = appURL.appendingPathComponent("Info.plist")
            guard FileManager.default.fileExists(atPath: infoPlist.path),
                  let plistData = try? Data(contentsOf: infoPlist),
                  let plist = plistData.parsePlist(),
                  let installedBundleID = plist["CFBundleIdentifier"] as? String,
                  installedBundleID == bundleID else {
                continue
            }
            
            return loadAppIcon(from: appURL)
        }
        
        return nil
    }
}
