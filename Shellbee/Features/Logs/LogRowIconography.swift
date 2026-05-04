import SwiftUI

/// Decides what visual element belongs in the leading slot of a log row.
///
/// The default for state-change entries is the device's actual thumbnail —
/// the one users already learned on the Devices screen. Reusing that visual
/// language is what makes the log scannable instead of a wall of identical
/// blue badges. Non-device events fall back to category-specific symbols
/// with distinct tints so each kind of event is recognisable at a glance.
enum LogRowIconography {

    /// What to render in the row's leading slot.
    enum Visual {
        case deviceThumbnail(Device)
        case groupThumbnail(Group, members: [Device])
        /// Plain SF Symbol with tint. Used for events that aren't tied to a
        /// concrete device (interview milestones, bridge events, generic
        /// system messages) and for state-change variants where the device
        /// thumbnail would lie about what happened (LQI drift, battery).
        case symbol(name: String, tint: Color)
    }

    /// Pick the right visual for `entry` against `store`'s device/group
    /// registry. `store` is optional for previews and contexts where the
    /// scope isn't available — symbol fallback wins in that case.
    static func visual(for entry: LogEntry, store: AppStore?) -> Visual {
        // LQI-only and battery-only state changes get category-specific
        // symbols, not the device thumbnail. The point of the thumbnail is
        // "this device's state changed in a meaningful way"; a 245→244 link
        // quality drift or a battery report doesn't qualify.
        if isLinkQualityOnly(entry) {
            return .symbol(name: "wifi.exclamationmark", tint: .orange)
        }
        if isBatteryOnly(entry) {
            return .symbol(name: batteryGlyph(for: entry), tint: .green)
        }

        // Device or group thumbnail when the entry has a known subject.
        if let store, let subject = resolveSubject(for: entry, in: store) {
            return subject
        }

        return symbolForCategory(entry)
    }

    // MARK: - Classification helpers

    /// True when every state change in the entry is just a `linkquality`
    /// drift. These are the events the issue calls out as the dominant
    /// noise in the current log — they get their own subtle icon and (in
    /// Phase B) get hidden by default.
    static func isLinkQualityOnly(_ entry: LogEntry) -> Bool {
        guard entry.category == .stateChange,
              let changes = entry.context?.stateChanges,
              !changes.isEmpty else { return false }
        return changes.allSatisfy { $0.property == "linkquality" }
    }

    /// True when the only changed property is `battery` (ignoring metadata
    /// fields). A battery report deserves a battery glyph, not a sensor
    /// thumbnail — the user wants to see "battery dropped" without parsing
    /// the row twice.
    static func isBatteryOnly(_ entry: LogEntry) -> Bool {
        guard entry.category == .stateChange,
              let changes = entry.context?.stateChanges,
              !changes.isEmpty else { return false }
        let metadata: Set<String> = ["linkquality", "last_seen"]
        let meaningful = changes.filter { !metadata.contains($0.property) }
        return !meaningful.isEmpty && meaningful.allSatisfy { $0.property == "battery" }
    }

    // MARK: - Private

    private static func resolveSubject(for entry: LogEntry, in store: AppStore) -> Visual? {
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
        guard let name = candidate else { return nil }
        if let device = store.device(named: name) {
            return .deviceThumbnail(device)
        }
        if let group = store.group(named: name) {
            return .groupThumbnail(group, members: store.memberDevices(of: group))
        }
        return nil
    }

    private static func symbolForCategory(_ entry: LogEntry) -> Visual {
        switch entry.category {
        case .deviceJoined:
            return .symbol(name: "plus.circle.fill", tint: .green)
        case .deviceAnnounce:
            return .symbol(name: "megaphone.fill", tint: .blue)
        case .interview:
            return .symbol(name: "checklist", tint: .blue)
        case .deviceLeave:
            return .symbol(name: "minus.circle.fill", tint: .red)
        case .stateChange:
            // State change with no device subject — rare, but render
            // consistently with the diff arrow rather than the old badge.
            return .symbol(name: "arrow.triangle.2.circlepath", tint: .purple)
        case .general:
            switch entry.level {
            case .error:
                return .symbol(name: "exclamationmark.triangle.fill", tint: .red)
            case .warning:
                return .symbol(name: "exclamationmark.circle.fill", tint: .orange)
            case .info:
                return .symbol(name: "info.circle.fill", tint: .blue)
            case .debug:
                return .symbol(name: "ladybug.fill", tint: .gray)
            }
        }
    }

    /// Pick a battery glyph at the right fill level when the change carries
    /// a percentage. Fallback is the generic "battery" symbol for entries
    /// where the new value isn't numeric.
    private static func batteryGlyph(for entry: LogEntry) -> String {
        guard let changes = entry.context?.stateChanges,
              let battery = changes.first(where: { $0.property == "battery" }),
              let level = battery.to.numberValue else {
            return "battery.50"
        }
        switch level {
        case ..<10: return "battery.0"
        case 10..<37: return "battery.25"
        case 37..<63: return "battery.50"
        case 63..<87: return "battery.75"
        default: return "battery.100"
        }
    }
}
