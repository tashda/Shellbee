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

    /// How loudly a symbol avatar speaks. Device and group thumbnails are
    /// always drawn as-is; emphasis only applies to symbols.
    enum Emphasis {
        /// Neutral glyph, no fill: background noise such as signal drift.
        case quiet
        /// Tinted glyph on a soft tinted circle: ordinary events.
        case standard
        /// White glyph on a solid tint: failures that need a look.
        case loud
    }

    /// What happened, drawn as a small pip on the avatar so severity never
    /// relies on colour alone.
    enum Outcome {
        case success
        case warning
        case failure

        var systemImage: String {
            switch self {
            case .success: "checkmark"
            case .warning: "exclamationmark"
            case .failure: "xmark"
            }
        }

        var tint: Color {
            switch self {
            case .success: .green
            case .warning: .orange
            case .failure: .red
            }
        }
    }

    static func outcome(for entry: LogEntry) -> Outcome? {
        switch entry.level {
        case .error: return .failure
        case .warning: return .warning
        case .info, .debug: break
        }
        if let isSuccess = entry.bridgeTopicDisplay?.isSuccess {
            // A tick on every routine health check would drown out the
            // ones that mean something, so success is only marked for
            // requests whose outcome the user is waiting on.
            if !isSuccess { return .failure }
            return reportsSuccess(entry) ? .success : nil
        }
        if entry.category == .interview {
            let message = entry.message.lowercased()
            if message.contains("fail") { return .failure }
            if message.contains("success") { return .success }
        }
        return nil
    }

    private static func reportsSuccess(_ entry: LogEntry) -> Bool {
        guard case .mqttPublish(_, let topic, _) = entry.parsedMessageKind else { return false }
        return ["ota_update/update", "device/interview", "device/configure", "device/bind", "backup"]
            .contains { topic.hasSuffix($0) }
    }

    static func emphasis(for entry: LogEntry) -> Emphasis {
        if outcome(for: entry) == .failure { return .loud }
        if isLinkQualityOnly(entry) || entry.level == .debug { return .quiet }
        return .standard
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
            // LQI drifts are background noise, not warnings — use the
            // quieter signal-bars glyph in a neutral tint so the row
            // doesn't shout "error" at the eye.
            return .symbol(name: "dot.radiowaves.left.and.right", tint: .secondary)
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

    /// The device or group an entry is about, when `store` knows it by
    /// name. Used for the row thumbnail and to stack Activity by subject.
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

    /// The device or group thumbnail, ignoring the signal and battery
    /// overrides in `visual(for:store:)`. For places that always want to
    /// show who an event is about.
    static func subjectVisual(for entry: LogEntry, store: AppStore?) -> Visual? {
        store.flatMap { resolveSubject(for: entry, in: $0) }
    }

    private static func resolveSubject(for entry: LogEntry, in store: AppStore) -> Visual? {
        guard let name = subjectName(for: entry, in: store) else { return nil }
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
        case .availability:
            // Online → green dot, offline → grey. Tint encodes the new
            // state so the row is parseable at a glance.
            let isOnline = entry.message.lowercased().contains("online")
                && !entry.message.lowercased().contains("offline")
            return .symbol(name: "circle.fill", tint: isOnline ? .green : Color(.tertiaryLabel))
        case .bridgeState:
            let isOnline = entry.message.lowercased().contains("online")
                && !entry.message.lowercased().contains("offline")
            return .symbol(name: "antenna.radiowaves.left.and.right",
                           tint: isOnline ? .indigo : Color(.tertiaryLabel))
        case .permitJoin:
            let opened = entry.message.lowercased().contains("opened")
            return .symbol(name: opened ? "lock.open.fill" : "lock.fill",
                           tint: opened ? .orange : Color(.tertiaryLabel))
        case .bridgeActivity:
            // Tint flips to red when the response carried a non-ok status
            // — surfaces failures in the row itself instead of buried in
            // the detail view.
            let isFailure = entry.bridgeTopicDisplay?.isSuccess == false
            return .symbol(name: bridgeActivityGlyph(for: entry),
                           tint: isFailure ? .red : .indigo)
        case .stateChange:
            // State change with no device subject — rare, but render
            // consistently with the diff arrow rather than the old badge.
            return .symbol(name: "arrow.triangle.2.circlepath", tint: .purple)
        case .general:
            switch entry.level {
            case .error:
                return .symbol(name: "xmark.octagon.fill", tint: .red)
            case .warning:
                return .symbol(name: "exclamationmark.triangle.fill", tint: .orange)
            case .info:
                return .symbol(name: "info.circle.fill", tint: .blue)
            case .debug:
                return .symbol(name: "ladybug.fill", tint: .gray)
            }
        }
    }

    /// One glyph per kind of bridge request, so a feed of health checks,
    /// backups and OTA checks no longer reads as a wall of identical gears.
    private static func bridgeActivityGlyph(for entry: LogEntry) -> String {
        guard case .mqttPublish(_, let rawTopic, _) = entry.parsedMessageKind,
              let range = rawTopic.range(of: "bridge/") else { return "gearshape.fill" }
        let topic = rawTopic[range.lowerBound...]
            .replacingOccurrences(of: "bridge/response/", with: "")
        switch topic {
        case "bridge/health", "health_check": return "stethoscope"
        case "info": return "info.circle.fill"
        case "options", "device/options", "group/options": return "slider.horizontal.3"
        case "backup": return "externaldrive.fill"
        case "restart": return "arrow.clockwise"
        case "networkmap": return "point.3.connected.trianglepath.dotted"
        case "device/rename", "group/rename": return "pencil"
        case "device/remove", "group/remove": return "trash.fill"
        case "device/configure", "device/configure_reporting": return "gearshape.2.fill"
        case "device/bind", "device/unbind": return "link"
        case "device/ota_update/check": return "arrow.triangle.2.circlepath"
        case "group/add", "group/members/add", "group/members/remove": return "rectangle.3.group.fill"
        default:
            if topic.hasPrefix("device/ota_update") { return "arrow.down.circle.fill" }
            if topic.hasPrefix("touchlink") { return "dot.radiowaves.forward" }
            return "gearshape.fill"
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
