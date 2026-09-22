import Foundation

enum ActivityCenterSettings {
    static let isEnabledStorageKey = "activityCenterEnabled"

    static var isEnabled: Bool {
        guard UserDefaults.standard.object(forKey: isEnabledStorageKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: isEnabledStorageKey)
    }
}

enum ActivityAccessoryDisplayMode: String, CaseIterable, Identifiable {
    case latestActivity
    case summary
    case notificationsOnly

    static let storageKey = "activityAccessoryDisplayMode"

    var id: Self { self }

    var title: String {
        switch self {
        case .latestActivity: "Latest Activity"
        case .summary: "Summary"
        case .notificationsOnly: "Notifications Only"
        }
    }

    var detail: String {
        switch self {
        case .latestActivity: "Show the newest event when Activity Center is idle."
        case .summary: "Show a compact count of recent events."
        case .notificationsOnly: "Show notifications without recent Activity details."
        }
    }
}
