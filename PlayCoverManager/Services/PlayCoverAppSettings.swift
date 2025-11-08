import Foundation
import AppKit

/// PlayCover-compatible app settings
/// This struct maintains compatibility with PlayCover's AppSettings.swift
/// Settings are stored in: ~/Library/Containers/io.playcover.PlayCover/App Settings/<bundleID>.plist
/// 
/// NOTE: Most PlayCover-specific settings have been removed from the UI to avoid
/// compatibility issues when PlayCover updates. We keep the struct properties for
/// backward compatibility with existing settings files.
struct PlayCoverAppSettings: Codable {
    // MARK: - Metadata
    var bundleIdentifier: String = ""
    var version = "3.0.0"
    
    // MARK: - Keymapping / Controls (UI removed - PlayCover-specific)
    var keymapping = true
    var sensitivity: Float = 50
    var noKMOnInput = true
    var enableScrollWheel = true
    var disableBuiltinMouse = false
    
    // MARK: - Graphics / Display (UI removed - PlayCover-specific)
    var iosDeviceModel = "iPad13,8"  // M1 iPad Pro 12.9"
    var windowWidth = 1920
    var windowHeight = 1080
    var customScaler = 2.0
    var resolution = 1  // 0=Auto, 1=1080p, 2=1440p, 3=4K, 4=Custom
    var aspectRatio = 1  // 0=4:3, 1=16:9, 2=16:10, 3=Custom
    var notch: Bool = false
    var hideTitleBar = false
    var floatingWindow = false
    var metalHUD = false
    var resizableAspectRatioType = 0
    var resizableAspectRatioWidth = 0
    var resizableAspectRatioHeight = 0
    
    // MARK: - System / Advanced (PlayChain and Bypass UI removed)
    var disableTimeout = false
    var bypass = false
    var playChain = true
    var playChainDebugging = false
    var windowFixMethod = 0
    var rootWorkDir = true
    var inverseScreenValues = false
    var injectIntrospection = false
    var checkMicPermissionSync = false
    var limitMotionUpdateFrequency = false
    
    // MARK: - Discord Integration
    var discordActivity = DiscordActivity()
    
    init() {}
    
    // Handle old 2.x settings where PlayChain did not exist yet
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier) ?? ""
        keymapping = try container.decodeIfPresent(Bool.self, forKey: .keymapping) ?? true
        sensitivity = try container.decodeIfPresent(Float.self, forKey: .sensitivity) ?? 50
        disableTimeout = try container.decodeIfPresent(Bool.self, forKey: .disableTimeout) ?? false
        iosDeviceModel = try container.decodeIfPresent(String.self, forKey: .iosDeviceModel) ?? "iPad13,8"
        windowWidth = try container.decodeIfPresent(Int.self, forKey: .windowWidth) ?? 1920
        windowHeight = try container.decodeIfPresent(Int.self, forKey: .windowHeight) ?? 1080
        customScaler = try container.decodeIfPresent(Double.self, forKey: .customScaler) ?? 2.0
        resolution = try container.decodeIfPresent(Int.self, forKey: .resolution) ?? 1
        aspectRatio = try container.decodeIfPresent(Int.self, forKey: .aspectRatio) ?? 1
        notch = try container.decodeIfPresent(Bool.self, forKey: .notch) ?? false
        bypass = try container.decodeIfPresent(Bool.self, forKey: .bypass) ?? false
        discordActivity = try container.decodeIfPresent(DiscordActivity.self, forKey: .discordActivity) ?? DiscordActivity()
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "3.0.0"
        playChain = try container.decodeIfPresent(Bool.self, forKey: .playChain) ?? true
        playChainDebugging = try container.decodeIfPresent(Bool.self, forKey: .playChainDebugging) ?? false
        inverseScreenValues = try container.decodeIfPresent(Bool.self, forKey: .inverseScreenValues) ?? false
        metalHUD = try container.decodeIfPresent(Bool.self, forKey: .metalHUD) ?? false
        windowFixMethod = try container.decodeIfPresent(Int.self, forKey: .windowFixMethod) ?? 0
        injectIntrospection = try container.decodeIfPresent(Bool.self, forKey: .injectIntrospection) ?? false
        rootWorkDir = try container.decodeIfPresent(Bool.self, forKey: .rootWorkDir) ?? true
        noKMOnInput = try container.decodeIfPresent(Bool.self, forKey: .noKMOnInput) ?? true
        enableScrollWheel = try container.decodeIfPresent(Bool.self, forKey: .enableScrollWheel) ?? true
        hideTitleBar = try container.decodeIfPresent(Bool.self, forKey: .hideTitleBar) ?? false
        floatingWindow = try container.decodeIfPresent(Bool.self, forKey: .floatingWindow) ?? false
        checkMicPermissionSync = try container.decodeIfPresent(Bool.self, forKey: .checkMicPermissionSync) ?? false
        limitMotionUpdateFrequency = try container.decodeIfPresent(Bool.self, forKey: .limitMotionUpdateFrequency) ?? false
        disableBuiltinMouse = try container.decodeIfPresent(Bool.self, forKey: .disableBuiltinMouse) ?? false
        resizableAspectRatioType = try container.decodeIfPresent(Int.self, forKey: .resizableAspectRatioType) ?? 0
        resizableAspectRatioWidth = try container.decodeIfPresent(Int.self, forKey: .resizableAspectRatioWidth) ?? 0
        resizableAspectRatioHeight = try container.decodeIfPresent(Int.self, forKey: .resizableAspectRatioHeight) ?? 0
    }
}

/// Discord Rich Presence settings
struct DiscordActivity: Codable {
    var enabled = false
    var applicationId = ""
    var details = ""
    var state = ""
    
    init(enabled: Bool = false, applicationId: String = "", details: String = "", state: String = "") {
        self.enabled = enabled
        self.applicationId = applicationId
        self.details = details
        self.state = state
    }
}

/// Enums for better type safety
extension PlayCoverAppSettings {
    enum Resolution: Int, CaseIterable, Identifiable {
        case auto = 0
        case hd1080p = 1
        case hd1440p = 2
        case uhd4K = 3
        case custom = 4
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .auto: return "自動（ディスプレイに基づく）"
            case .hd1080p: return "1080p (1920×1080)"
            case .hd1440p: return "1440p (2560×1440)"
            case .uhd4K: return "4K (3840×2160)"
            case .custom: return "カスタム"
            }
        }
    }
    
    enum AspectRatio: Int, CaseIterable, Identifiable {
        case ratio4_3 = 0
        case ratio16_9 = 1
        case ratio16_10 = 2
        case custom = 3
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .ratio4_3: return "4:3"
            case .ratio16_9: return "16:9"
            case .ratio16_10: return "16:10"
            case .custom: return "カスタム"
            }
        }
    }
    
    enum IOSDeviceModel: String, CaseIterable, Identifiable {
        case iPad13_8 = "iPad13,8"  // M1 iPad Pro 12.9" (5th gen)
        case iPad13_4 = "iPad13,4"  // M1 iPad Pro 11" (3rd gen)
        case iPad8_12 = "iPad8,12"  // A12Z iPad Pro 12.9" (4th gen)
        case iPad8_1 = "iPad8,1"    // A12X iPad Pro 11" (1st gen)
        case iPhone14_2 = "iPhone14,2"  // iPhone 13 Pro
        case iPhone14_3 = "iPhone14,3"  // iPhone 13 Pro Max
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .iPad13_8: return "M1 iPad Pro 12.9\" (推奨)"
            case .iPad13_4: return "M1 iPad Pro 11\""
            case .iPad8_12: return "A12Z iPad Pro 12.9\" (省電力)"
            case .iPad8_1: return "A12X iPad Pro 11\""
            case .iPhone14_2: return "iPhone 13 Pro"
            case .iPhone14_3: return "iPhone 13 Pro Max"
            }
        }
        
        var description: String {
            switch self {
            case .iPad13_8: return "ほとんどの Apple Silicon Mac に最適"
            case .iPad13_4: return "小型ディスプレイ向け"
            case .iPad8_12: return "MacBook Air での長時間プレイに推奨（低解像度だが安定した 60 FPS）"
            case .iPad8_1: return "互換性重視"
            case .iPhone14_2, .iPhone14_3: return "iPhone 専用アプリ向け"
            }
        }
    }
    
    enum WindowFixMethod: Int, CaseIterable, Identifiable {
        case none = 0
        case method1 = 1
        case method2 = 2
        
        var id: Int { rawValue }
        
        var displayName: String {
            switch self {
            case .none: return "なし"
            case .method1: return "方法 1"
            case .method2: return "方法 2"
            }
        }
    }
}

/// Service to manage PlayCover-compatible app settings
@MainActor
class PlayCoverAppSettingsStore {
    // PlayCover's settings directory
    static var appSettingsDir: URL {
        let playCoverContainer = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/io.playcover.PlayCover")
        let settingsFolder = playCoverContainer.appendingPathComponent("App Settings")
        
        if !FileManager.default.fileExists(atPath: settingsFolder.path) {
            try? FileManager.default.createDirectory(at: settingsFolder, withIntermediateDirectories: true, attributes: [:])
        }
        
        return settingsFolder
    }
    
    /// Get settings file URL for a bundle ID
    static func settingsURL(for bundleID: String) -> URL {
        return appSettingsDir.appendingPathComponent(bundleID).appendingPathExtension("plist")
    }
    
    /// Load settings for an app
    static func load(for bundleID: String) -> PlayCoverAppSettings {
        let url = settingsURL(for: bundleID)
        
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              var settings = try? PropertyListDecoder().decode(PlayCoverAppSettings.self, from: data) else {
            // Return default settings with bundle ID set
            var settings = PlayCoverAppSettings()
            settings.bundleIdentifier = bundleID
            return settings
        }
        
        // Ensure bundle ID is set
        settings.bundleIdentifier = bundleID
        return settings
    }
    
    /// Save settings for an app
    static func save(_ settings: PlayCoverAppSettings, for bundleID: String) throws {
        var settings = settings
        settings.bundleIdentifier = bundleID
        
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        
        let data = try encoder.encode(settings)
        let url = settingsURL(for: bundleID)
        
        try data.write(to: url)
    }
    
    /// Delete settings for an app
    static func delete(for bundleID: String) throws {
        let url = settingsURL(for: bundleID)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
    
    /// Check if settings exist for an app
    static func exists(for bundleID: String) -> Bool {
        return FileManager.default.fileExists(atPath: settingsURL(for: bundleID).path)
    }
}
