import Foundation

enum DeveloperSettings {
    static let modeEnabledKey = "developerModeEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: modeEnabledKey)
    }
}
