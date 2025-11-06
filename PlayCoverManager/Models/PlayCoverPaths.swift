import Foundation

struct PlayCoverPaths {
    let applicationURL: URL
    let bundleIdentifier: String
    let containerRootURL: URL
    let applicationsRootURL: URL

    static let defaultApplicationURL = URL(fileURLWithPath: "/Applications/PlayCover.app")

    static func defaultContainerRoot(for userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        userHome.appendingPathComponent("Library/Containers", isDirectory: true)
    }

    static func playCoverContainerURL(for userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        defaultContainerRoot(for: userHome).appendingPathComponent("io.playcover.PlayCover", isDirectory: true)
    }
    
    // MARK: - Container URL Generation
    
    /// Get container URL for a specific app bundle ID
    /// - Parameter bundleID: The bundle identifier of the app
    /// - Returns: URL to the app's container directory
    static func containerURL(for bundleID: String, userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        defaultContainerRoot(for: userHome).appendingPathComponent(bundleID, isDirectory: true)
    }
    
    /// Get app settings file URL for PlayCover
    /// - Parameters:
    ///   - playCoverBundleID: PlayCover's bundle ID (default: io.playcover.PlayCover)
    ///   - appBundleID: The app's bundle ID
    /// - Returns: URL to the app settings plist file
    static func appSettingsURL(playCoverBundleID: String = "io.playcover.PlayCover", 
                               appBundleID: String,
                               userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        defaultContainerRoot(for: userHome)
            .appendingPathComponent("\(playCoverBundleID)/App Settings/\(appBundleID).plist")
    }
    
    /// Get entitlements file URL for PlayCover
    /// - Parameters:
    ///   - playCoverBundleID: PlayCover's bundle ID (default: io.playcover.PlayCover)
    ///   - appBundleID: The app's bundle ID
    /// - Returns: URL to the entitlements plist file
    static func entitlementsURL(playCoverBundleID: String = "io.playcover.PlayCover",
                                appBundleID: String,
                                userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        defaultContainerRoot(for: userHome)
            .appendingPathComponent("\(playCoverBundleID)/Entitlements/\(appBundleID).plist")
    }
    
    /// Get keymapping file URL for PlayCover
    /// - Parameters:
    ///   - playCoverBundleID: PlayCover's bundle ID (default: io.playcover.PlayCover)
    ///   - appBundleID: The app's bundle ID
    /// - Returns: URL to the keymapping plist file
    static func keymappingURL(playCoverBundleID: String = "io.playcover.PlayCover",
                             appBundleID: String,
                             userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        defaultContainerRoot(for: userHome)
            .appendingPathComponent("\(playCoverBundleID)/Keymapping/\(appBundleID).plist")
    }
    
    /// Get PlayChain directory URL for PlayCover
    /// - Parameter playCoverBundleID: PlayCover's bundle ID (default: io.playcover.PlayCover)
    /// - Returns: URL to the PlayChain directory
    static func playChainURL(playCoverBundleID: String = "io.playcover.PlayCover",
                            userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        defaultContainerRoot(for: userHome)
            .appendingPathComponent("\(playCoverBundleID)/PlayChain", isDirectory: true)
    }
    
    /// Get Applications directory URL inside PlayCover container
    /// - Parameter playCoverBundleID: PlayCover's bundle ID (default: io.playcover.PlayCover)
    /// - Returns: URL to the Applications directory
    static func playCoverApplicationsURL(playCoverBundleID: String = "io.playcover.PlayCover",
                                        userHome: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        defaultContainerRoot(for: userHome)
            .appendingPathComponent("\(playCoverBundleID)/Applications", isDirectory: true)
    }

    init(applicationURL: URL, bundleIdentifier: String, containerRootURL: URL) {
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
        self.containerRootURL = containerRootURL
        self.applicationsRootURL = containerRootURL.appendingPathComponent("Applications", isDirectory: true)
    }
}
