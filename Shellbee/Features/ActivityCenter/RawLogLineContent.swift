import Foundation

/// The words on a raw log row: the MQTT topic or log namespace as the
/// title, and the message shortened so a busy stream stays scannable. The
/// sheet behind each row still shows the untouched line.
struct RawLogLineContent: Equatable {
    let title: String
    /// Small tag after the title, such as "mqtt" for publishes.
    let tag: String?
    let message: String

    init(entry: LogEntry) {
        if case .mqttPublish(_, let topic, let payload) = entry.parsedMessageKind {
            title = Self.dropBaseTopic(topic)
            tag = "mqtt"
            message = payload.isEmpty ? LogEntry.stripZ2MPrefix(entry.message) : Self.compact(payload)
        } else {
            title = entry.namespace ?? entry.level.label
            tag = nil
            message = LogEntry.stripZ2MPrefix(entry.message)
        }
    }

    /// `zigbee2mqtt/Office Sensor` → `Office Sensor`. The base topic is the
    /// same on every line, so it only costs width.
    private static func dropBaseTopic(_ topic: String) -> String {
        guard let slash = topic.firstIndex(of: "/") else { return topic }
        let rest = topic[topic.index(after: slash)...]
        return rest.isEmpty ? topic : String(rest)
    }

    /// `brightness 161 · state ON · color {"h":34}`
    static func compact(_ payload: [String: JSONValue]) -> String {
        payload.keys.sorted()
            .map { key in "\(key) \(raw(payload[key] ?? .null))" }
            .joined(separator: " · ")
    }

    private static func raw(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let b): return b ? "true" : "false"
        case .int(let i): return "\(i)"
        case .double(let d): return "\(d)"
        case .string(let s): return s
        case .array, .object:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            guard let data = try? encoder.encode(value) else { return "…" }
            return String(decoding: data, as: UTF8.self)
        }
    }
}
