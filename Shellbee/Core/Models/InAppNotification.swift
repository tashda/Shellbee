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
    var count: Int
    var lastUpdated: Date
    let priority: Priority

    init(
        level: LogLevel,
        title: String,
        subtitle: String? = nil,
        logEntryID: UUID? = nil,
        priority: Priority = .normal
    ) {
        self.id = UUID()
        self.level = level
        self.title = title
        self.subtitle = subtitle
        self.logEntryIDs = logEntryID.map { [$0] } ?? []
        self.count = 1
        self.lastUpdated = .now
        self.priority = priority
    }

    var coalesceKey: String { "\(level.rawValue)|\(title)" }
}
