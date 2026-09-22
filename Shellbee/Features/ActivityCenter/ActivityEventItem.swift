import Foundation

/// One Activity event, ready to draw: its instrument and its words. Built
/// once from a log entry so the feed, Home and the tab bar accessory can't
/// drift apart, and constructible directly for the developer gallery.
struct ActivityEventItem: Identifiable {
    let id: UUID
    let instrument: ActivityInstrument
    let content: ActivityCardContent
    let timestamp: Date
    /// The source log line, when there is one. Wide layouts show extra
    /// detail from it; gallery samples have none.
    let entry: LogEntry?

    init(
        id: UUID = UUID(),
        instrument: ActivityInstrument,
        content: ActivityCardContent,
        timestamp: Date,
        entry: LogEntry? = nil
    ) {
        self.id = id
        self.instrument = instrument
        self.content = content
        self.timestamp = timestamp
        self.entry = entry
    }

    init(entry: LogEntry, subject: ActivityStack.Subject, bridgeName: String) {
        self.init(
            id: entry.id,
            instrument: ActivityInstrumentResolver.instrument(for: entry),
            content: ActivityCardContent(entry: entry, subject: subject, bridgeName: bridgeName),
            timestamp: entry.timestamp,
            entry: entry
        )
    }
}

extension AppEnvironment {
    /// Same subject resolution as the Activity feed: the device or group an
    /// entry is about, or the bridge when it's about neither.
    func activityEventItem(for item: BridgeBoundLogEntry) -> ActivityEventItem {
        let name = registry.session(for: item.bridgeID)
            .flatMap { LogRowIconography.subjectName(for: item.entry, in: $0.store) }
        return ActivityEventItem(
            entry: item.entry,
            subject: name.map(ActivityStack.Subject.named) ?? .bridge,
            bridgeName: item.bridgeName
        )
    }
}
