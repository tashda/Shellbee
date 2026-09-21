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
        case .latestActivity: "Show the newest event when the bar is idle."
        case .summary: "Show a compact count of recent events."
        case .notificationsOnly: "Hide the bar unless Shellbee has a notification."
        }
    }
}
