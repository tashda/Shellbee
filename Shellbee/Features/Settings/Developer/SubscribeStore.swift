import SwiftUI

/// Captures every inbound MQTT message routed through the active session
/// and exposes a filtered, capped view suitable for the MQTT Inspector's
/// Subscribe tab. Backed by `ConnectionSessionController.rawInboundTap`.
@Observable
final class SubscribeStore {
    var messages: [InspectorMessage] = []
    var paused: Bool = false
    var filter: String = ""
    let bufferCap: Int = 1000

    func attach(session: ConnectionSessionController) {
        session.rawInboundTap = { [weak self] topic, payload in
            guard let self, !self.paused else { return }
            let msg = InspectorMessage(timestamp: .now, topic: topic, payload: payload)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.messages.append(msg)
                if self.messages.count > self.bufferCap {
                    self.messages.removeFirst(self.messages.count - self.bufferCap)
                }
            }
        }
    }

    func detach(session: ConnectionSessionController) {
        session.rawInboundTap = nil
    }

    func clear() {
        messages.removeAll()
    }

    var filtered: [InspectorMessage] {
        let f = filter.trimmingCharacters(in: .whitespaces)
        guard !f.isEmpty else { return messages }
        return messages.filter { $0.topic.localizedCaseInsensitiveContains(f) }
    }
}

struct InspectorMessage: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let topic: String
    let payload: JSONValue

    var prettyPayload: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }

    /// Z2M log messages on `bridge/logging` carry a `level` field — surface
    /// that color on the row icon to match the raw logs view.
    var logLevelColor: Color {
        guard topic == Z2MTopics.bridgeLogging,
              let level = payload.object?["level"]?.stringValue,
              let parsed = LogLevel(rawValue: level.lowercased()) else {
            return .secondary
        }
        return parsed.color
    }

    var logLevelIcon: String {
        guard topic == Z2MTopics.bridgeLogging,
              let level = payload.object?["level"]?.stringValue,
              let parsed = LogLevel(rawValue: level.lowercased()) else {
            return "dot.radiowaves.up.forward"
        }
        return parsed.systemImage
    }
}
