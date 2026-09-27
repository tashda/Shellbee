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
    /// The bridge the event came from, for its monogram.
    let bridgeID: UUID?
    let bridgeName: String

    init(
        id: UUID = UUID(),
        instrument: ActivityInstrument,
        content: ActivityCardContent,
        timestamp: Date,
        entry: LogEntry? = nil,
        bridgeID: UUID? = nil,
        bridgeName: String = ""
    ) {
        self.id = id
        self.instrument = instrument
        self.content = content
        self.timestamp = timestamp
        self.entry = entry
        self.bridgeID = bridgeID
        self.bridgeName = bridgeName
    }

    init(entry: LogEntry, subject: ActivityStack.Subject, bridgeName: String, bridgeID: UUID? = nil) {
        self.init(
            id: entry.id,
            instrument: ActivityInstrumentResolver.instrument(for: entry),
            content: ActivityCardContent(entry: entry, subject: subject, bridgeName: bridgeName),
            timestamp: entry.timestamp,
            entry: entry,
            bridgeID: bridgeID,
            bridgeName: bridgeName
        )
    }
}

extension AppEnvironment {
    /// Same subject resolution as the Activity feed: the device or group an
    /// entry is about, or the bridge when it's about neither.
    func activityEventItem(for item: BridgeBoundLogEntry) -> ActivityEventItem {
        ActivityEventItem(entry: item.entry, subject: activitySubject(for: item), bridgeName: item.bridgeName,
                          bridgeID: item.bridgeID)
    }

    func activitySubject(for item: BridgeBoundLogEntry) -> ActivityStack.Subject {
        registry.session(for: item.bridgeID)
            .flatMap { LogRowIconography.subjectName(for: item.entry, in: $0.store) }
            .map(ActivityStack.Subject.named) ?? .bridge
    }
}
