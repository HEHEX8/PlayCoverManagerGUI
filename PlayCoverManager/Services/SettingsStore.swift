import Foundation
import Observation

@Observable
final class SettingsStore {
    private enum Keys {
        static let diskImageDirectory = "diskImageDirectory"
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

    enum DiskImageFormat: String, CaseIterable, Identifiable {
        case sparse
        case sparseBundle
        case sparseHFS
        case asif

        var id: String { rawValue }
        var localizedDescription: String {
            switch self {
            case .sparse:
                return "スパース APFS（単一ファイル）"
            case .sparseBundle:
                return "スパースバンドル APFS（分割ファイル）"
            case .sparseHFS:
                return "スパース HFS+（互換性重視）"
            case .asif:
                return "ASIF（Tahoe、最速）"
            }
        }
        
        var requiresAPFS: Bool {
            switch self {
            case .sparse, .sparseBundle, .asif:
                return true
            case .sparseHFS:
                return false
            }
        }

        static let `default`: DiskImageFormat = .sparseHFS
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

    var diskImageFormat: DiskImageFormat = .default {
        didSet { UserDefaults.standard.set(diskImageFormat.rawValue, forKey: Keys.imageFormat) }
    }

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
        if let rawFormat = userDefaults.string(forKey: Keys.imageFormat),
           let fmt = DiskImageFormat(rawValue: rawFormat) {
            diskImageFormat = fmt
        } else {
            diskImageFormat = .default
            userDefaults.set(diskImageFormat.rawValue, forKey: Keys.imageFormat)
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
