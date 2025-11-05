import Foundation
import Observation

@Observable
final class SettingsStore {
    private enum Keys {
        static let diskImageDirectory = "diskImageDirectory"
        static let diskImageDirectoryBookmark = "diskImageDirectoryBookmark"
        static let nobrowseEnabled = "nobrowseEnabled"
        static let defaultDataHandling = "defaultDataHandling"
        static let imageFormat = "diskImageFormat"
    }

    enum InternalDataStrategy: String, CaseIterable, Identifiable {
        case discard
        case mergeThenDelete
        case leave

        var id: String { rawValue }
        var localizedDescription: String {
            switch self {
            case .discard:
                return "内部データを破棄してからマウント"
            case .mergeThenDelete:
                return "内部データを統合してから削除しマウント"
            case .leave:
                return "何もせずにマウント"
            }
        }

        static let `default`: InternalDataStrategy = .mergeThenDelete
    }

    // ASIF format only - macOS Tahoe 26.0+ required
    // Legacy formats removed for simplicity and modern macOS compatibility
    enum DiskImageFormat: String {
        case asif = "asif"
        
        var fileExtension: String { "asif" }
        var localizedDescription: String { "ASIF（macOS Tahoe 専用）" }
    }

    var diskImageDirectory: URL? = nil {
        didSet { saveDiskImageDirectory() }
    }

    var nobrowseEnabled: Bool = true {
        didSet { UserDefaults.standard.set(nobrowseEnabled, forKey: Keys.nobrowseEnabled) }
    }

    var defaultDataHandling: InternalDataStrategy = .default {
        didSet { UserDefaults.standard.set(defaultDataHandling.rawValue, forKey: Keys.defaultDataHandling) }
    }

    // ASIF format is hardcoded - no user selection needed
    let diskImageFormat: DiskImageFormat = .asif

    init(userDefaults: UserDefaults = .standard) {
        if let path = userDefaults.string(forKey: Keys.diskImageDirectory) {
            diskImageDirectory = URL(fileURLWithPath: path)
        } else {
            diskImageDirectory = nil
        }
        if userDefaults.object(forKey: Keys.nobrowseEnabled) == nil {
            userDefaults.set(true, forKey: Keys.nobrowseEnabled)
        }
        nobrowseEnabled = userDefaults.bool(forKey: Keys.nobrowseEnabled)
        if let raw = userDefaults.string(forKey: Keys.defaultDataHandling),
           let strategy = InternalDataStrategy(rawValue: raw) {
            defaultDataHandling = strategy
        } else {
            defaultDataHandling = .default
            userDefaults.set(defaultDataHandling.rawValue, forKey: Keys.defaultDataHandling)
        }
    }

    private func saveDiskImageDirectory() {
        if let diskImageDirectory {
            UserDefaults.standard.set(diskImageDirectory.path, forKey: Keys.diskImageDirectory)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.diskImageDirectory)
        }
    }
}
