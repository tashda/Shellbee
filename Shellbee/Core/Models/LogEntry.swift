import SwiftUI

enum LogLevel: String, CaseIterable, Sendable, Hashable, ChipRepresentable {
    case error
    case warning
    case info
    case debug

    var chipLabel: String { label }
    var chipIcon: String? { systemImage }
    var chipTint: Color { color }

    var label: String {
        switch self {
        case .error: "Error"
        case .warning: "Warning"
        case .info: "Info"
        case .debug: "Debug"
        }
    }

    var systemImage: String {
        switch self {
        case .error: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .info: "info.circle.fill"
        case .debug: "ladybug.fill"
        }
    }

    var color: Color {
        switch self {
        case .error: .red
        case .warning: .yellow
        case .info: .blue
        case .debug: .gray
        }
    }

    init?(raw: String) {
        self.init(rawValue: raw.lowercased())
    }
}

struct LogEntry: Identifiable, Sendable, Hashable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    /// `var` so AppStore+Events can override the category after the entry
    /// is constructed — bridge MQTT publishes start as `.general` from
    /// `LogContext.inferredCategory` and get re-categorised based on the
    /// recognised topic without rebuilding the whole entry.
    var category: LogCategory
    let namespace: String?
    let message: String
    let deviceName: String?
    let context: LogContext?
    /// Set by the view model when consecutive same-device same-kind entries
    /// are coalesced into one displayed row ("Signal drifted ×5"). Always 1
    /// on the canonical entries stored in `AppStore.logEntries`; the view
    /// model produces synthesized copies with a higher count for display.
    var coalescedCount: Int

    init(
        id: UUID, timestamp: Date, level: LogLevel, category: LogCategory,
        namespace: String?, message: String, deviceName: String?, context: LogContext? = nil,
        coalescedCount: Int = 1
    ) {
        self.id = id; self.timestamp = timestamp; self.level = level
        self.category = category; self.namespace = namespace
        self.message = message; self.deviceName = deviceName; self.context = context
        self.coalescedCount = coalescedCount
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    enum MessageKind: Sendable {
        case mqttPublish(device: String, topic: String, payload: [String: JSONValue])
        case simple
    }

    var parsedMessageKind: MessageKind {
        let topicPattern = /topic '([^']+)'/
        guard let topicMatch = message.firstMatch(of: topicPattern) else { return .simple }
        let topic = String(topicMatch.1)

        guard let payloadStr = Self.extractPayload(from: message) else {
            return .mqttPublish(device: topic, topic: topic, payload: [:])
        }
        var payload: [String: JSONValue] = [:]
        
        if let data = payloadStr.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String: JSONValue].self, from: data) {
            payload = decoded
        } else if !payloadStr.isEmpty {
            // Not JSON, but could be a simple value. Store it as "payload" key.
            if let intVal = Int(payloadStr) {
                payload["payload"] = .int(intVal)
            } else if let doubleVal = Double(payloadStr) {
                payload["payload"] = .double(doubleVal)
            } else if payloadStr.lowercased() == "true" || payloadStr.lowercased() == "false" {
                payload["payload"] = .bool(payloadStr.lowercased() == "true")
            } else {
                payload["payload"] = .string(payloadStr)
            }
        }

        var device = topic
        if device.hasPrefix("zigbee2mqtt/") {
            device = String(device.dropFirst("zigbee2mqtt/".count))
        }
        // Bridge responses/events carry the real subject inside the payload.
        // Examples:
        //   bridge/response/device/ota_update/check  → payload.data.id
        //   bridge/response/device/configure         → payload.data.id
        //   bridge/response/device/rename            → payload.data.to (post-rename name)
        //   bridge/event                             → payload.data.friendly_name
        if device.hasPrefix("bridge/") {
            if let resolved = Self.resolveBridgeSubject(topic: device, payload: payload) {
                device = resolved
            }
        }
        return .mqttPublish(device: device, topic: topic, payload: payload)
    }

    /// Extract the JSON payload from a z2m log line of the form
    /// `... topic '<topic>', payload '<json>'` where the JSON itself can contain
    /// single quotes (e.g. `'office_remote'`, `didn't`). The payload always runs
    /// from `payload '` to the final single quote in the string.
    static func extractPayload(from message: String) -> String? {
        guard let range = message.range(of: "payload '") else { return nil }
        let afterOpen = range.upperBound
        guard let lastQuote = message.lastIndex(of: "'"), lastQuote > afterOpen else {
            return nil
        }
        return String(message[afterOpen..<lastQuote])
    }

    private static func resolveBridgeSubject(topic: String, payload: [String: JSONValue]) -> String? {
        if case .object(let data) = payload["data"] ?? .null {
            if topic.hasSuffix("/rename"), case .string(let to) = data["to"] ?? .null {
                return to
            }
            if case .string(let id) = data["id"] ?? .null { return id }
            if case .string(let fn) = data["friendly_name"] ?? .null { return fn }
        }
        if case .string(let fn) = payload["friendly_name"] ?? .null { return fn }
        // Error responses: device name only appears quoted inside `error`.
        if case .string(let err) = payload["error"] ?? .null {
            let pattern = /'([^']+)'/
            if let m = err.firstMatch(of: pattern) { return String(m.1) }
        }
        return nil
    }

    var summaryTitle: String {
        // Recognized bridge topics get a friendly title up front so rows
        // read as "Bridge health check" instead of the raw MQTT topic.
        if let display = bridgeTopicDisplay { return display.title }
        if let name = context?.primaryDevice?.friendlyName { return name }
        if let name = deviceName { return name }
        if case .mqttPublish(let device, _, _) = parsedMessageKind { return device }
        if let ns = namespace { return ns }
        return String(Self.stripZ2MPrefix(message).prefix(60))
    }

    var summarySubtitle: String {
        if let display = bridgeTopicDisplay {
            return display.subtitle ?? ""
        }
        if let ctx = context, !ctx.stateChanges.isEmpty {
            let withFrom = ctx.stateChanges.filter { $0.displayFrom != nil }
            let candidates = withFrom.isEmpty ? ctx.stateChanges : withFrom
            let shown = candidates.prefix(2)
            var parts = shown.map(\.shortDescription)
            let extra = candidates.count - shown.count
            if extra > 0 { parts.append("+\(extra)") }
            return parts.joined(separator: " · ")
        }
        if case .mqttPublish(_, _, let payload) = parsedMessageKind {
            let pairs = payload.sorted { $0.key < $1.key }.prefix(3).map(formatPair)
            let extra = max(payload.count - 3, 0)
            let suffix = extra > 0 ? ", +\(extra) more" : ""
            return pairs.joined(separator: ", ") + suffix
        }
        return Self.stripZ2MPrefix(message)
    }

    /// Friendly bridge-topic display when this entry is an MQTT publish on
    /// a recognized `bridge/response/*` or `bridge/event` topic. Computed
    /// fresh because the canonical topic + payload are derivable from the
    /// raw `message` via `parsedMessageKind` — no model duplication needed.
    var bridgeTopicDisplay: BridgeTopicLabel.Display? {
        guard case .mqttPublish(_, let topic, let payload) = parsedMessageKind else { return nil }
        return BridgeTopicLabel.display(for: topic, payload: payload)
    }

    static func stripZ2MPrefix(_ text: String) -> String {
        guard text.hasPrefix("z2m:") else { return text }
        if let spaceRange = text.range(of: " ") {
            return String(text[spaceRange.upperBound...])
        }
        return text
    }

    private func formatPair(_ pair: (key: String, value: JSONValue)) -> String {
        switch pair.value {
        case .bool(let b): return "\(pair.key): \(b ? "ON" : "OFF")"
        case .string(let s): return "\(pair.key): \(s.prefix(20))"
        case .int(let i): return "\(pair.key): \(i)"
        case .double(let d): return "\(pair.key): \(d)"
        default: return pair.key
        }
    }

    static let previewEntries: [LogEntry] = [
        LogEntry(id: UUID(), timestamp: .now.addingTimeInterval(-30), level: .error, category: .interview, namespace: nil, message: "Interview of 'Motion Sensor' failed", deviceName: "Motion Sensor"),
        LogEntry(id: UUID(), timestamp: .now.addingTimeInterval(-60), level: .warning, category: .general, namespace: "z2m", message: "Failed to ping 'Living Room Light'", deviceName: nil),
        LogEntry(id: UUID(), timestamp: .now.addingTimeInterval(-120), level: .info, category: .deviceJoined, namespace: nil, message: "Device 'Temperature Sensor' joined the network", deviceName: "Temperature Sensor"),
        LogEntry(id: UUID(), timestamp: .now.addingTimeInterval(-180), level: .info, category: .general, namespace: "z2m:mqtt", message: "MQTT publish: topic 'zigbee2mqtt/Living Room Light', payload '{\"state\":\"ON\",\"brightness\":254,\"linkquality\":116}'", deviceName: nil),
        LogEntry(id: UUID(), timestamp: .now.addingTimeInterval(-240), level: .debug, category: .general, namespace: "zh:controller", message: "Received Zigbee message from '0x00158d00045xx000'", deviceName: nil),
    ]
}
