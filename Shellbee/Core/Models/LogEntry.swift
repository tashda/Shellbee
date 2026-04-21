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
    let category: LogCategory
    let namespace: String?
    let message: String
    let deviceName: String?
    let context: LogContext?

    init(
        id: UUID, timestamp: Date, level: LogLevel, category: LogCategory,
        namespace: String?, message: String, deviceName: String?, context: LogContext? = nil
    ) {
        self.id = id; self.timestamp = timestamp; self.level = level
        self.category = category; self.namespace = namespace
        self.message = message; self.deviceName = deviceName; self.context = context
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }

    enum MessageKind: Sendable {
        case mqttPublish(device: String, topic: String, payload: [String: JSONValue])
        case simple
    }

    var parsedMessageKind: MessageKind {
        // Find the topic and payload within single quotes
        // We look for: topic '([^']+)' and payload '([^']*)'
        let topicPattern = /topic '([^']+)'/
        let payloadPattern = /payload '([^']*)'/
        
        guard let topicMatch = message.firstMatch(of: topicPattern) else { return .simple }
        let topic = String(topicMatch.1)
        
        guard let payloadMatch = message.firstMatch(of: payloadPattern) else {
            return .mqttPublish(device: topic, topic: topic, payload: [:])
        }
        
        let payloadStr = String(payloadMatch.1)
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
        return .mqttPublish(device: device, topic: topic, payload: payload)
    }

    var summaryTitle: String {
        if let name = context?.primaryDevice?.friendlyName { return name }
        if let name = deviceName { return name }
        if case .mqttPublish(let device, _, _) = parsedMessageKind { return device }
        if let ns = namespace { return ns }
        return String(message.prefix(60))
    }

    var summarySubtitle: String {
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
        return message
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
