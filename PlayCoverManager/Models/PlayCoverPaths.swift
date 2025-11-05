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

    init(applicationURL: URL, bundleIdentifier: String, containerRootURL: URL) {
        self.applicationURL = applicationURL
        self.bundleIdentifier = bundleIdentifier
        self.containerRootURL = containerRootURL
        self.applicationsRootURL = containerRootURL.appendingPathComponent("Applications", isDirectory: true)
    }
}
