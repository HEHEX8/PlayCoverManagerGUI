import Foundation
import Observation

/// Per-app settings storage
/// Stores individual settings for each app by bundle identifier
@MainActor
@Observable
final class PerAppSettingsStore {
    private enum Keys {
        static let perAppSettings = "perAppSettings"
    }
    
    /// Settings for a single app
    struct AppSettings: Codable, Equatable {
        var nobrowseEnabled: Bool?  // nil means use global default
        var dataHandlingStrategy: String?  // nil means use global default
        
        init(nobrowseEnabled: Bool? = nil, dataHandlingStrategy: String? = nil) {
            self.nobrowseEnabled = nobrowseEnabled
            self.dataHandlingStrategy = dataHandlingStrategy
        }
    }
    
    // All per-app settings, keyed by bundle identifier
    private var allSettings: [String: AppSettings] = [:]
    
    private let userDefaults: UserDefaults
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadSettings()
    }
    
    // MARK: - Get/Set Settings
    
    func getSettings(for bundleID: String) -> AppSettings {
        return allSettings[bundleID] ?? AppSettings()
    }
    
    func setSettings(_ settings: AppSettings, for bundleID: String) {
        allSettings[bundleID] = settings
        saveSettings()
    }
    
    func removeSettings(for bundleID: String) {
        allSettings.removeValue(forKey: bundleID)
        saveSettings()
    }
    
    // MARK: - Convenience Methods
    
    func getNobrowse(for bundleID: String, globalDefault: Bool) -> Bool {
        return allSettings[bundleID]?.nobrowseEnabled ?? globalDefault
    }
    
    func setNobrowse(_ enabled: Bool?, for bundleID: String) {
        var settings = getSettings(for: bundleID)
        settings.nobrowseEnabled = enabled
        setSettings(settings, for: bundleID)
    }
    
    func getDataHandlingStrategy(for bundleID: String, globalDefault: SettingsStore.InternalDataStrategy) -> SettingsStore.InternalDataStrategy {
        if let strategyRaw = allSettings[bundleID]?.dataHandlingStrategy,
           let strategy = SettingsStore.InternalDataStrategy(rawValue: strategyRaw) {
            return strategy
        }
        return globalDefault
    }
    
    func setDataHandlingStrategy(_ strategy: SettingsStore.InternalDataStrategy?, for bundleID: String) {
        var settings = getSettings(for: bundleID)
        settings.dataHandlingStrategy = strategy?.rawValue
        setSettings(settings, for: bundleID)
    }
    
    // MARK: - Persistence
    
    private func loadSettings() {
        guard let data = userDefaults.data(forKey: Keys.perAppSettings),
              let decoded = try? JSONDecoder().decode([String: AppSettings].self, from: data) else {
            return
        }
        allSettings = decoded
    }
    
    private func saveSettings() {
        guard let encoded = try? JSONEncoder().encode(allSettings) else {
            return
        }
        userDefaults.set(encoded, forKey: Keys.perAppSettings)
    }
}
