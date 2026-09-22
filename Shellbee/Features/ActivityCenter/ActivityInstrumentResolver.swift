import SwiftUI

/// Converts live Activity entries into the same semantic instruments used by
/// the Developer gallery. Classification is based on Z2M property and topic
/// semantics, never on a device model, so custom devices remain useful.
enum ActivityInstrumentResolver {
    private static let metadataProperties: Set<String> = ["last_seen", "linkquality"]

    static func instrument(for entry: LogEntry) -> ActivityInstrument {
        if entry.category == .stateChange,
           let changes = entry.context?.stateChanges,
           !changes.isEmpty {
            return stateInstrument(for: changes, entrySeverity: severity(for: entry))
        }

        if let bridgeInstrument = bridgeInstrument(for: entry) {
            return bridgeInstrument
        }

        if let actionInstrument = actionInstrument(for: entry) {
            return actionInstrument
        }

        let severity = severity(for: entry)
        let message = entry.message.lowercased()
        switch entry.category {
        case .deviceJoined:
            return .init(kind: .lifecycle, normalizedValue: 1, trend: .rising, severity: .success)
        case .deviceAnnounce:
            return .init(kind: .signal, normalizedValue: 0.72, severity: severity)
        case .interview:
            return .init(kind: .pairing, normalizedValue: severity == .failure ? 0 : 1, severity: severity)
        case .deviceLeave:
            return .init(kind: .lifecycle, normalizedValue: 0, trend: .falling, severity: .warning)
        case .availability, .bridgeState:
            let online = message.contains("online") && !message.contains("offline")
            return .init(
                kind: .lifecycle,
                normalizedValue: online ? 1 : 0,
                trend: online ? .rising : .falling,
                severity: online ? .success : .failure,
                variant: .availability
            )
        case .permitJoin:
            let opened = message.contains("open") || message.contains("true")
            return permitJoin(opened: opened)
        case .bridgeActivity:
            return .init(kind: .unknown, severity: severity)
        case .stateChange:
            return .init(kind: .unknown, severity: severity)
        case .general:
            return .init(kind: .message, severity: severity)
        }
    }

    static func instrument(
        forProperty property: String,
        from: JSONValue? = nil,
        to: JSONValue,
        severity entrySeverity: ActivityInstrumentSeverity = .routine
    ) -> ActivityInstrument {
        let key = canonical(property)
        let kind = kind(for: key)
        let normalizedValue = normalized(value: to, property: key)
        let propertySeverity = severity(for: key, normalizedValue: normalizedValue)

        return ActivityInstrument(
            kind: kind,
            value: to.numberValue,
            normalizedValue: normalizedValue,
            trend: trend(from: from, to: to),
            severity: entrySeverity == .routine ? propertySeverity : entrySeverity,
            variant: variant(for: key),
            swatch: kind == .colour ? swatch(property: key, value: to) : nil
        )
    }

    // MARK: - State changes

    /// The change a multi-property report is about. Link quality and
    /// last-seen ride along with most reports, so they only win alone.
    static func headline(of changes: [LogContext.StateChange]) -> LogContext.StateChange? {
        let meaningful = changes.filter { !metadataProperties.contains(canonical($0.property)) }
        let candidates = meaningful.isEmpty ? changes : meaningful
        return candidates.max { priority(for: $0) < priority(for: $1) }
    }

    private static func stateInstrument(
        for changes: [LogContext.StateChange],
        entrySeverity: ActivityInstrumentSeverity
    ) -> ActivityInstrument {
        guard let primary = headline(of: changes) else {
            return .init(kind: .unknown, severity: entrySeverity)
        }
        return instrument(
            forProperty: primary.property,
            from: primary.from,
            to: primary.to,
            severity: entrySeverity
        )
    }

    private static func kind(for property: String) -> ActivityInstrumentKind {
        if property.contains("temperature") || property.contains("setpoint") { return .temperature }
        if property.contains("humidity") || property.contains("moisture") { return .humidity }
        if property == "air_quality" || property.contains("co2") || property.contains("voc")
            || property.contains("pm25") || property.contains("pm2_5") { return .airQuality }
        if property == "power" || property == "energy" || property == "current" { return .energy }
        if property == "position" || property.contains("tilt") || property.contains("cover") { return .position }
        if property.contains("color") || property.contains("colour") { return .colour }
        if property == "linkquality" || property == "rssi" { return .signal }
        if property.contains("battery") { return .battery }
        if ["occupancy", "presence", "motion"].contains(property) { return .presence }
        if ["water_leak", "smoke", "gas", "tamper", "carbon_monoxide", "alarm"].contains(property) {
            return .safety
        }
        if property == "action" || property.contains("button") || property.contains("click") { return .action }
        if property == "brightness" || property.contains("level") || property.contains("speed")
            || property.contains("illuminance") { return .level }
        if ["state", "contact", "lock", "child_lock"].contains(property) {
            return .binary
        }
        if ["pressure", "voltage", "frequency", "vibration"].contains(property) { return .trend }
        return .unknown
    }

    /// Which change headlines a multi-property report. An actual on/off
    /// flip is what happened when a light turns on, even though brightness
    /// arrives alongside it; only a safety alarm outranks it.
    private static func priority(for change: LogContext.StateChange) -> Int {
        let property = canonical(change.property)
        if kind(for: property) == .binary,
           let before = change.from.flatMap(binaryValue),
           let after = binaryValue(change.to),
           before != after {
            return 95
        }
        return priority(for: property)
    }

    private static func priority(for property: String) -> Int {
        switch kind(for: property) {
        case .safety: 100
        case .presence, .action: 90
        case .battery: 80
        case .temperature, .humidity, .airQuality, .energy, .position, .colour, .level: 70
        case .signal: 30
        case .binary, .trend: 50
        default: 0
        }
    }

    private static func variant(for property: String) -> ActivityInstrumentVariant {
        switch property {
        case "contact": return .contact
        case "lock", "child_lock": return .lock
        default: return property.contains("speed") ? .fan : .standard
        }
    }

    /// The colour a light was set to: an xy/hs/rgb object, a hex string,
    /// or a colour temperature in mireds.
    private static func swatch(property: String, value: JSONValue) -> Color? {
        if property.contains("color_temp") || property.contains("colour_temp") {
            return value.numberValue.map { LightDisplayColor.temperatureColor(mireds: $0) }
        }
        if value.object != nil {
            return LightDisplayColor.resolve(colorValue: value, colorTemperature: nil, colorMode: nil)
        }
        guard let hex = value.stringValue?.trimmingCharacters(in: CharacterSet(charactersIn: "#")),
              hex.count == 6, let rgb = UInt32(hex, radix: 16) else { return nil }
        return Color(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    private static func normalized(value: JSONValue, property: String) -> Double {
        if let binary = binaryValue(value) {
            // Z2M reports `contact: true` for closed; the lit state is open.
            if property == "contact" { return binary ? 0 : 1 }
            return binary ? 1 : 0
        }
        guard let number = value.numberValue else { return 0.5 }

        let scaled: Double
        switch kind(for: property) {
        case .battery, .humidity, .position:
            scaled = number / 100
        case .signal:
            scaled = property == "rssi" ? (number + 100) / 70 : number / DesignTokens.ActivityFeed.maxLinkQuality
        case .temperature:
            scaled = (number + 10) / 50
        case .level:
            if property == "brightness" && number > 100 {
                scaled = number / 254
            } else if number <= 100 {
                scaled = number / 100
            } else {
                scaled = number / (number + 100)
            }
        case .airQuality:
            scaled = number / (property.contains("co2") ? 2_000 : 500)
        case .energy:
            scaled = number / (abs(number) + 500)
        default:
            scaled = abs(number) / (abs(number) + 100)
        }
        return min(max(scaled, 0), 1)
    }

    private static func binaryValue(_ value: JSONValue) -> Bool? {
        if let bool = value.boolValue { return bool }
        guard let string = value.stringValue?.lowercased() else { return nil }
        if ["on", "open", "opened", "true", "yes", "active", "detected", "occupied", "locked", "lock", "online"].contains(string) {
            return true
        }
        if ["off", "closed", "false", "no", "inactive", "clear", "unoccupied", "unlocked", "unlock", "offline"].contains(string) {
            return false
        }
        return nil
    }

    private static func trend(from: JSONValue?, to: JSONValue) -> ActivityInstrumentTrend {
        if let fromNumber = from?.numberValue, let toNumber = to.numberValue {
            if toNumber > fromNumber { return .rising }
            if toNumber < fromNumber { return .falling }
            return .steady
        }
        if let before = from.flatMap(binaryValue), let after = binaryValue(to) {
            if before == after { return .steady }
            return after ? .rising : .falling
        }
        return .none
    }

    private static func severity(
        for property: String,
        normalizedValue: Double
    ) -> ActivityInstrumentSeverity {
        switch kind(for: property) {
        case .safety: return normalizedValue >= 0.5 ? .failure : .success
        case .battery: return normalizedValue < 0.2 ? .warning : .routine
        case .signal: return .quiet
        default: return .routine
        }
    }

    // MARK: - Bridge and event semantics

    private static func bridgeInstrument(for entry: LogEntry) -> ActivityInstrument? {
        guard case .mqttPublish(_, let rawTopic, let payload) = entry.parsedMessageKind,
              let bridgeRange = rawTopic.range(of: "bridge/") else { return nil }
        let topic = String(rawTopic[bridgeRange.lowerBound...])
        let suffix = topic.replacingOccurrences(of: "bridge/response/", with: "")
        let severity = severity(for: entry)

        if topic == "bridge/health" || suffix == "health_check" {
            return .init(kind: .health, normalizedValue: severity == .failure ? 0 : 1, severity: severity)
        }
        if topic == "bridge/event" {
            return bridgeEventInstrument(payload: payload, severity: severity)
        }
        if suffix == "info" { return .init(kind: .message, severity: severity) }
        if suffix == "options" || suffix.hasSuffix("/options") || suffix.hasSuffix("configure_reporting")
            || suffix.hasSuffix("/configure") { return .init(kind: .options, severity: severity) }
        if suffix == "backup" { return .init(kind: .backup, severity: severity) }
        if suffix == "restart" { return .init(kind: .restart, severity: severity) }
        if suffix == "permit_join" {
            let data = payload["data"]?.object
            let opened = data?["value"]?.boolValue ?? ((data?["time"]?.numberValue ?? 1) > 0)
            return permitJoin(opened: opened, severity: severity)
        }
        if suffix == "networkmap" || suffix == "devices" { return .init(kind: .network, severity: severity) }
        if suffix.hasPrefix("touchlink/") { return .init(kind: .touchlink, severity: severity) }
        if suffix.contains("ota_update") {
            let finished = suffix.hasSuffix("/update") && severity == .success
            let progress = payload["data"]?.object?["progress"]?.numberValue ?? (finished ? 100 : 0)
            return .init(kind: .update, normalizedValue: progress / 100, severity: severity)
        }
        if suffix.contains("interview") || suffix.hasSuffix("/bind") || suffix.hasSuffix("/unbind")
            || suffix.hasPrefix("install_code/") { return .init(kind: .pairing, severity: severity) }
        if suffix.hasPrefix("group/") || suffix == "groups" { return .init(kind: .group, severity: severity) }
        if suffix.contains("rename") { return .init(kind: .lifecycle, severity: severity, variant: .rename) }
        if suffix.contains("remove") { return .init(kind: .lifecycle, severity: severity, variant: .remove) }
        if suffix == "action" { return .init(kind: .action, severity: severity) }
        if topic.hasPrefix("bridge/response/") { return .init(kind: .unknown, severity: severity) }
        return nil
    }

    private static func bridgeEventInstrument(
        payload: [String: JSONValue],
        severity: ActivityInstrumentSeverity
    ) -> ActivityInstrument {
        switch payload["type"]?.stringValue {
        case "device_joined":
            return .init(kind: .lifecycle, normalizedValue: 1, trend: .rising, severity: .success)
        case "device_announce":
            return .init(kind: .signal, normalizedValue: 0.72, severity: severity)
        case "device_leave":
            return .init(kind: .lifecycle, normalizedValue: 0, trend: .falling, severity: .warning)
        case "device_interview":
            return .init(kind: .pairing, severity: severity)
        case "device_options_changed":
            return .init(kind: .options, severity: severity)
        case "scene_added", "scene_removed":
            return .init(kind: .group, severity: severity)
        case "permit_join":
            let opened = payload["data"]?.object?["permit"]?.boolValue ?? true
            return permitJoin(opened: opened, severity: severity)
        case "restart_required":
            return .init(kind: .restart, severity: .warning)
        default:
            return .init(kind: .unknown, severity: severity)
        }
    }

    private static func actionInstrument(for entry: LogEntry) -> ActivityInstrument? {
        guard let action = entry.context?.action else { return nil }
        let severity = severity(for: entry)
        switch action {
        case .otaProgress(let percent):
            return .init(kind: .update, normalizedValue: Double(percent) / 100, severity: severity)
        case .otaFinished:
            return .init(kind: .update, normalizedValue: 1, severity: .success)
        case .bindSuccess:
            return .init(kind: .pairing, normalizedValue: 1, severity: .success)
        case .bindFailure:
            return .init(kind: .pairing, normalizedValue: 0, severity: .failure)
        case .unbind:
            return .init(kind: .pairing, severity: severity)
        case .groupAdd, .groupRemove:
            return .init(kind: .group, severity: severity)
        case .reportingConfigure:
            return .init(kind: .options, severity: severity)
        case .publishFailure, .requestFailure:
            return .init(kind: .message, severity: .failure)
        case .mqttPublish, .bridgeResponse, .stateChange, .general:
            return nil
        }
    }

    private static func severity(for entry: LogEntry) -> ActivityInstrumentSeverity {
        switch entry.level {
        case .error: return .failure
        case .warning: return .warning
        case .debug: return .quiet
        case .info: break
        }
        if entry.bridgeTopicDisplay?.isSuccess == false { return .failure }
        if entry.bridgeTopicDisplay?.isSuccess == true { return .success }

        let message = entry.message.lowercased()
        if entry.category == .interview {
            if message.contains("fail") { return .failure }
            if message.contains("success") { return .success }
        }
        return .routine
    }

    private static func permitJoin(
        opened: Bool,
        severity: ActivityInstrumentSeverity = .routine
    ) -> ActivityInstrument {
        .init(
            kind: .pairing,
            normalizedValue: opened ? 1 : 0,
            severity: opened ? severity : .quiet,
            variant: .permitJoin
        )
    }

    private static func canonical(_ property: String) -> String {
        property.lowercased().replacingOccurrences(of: "-", with: "_")
    }
}
