import Foundation

/// Turns the filtered Activity entries into the feed's sections and stacks.
///
/// Errors and warnings from the last day are pinned under Needs Attention.
/// Everything else is Recent. Within a section, events stack by subject on
/// their bridge, and stacks are ordered by their newest event.
enum ActivityStackBuilder {
    static let attentionWindow: TimeInterval = 24 * 60 * 60

    /// - Parameters:
    ///   - entries: Bridge-attributed entries, newest first.
    ///   - subject: Resolves who an entry is about. Injected so the builder
    ///     stays independent of the store.
    static func sections(
        from entries: [BridgeBoundLogEntry],
        now: Date = .now,
        subject: (BridgeBoundLogEntry) -> ActivityStack.Subject
    ) -> [ActivityFeedSection] {
        struct Key: Hashable {
            let section: ActivityFeedSection.Kind
            let bridgeID: UUID
            let subject: ActivityStack.Subject
        }

        var order: [Key] = []
        var grouped: [Key: [LogEntry]] = [:]
        let attentionCutoff = now.addingTimeInterval(-attentionWindow)

        for item in entries {
            let section: ActivityFeedSection.Kind =
                needsAttention(item.entry) && item.entry.timestamp >= attentionCutoff
                ? .needsAttention : .recent
            let key = Key(section: section, bridgeID: item.bridgeID, subject: subject(item))
            if grouped[key] == nil {
                order.append(key)
                grouped[key] = []
            }
            grouped[key]?.append(item.entry)
        }

        let stacks = order.map { key in
            ActivityStack(
                section: key.section,
                bridgeID: key.bridgeID,
                subject: key.subject,
                entries: grouped[key] ?? []
            )
        }

        return [ActivityFeedSection.Kind.needsAttention, .recent].compactMap { kind in
            let matching = stacks.filter { $0.section == kind }
            return matching.isEmpty ? nil : ActivityFeedSection(kind: kind, stacks: matching)
        }
    }

    static func needsAttention(_ entry: LogEntry) -> Bool {
        entry.level == .error || entry.level == .warning
    }
}
