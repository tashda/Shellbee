import Foundation

/// What the user has cleared from Needs Attention. Clearing never deletes a
/// log line: it records "seen up to here" for a whole bridge or for one
/// stack, and anything at or before that moves down into Recent. Warnings
/// that arrive afterwards need attention again.
struct ActivityAttentionClearance: Equatable {
    static let storageKey = "activityAttentionClearance"

    /// Seen-through time by key: a bridge ID, or a bridge ID and subject.
    private var clearedThrough: [String: Date]

    init(rawValue: String) {
        let data = Data(rawValue.utf8)
        let seconds = (try? JSONDecoder().decode([String: Double].self, from: data)) ?? [:]
        clearedThrough = seconds.mapValues(Date.init(timeIntervalSince1970:))
    }

    var rawValue: String {
        let seconds = clearedThrough.mapValues(\.timeIntervalSince1970)
        guard let data = try? JSONEncoder().encode(seconds) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    func isCleared(_ entry: LogEntry, bridgeID: UUID, subject: ActivityStack.Subject) -> Bool {
        [Self.key(bridgeID), Self.key(bridgeID, subject)].contains { key in
            clearedThrough[key].map { entry.timestamp <= $0 } ?? false
        }
    }

    mutating func clear(bridgeIDs: some Sequence<UUID>, through date: Date = .now) {
        for bridgeID in bridgeIDs {
            clearedThrough[Self.key(bridgeID)] = date
        }
    }

    mutating func clear(_ stack: ActivityStack) {
        clearedThrough[Self.key(stack.bridgeID, stack.subject)] = stack.latest.timestamp
    }

    private static func key(_ bridgeID: UUID) -> String { bridgeID.uuidString }

    private static func key(_ bridgeID: UUID, _ subject: ActivityStack.Subject) -> String {
        switch subject {
        case .named(let name): return "\(bridgeID.uuidString)|named:\(name)"
        case .bridge: return "\(bridgeID.uuidString)|bridge"
        }
    }
}
