import Foundation

/// Marks an Activity entry as needing the user's attention. The name remains
/// for source compatibility while event producers migrate to Activity naming.
struct InAppNotification {
    enum Priority: Equatable {
        case normal
        case fastTrack
    }

    let level: LogLevel
    let title: String
    let subtitle: String?
    let logEntryIDs: [UUID]
    let deviceName: String?
    let priority: Priority
    let category: NotificationCategory?

    init(
        level: LogLevel,
        title: String,
        subtitle: String? = nil,
        logEntryID: UUID? = nil,
        deviceName: String? = nil,
        priority: Priority = .normal,
        category: NotificationCategory? = nil
    ) {
        self.level = level
        self.title = title
        self.subtitle = subtitle
        self.logEntryIDs = logEntryID.map { [$0] } ?? []
        self.deviceName = deviceName
        self.priority = priority
        self.category = category
    }
}
