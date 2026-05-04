import Foundation

struct LogMapperEngine {

    // MARK: - Log message parsing

    static func context(
        message: String,
        namespace: String?,
        knownDevices: Set<String>
    ) -> LogContext {
        if let m = message.firstMatch(of: Z2MLogPatterns.bindFailure) {
            return twoDevice(String(m.from), String(m.to), .bindFailure)
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.bindSuccess) {
            return twoDevice(String(m.from), String(m.to), .bindSuccess)
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.unbind) {
            return twoDevice(String(m.from), String(m.to), .unbind)
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.publishFailure) {
            return oneDevice(String(m.device), .publishFailure(command: String(m.command)))
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.groupAdd) {
            return oneDevice(String(m.device), .groupAdd)
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.groupRemove) {
            return oneDevice(String(m.device), .groupRemove)
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.reportingConfigure) {
            return oneDevice(String(m.device), .reportingConfigure)
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.otaFinished) {
            return oneDevice(String(m.device), .otaFinished)
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.otaProgress),
           let percent = Int(m.percent) {
            return oneDevice(String(m.device), .otaProgress(percent: percent))
        }
        if let m = message.firstMatch(of: Z2MLogPatterns.mqttPublish) {
            var name = String(m.topic)
            if name.hasPrefix("zigbee2mqtt/") { name = String(name.dropFirst("zigbee2mqtt/".count)) }
            // Bridge responses/events carry the real subject inside the payload.
            // Parse `payload '<json>'` from the message to surface it.
            if name.hasPrefix("bridge/"),
               let resolved = bridgeSubject(in: message, topic: name, knownDevices: knownDevices) {
                return oneDevice(resolved, .bridgeResponse)
            }
            // Sub-topics like "<device>/action" or "<device>/availability" should
            // attribute to the parent device so the redundant publish row dedupes
            // against the .deviceState event (handled in AppStore+Events).
            if let slash = name.firstIndex(of: "/") {
                let parent = String(name[..<slash])
                if knownDevices.contains(parent) { return oneDevice(parent, .mqttPublish) }
            }
            return oneDevice(name, .mqttPublish)
        }
        // Fallback: scan all 'quoted' tokens against known device/group names
        let refs = message.matches(of: Z2MLogPatterns.singleQuoted)
            .compactMap { m -> LogContext.DeviceRef? in
                let name = String(m.name)
                guard knownDevices.contains(name) else { return nil }
                return LogContext.DeviceRef(friendlyName: name, role: .subject)
            }
        return LogContext(devices: refs, stateChanges: [], action: .general)
    }

    // MARK: - State diffing

    static func diff(
        _ previous: [String: JSONValue],
        _ next: [String: JSONValue]
    ) -> [LogContext.StateChange] {
        let excluded: Set<String> = ["last_seen", "update", "update_available", "device", "elapsed"]
        var changes: [LogContext.StateChange] = []
        let keys = Set(previous.keys).union(next.keys).subtracting(excluded)

        for key in keys.sorted() {
            let prev = previous[key]
            let curr = next[key]
            if let p = prev, let c = curr, p == c { continue }

            // Null-valued entries mean "not active" — not a meaningful change to surface
            if case .null = curr ?? .null { continue }
            // z2m clears momentary triggers like `action` by publishing an empty
            // string — that's not a meaningful change either.
            if case .string(let s) = curr, s.isEmpty { continue }

            if case .object(let pObj) = prev, case .object(let cObj) = curr {
                let subKeys = Set(pObj.keys).union(cObj.keys)
                for sub in subKeys.sorted() where pObj[sub] != cObj[sub] {
                    let subVal = cObj[sub] ?? .null
                    if case .null = subVal { continue }
                    if case .object = subVal { continue }
                    if case .array = subVal { continue }
                    changes.append(makeChange("\(key).\(sub)", from: pObj[sub], to: subVal))
                }
            } else if case .object = curr ?? .null {
                // New top-level object: recurse into its keys with no "from" values
                if case .object(let cObj) = curr {
                    for sub in cObj.keys.sorted() {
                        let subVal = cObj[sub]!
                        if case .null = subVal { continue }
                        if case .object = subVal { continue }
                        if case .array = subVal { continue }
                        changes.append(makeChange("\(key).\(sub)", from: nil, to: subVal))
                    }
                }
            } else if case .array = curr ?? .null {
                // Skip array-valued top-level keys — not meaningfully displayable
                continue
            } else {
                changes.append(makeChange(key, from: prev, to: curr ?? .null))
            }
        }
        return changes
    }

    static func stateChangeEntry(
        device: String,
        changes: [LogContext.StateChange],
        payload: [String: JSONValue]? = nil
    ) -> LogEntry {
        let ctx = LogContext(
            devices: [.init(friendlyName: device, role: .subject)],
            stateChanges: changes,
            action: .stateChange,
            payload: payload
        )
        let summary = changes.prefix(2).map(\.shortDescription).joined(separator: " · ")
        return LogEntry(
            id: UUID(), timestamp: .now, level: .info,
            category: .stateChange, namespace: "state",
            message: summary, deviceName: device, context: ctx
        )
    }

    // MARK: - Formatting helpers

    static func humanize(_ property: String) -> String {
        let table: [String: String] = [
            "linkquality": "Link Quality", "color_temp": "Color Temperature",
            "color_temp_startup": "Startup Color Temp", "brightness": "Brightness",
            "battery": "Battery", "battery_low": "Battery Low", "state": "State",
            "voltage": "Voltage", "power": "Power", "current": "Current",
            "energy": "Energy", "temperature": "Temperature", "humidity": "Humidity",
            "pressure": "Pressure", "co2": "CO₂", "pm25": "PM2.5",
            "occupancy": "Occupancy", "contact": "Contact",
            "water_leak": "Water Leak", "smoke": "Smoke", "gas": "Gas",
            "color_mode": "Color Mode", "color.x": "Color X", "color.y": "Color Y",
            "color.hue": "Hue", "color.saturation": "Saturation",
            "action": "Action", "action_group": "Action Group",
        ]
        return table[property] ?? property.replacingOccurrences(of: "_", with: " ").capitalized
    }

    static func format(_ value: JSONValue, property: String) -> String {
        switch value {
        case .null: return "—"
        case .bool(let b):
            let asOnOff: Set<String> = ["state", "occupancy", "water_leak", "smoke", "gas"]
            return asOnOff.contains(property) ? (b ? "ON" : "OFF") : (b ? "Yes" : "No")
        case .string(let s): return s.isEmpty ? "—" : s
        case .int(let i):
            if property == "brightness" { return "\(Int((Double(i) / 254.0 * 100).rounded()))%" }
            if property == "color_temp" { return "\(Int((1_000_000.0 / Double(i)).rounded()))K" }
            if property == "battery" || property == "humidity" { return "\(i)%" }
            if Self.minuteDurationProps.contains(property) { return formatMinutesDuration(Double(i)) }
            return "\(i)"
        case .double(let d):
            if property == "temperature" { return String(format: "%.1f°", d) }
            if Self.minuteDurationProps.contains(property) { return formatMinutesDuration(d) }
            return d.formatted(.number.precision(.fractionLength(0...2)))
        default: return value.stringified
        }
    }

    private static let minuteDurationProps: Set<String> = ["filter_age", "device_age"]

    private static func formatMinutesDuration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        if total < 60 { return "\(total) min" }
        let hours = total / 60
        if hours < 48 { return "\(hours) h" }
        let days = hours / 24
        if days < 60 { return "\(days) d" }
        let months = days / 30
        return "\(months) mo"
    }

    // MARK: - Private

    /// Extract the subject of a `bridge/...` MQTT publish from the embedded payload.
    /// Examples:
    ///   bridge/response/device/ota_update/check  → payload.data.id
    ///   bridge/response/device/rename            → payload.data.to
    ///   bridge/event                             → payload.data.friendly_name
    /// On error responses (`status: "error"`) z2m clears `data` and the device name
    /// only appears inside the human-readable `error` string, e.g.
    ///   {"data":{},"error":"Failed ... for 'office_remote' ...","status":"error"}
    /// In that case we scan the error string for a quoted token that matches a
    /// known device name.
    private static func bridgeSubject(
        in message: String, topic: String, knownDevices: Set<String>
    ) -> String? {
        guard let payloadStr = LogEntry.extractPayload(from: message) else { return nil }
        guard let data = payloadStr.data(using: .utf8),
              let payload = try? JSONDecoder().decode([String: JSONValue].self, from: data) else {
            return nil
        }
        if case .object(let inner) = payload["data"] ?? .null {
            if topic.hasSuffix("/rename"), case .string(let to) = inner["to"] ?? .null {
                return to
            }
            if case .string(let id) = inner["id"] ?? .null { return id }
            if case .string(let fn) = inner["friendly_name"] ?? .null { return fn }
        }
        if case .string(let fn) = payload["friendly_name"] ?? .null { return fn }
        // Error path: scan payload.error for a quoted token matching a known device.
        if case .string(let err) = payload["error"] ?? .null {
            for m in err.matches(of: Z2MLogPatterns.singleQuoted) {
                let token = String(m.name)
                if knownDevices.contains(token) { return token }
            }
        }
        return nil
    }

    private static func oneDevice(_ name: String, _ action: LogContext.LogAction) -> LogContext {
        LogContext(devices: [.init(friendlyName: name, role: .subject)], stateChanges: [], action: action)
    }

    private static func twoDevice(_ from: String, _ to: String, _ action: LogContext.LogAction) -> LogContext {
        LogContext(
            devices: [
                .init(friendlyName: from, role: .source),
                .init(friendlyName: to, role: .target),
            ],
            stateChanges: [], action: action
        )
    }

    private static func makeChange(_ property: String, from: JSONValue?, to: JSONValue) -> LogContext.StateChange {
        LogContext.StateChange(
            id: UUID(), property: property, from: from, to: to,
            displayLabel: humanize(property),
            displayFrom: from.map { format($0, property: property) },
            displayTo: format(to, property: property)
        )
    }
}
