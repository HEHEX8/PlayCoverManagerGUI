import Foundation

// MARK: - PropertyList Helper Extensions
// Centralized PropertyList parsing to reduce code duplication and improve performance

extension String {
    /// Parse String output (typically from diskutil commands) as PropertyList Dictionary
    /// - Returns: Parsed dictionary or nil if parsing fails
    func parsePlist() -> [String: Any]? {
        guard let data = self.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }
}

extension Data {
    /// Parse Data as PropertyList Dictionary
    /// - Returns: Parsed dictionary or nil if parsing fails
    func parsePlist() -> [String: Any]? {
        guard let plist = try? PropertyListSerialization.propertyList(from: self, options: [], format: nil) as? [String: Any] else {
            return nil
        }
        return plist
    }
}

extension URL {
    /// Read and parse plist file at URL
    /// - Returns: Parsed dictionary or nil if reading or parsing fails
    func readPlist() -> [String: Any]? {
        guard let data = try? Data(contentsOf: self) else {
            return nil
        }
        return data.parsePlist()
    }
}
