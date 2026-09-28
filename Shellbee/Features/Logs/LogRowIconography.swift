import Foundation

/// Classifies log entries for the Activity feed: which ones are signal or
/// battery noise, and which device or group an entry is about.
enum LogRowIconography {
    /// True when every state change in the entry is just a `linkquality`
    /// drift. Activity hides these unless Signal Changes is on.
    static func isLinkQualityOnly(_ entry: LogEntry) -> Bool {
        guard entry.category == .stateChange,
              let changes = entry.context?.stateChanges,
              !changes.isEmpty else { return false }
        return changes.allSatisfy { $0.property == "linkquality" }
    }

    /// True when the only changed property is `battery` (ignoring metadata
    /// fields). Used to give battery reports their own title.
    static func isBatteryOnly(_ entry: LogEntry) -> Bool {
        guard entry.category == .stateChange,
              let changes = entry.context?.stateChanges,
              !changes.isEmpty else { return false }
        let metadata: Set<String> = ["linkquality", "last_seen"]
        let meaningful = changes.filter { !metadata.contains($0.property) }
        return !meaningful.isEmpty && meaningful.allSatisfy { $0.property == "battery" }
    }

    /// The device or group an entry is about, when `store` knows it by
    /// name. Used to stack Activity by subject.
    static func subjectName(for entry: LogEntry, in store: AppStore) -> String? {
        let candidate: String?
        if let ctx = entry.context, !ctx.devices.isEmpty {
            candidate = ctx.devices.first?.friendlyName
        } else if let n = entry.deviceName {
            candidate = n
        } else if case .mqttPublish(let d, _, _) = entry.parsedMessageKind {
            candidate = d
        } else {
            candidate = nil
        }
        guard let name = candidate,
              store.device(named: name) != nil || store.group(named: name) != nil else { return nil }
        return name
    }
}
