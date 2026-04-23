import Foundation

struct InAppNotification: Identifiable, Equatable {
    enum Priority: Equatable {
        case normal
        case fastTrack
    }

    let id: UUID
    let level: LogLevel
    let title: String
    var subtitle: String?
    var logEntryIDs: [UUID]
    var deviceName: String?
    var count: Int
    var lastUpdated: Date
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
        self.id = UUID()
        self.level = level
        self.title = title
        self.subtitle = subtitle
        self.logEntryIDs = logEntryID.map { [$0] } ?? []
        self.deviceName = deviceName
        self.count = 1
        self.lastUpdated = .now
        self.priority = priority
        self.category = category
    }

    var coalesceKey: String { "\(level.rawValue)|\(title)" }
}
