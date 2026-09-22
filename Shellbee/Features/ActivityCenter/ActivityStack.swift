import Foundation

/// One notification-style stack in the Activity feed: every visible event
/// for one subject (a device, a group, or the bridge itself) on one bridge,
/// the way Notification Center stacks everything from one app.
struct ActivityStack: Identifiable, Hashable {
    enum Subject: Hashable {
        /// A device or group, by friendly name.
        case named(String)
        /// Events that have no device or group, attributed to the bridge.
        case bridge
    }

    let section: ActivityFeedSection.Kind
    let bridgeID: UUID
    let subject: Subject
    /// Newest first. Never empty.
    let entries: [LogEntry]

    /// Stable across refreshes so a new event slides into its existing stack
    /// instead of replacing it.
    var id: String {
        let subjectKey: String
        switch subject {
        case .named(let name): subjectKey = "named:\(name)"
        case .bridge: subjectKey = "bridge"
        }
        return "\(section.rawValue):\(bridgeID.uuidString):\(subjectKey)"
    }

    var latest: LogEntry { entries[0] }
    var isStacked: Bool { entries.count > 1 }

    /// Coalesced rows count every event they merged, so the "more" line
    /// reports what actually happened rather than how many rows exist.
    var eventCount: Int { entries.reduce(0) { $0 + $1.coalescedCount } }
}

struct ActivityFeedSection: Identifiable, Hashable {
    enum Kind: String {
        case needsAttention
        case recent
    }

    let kind: Kind
    let stacks: [ActivityStack]

    var id: Kind { kind }
}
