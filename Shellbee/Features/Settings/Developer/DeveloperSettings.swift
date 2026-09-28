import Foundation

enum DeveloperSettings {
    static let modeEnabledKey = "developerModeEnabled"
    static let softTopEdgeEnabledKey = "developerSoftTopEdgeEnabled"
    static let softTopEdgeEnabledDefault = true

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: modeEnabledKey)
    }
}
