import Foundation

struct InAppNotification: Identifiable {
    let id: UUID
    let level: LogLevel
    let title: String
    let subtitle: String?
    let logEntryID: UUID?

    init(level: LogLevel, title: String, subtitle: String? = nil, logEntryID: UUID? = nil) {
        self.id = UUID()
        self.level = level
        self.title = title
        self.subtitle = subtitle
        self.logEntryID = logEntryID
    }
}
