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
        static let appLanguage = "appLanguage"
        static let maxConcurrentApps = "maxConcurrentApps"
        static let alwaysLaunchFullscreen = "alwaysLaunchFullscreen"
    }

    enum AppLanguage: String, CaseIterable, Identifiable {
        case system = "system"
        case japanese = "ja"
        case english = "en"
        case chinese = "zh-Hans"
        case chineseTraditional = "zh-Hant"
        
        var id: String { rawValue }
        
        /// Get native (endonym) display name for the language
        /// Uses each language's own locale to get the native name
        var localizedDescription: String {
            if self == .system {
                return String(localized: "システム設定に従う")
            }
            
            guard let code = languageCode else {
                return String(localized: "システム設定に従う")
            }
            
            // Use the language's own locale to get its native name (endonym)
            // This ensures Japanese shows as "日本語", Chinese as "简体中文" etc.
            let nativeLocale = Locale(identifier: code)
            return nativeLocale.localizedString(forIdentifier: code) ?? code
        }
        
        var languageCode: String? {
            switch self {
            case .system:
                return nil
            case .japanese:
                return "ja"
            case .english:
                return "en"
            case .chinese:
                return "zh-Hans"
            case .chineseTraditional:
                return "zh-Hant"
            }
        }
    }
    
    enum InternalDataStrategy: String, CaseIterable, Identifiable {
        case discard
        case mergeThenDelete
        case leave

        var id: String { rawValue }
        var localizedDescription: String {
            switch self {
            case .discard:
                return String(localized: "内部データを破棄してからマウント")
            case .mergeThenDelete:
                return String(localized: "内部データを統合してから削除しマウント")
            case .leave:
                return String(localized: "何もせずにマウント")
            }
        }

        static let `default`: InternalDataStrategy = .mergeThenDelete
    }

    // ASIF format only - macOS Tahoe 26.0+ required
    // Legacy formats removed for simplicity and modern macOS compatibility
    enum DiskImageFormat: String {
        case asif = "asif"
        
        var fileExtension: String { "asif" }
        var localizedDescription: String { String(localized: "ASIF（macOS Tahoe 専用）") }
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
    
    var appLanguage: AppLanguage = .system {
        didSet {
            UserDefaults.standard.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            applyLanguage()
        }
    }
    
    // Alert states - all shown at QuickLauncherView level for proper centering
    var showLanguageChangeAlert: Bool = false
    var showResetConfirmation: Bool = false
    var showClearCacheConfirmation: Bool = false
    
    // Alert result states (for info/error messages after operations)
    enum CacheOperationResult {
        case cleared
    }
    var cacheOperationResult: CacheOperationResult? = nil
    
    enum ShortcutRemovalResult {
        case success
        case notFound
        case error(String)
    }
    var shortcutRemovalResult: ShortcutRemovalResult? = nil
    
    // Concurrent app launch limit (0 = unlimited, default = 3)
    var maxConcurrentApps: Int = 3 {
        didSet {
            UserDefaults.standard.set(maxConcurrentApps, forKey: Keys.maxConcurrentApps)
        }
    }
    
    var alwaysLaunchFullscreen: Bool = false {
        didSet {
            UserDefaults.standard.set(alwaysLaunchFullscreen, forKey: Keys.alwaysLaunchFullscreen)
        }
    }
    
    // ASIF format is hardcoded - no user selection needed
    let diskImageFormat: DiskImageFormat = .asif
    
    // Fixed disk image size: 1TB for all (cannot be resized after creation)
    let defaultDiskImageSizeGB: Int = 1000

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
        
        if let raw = userDefaults.string(forKey: Keys.appLanguage),
           let language = AppLanguage(rawValue: raw) {
            appLanguage = language
        } else {
            appLanguage = .system
        }
        
        // Load maxConcurrentApps from UserDefaults (default: 3)
        // If value is 0 (from old version), treat it as unset and use default
        let savedValue = userDefaults.integer(forKey: Keys.maxConcurrentApps)
        if savedValue > 0 {
            maxConcurrentApps = savedValue
        } else {
            // Value is 0 or doesn't exist - use default 3
            maxConcurrentApps = 3
            userDefaults.set(3, forKey: Keys.maxConcurrentApps)
        }
        
        // Load alwaysLaunchFullscreen setting (default: false)
        alwaysLaunchFullscreen = userDefaults.bool(forKey: Keys.alwaysLaunchFullscreen)
        
        // Apply language on init
        applyLanguage()
    }
    
    private func applyLanguage() {
        if let languageCode = appLanguage.languageCode {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        // Note: synchronize() is unnecessary on macOS 10.14+ / iOS 12+
        // UserDefaults automatically persists changes asynchronously
    }

    private func saveDiskImageDirectory() {
        if let diskImageDirectory {
            UserDefaults.standard.set(diskImageDirectory.path, forKey: Keys.diskImageDirectory)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.diskImageDirectory)
        }
    }
}
