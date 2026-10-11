import XCTest
@testable import Shellbee

@MainActor
final class LogEntryTests: XCTestCase {
    private func entry(_ message: String) -> LogEntry {
        LogEntry(
            id: UUID(), timestamp: .now, level: .info, category: .general,
            namespace: nil, message: message, deviceName: nil
        )
    }

    func testPlainMessageParsesAsSimpleEveryTime() {
        let entry = entry("Zigbee2MQTT started")
        for _ in 0..<2 {
            guard case .simple = entry.parsedMessageKind else { return XCTFail("expected .simple") }
        }
    }

    func testCopiesOfAnEntryAgreeOnTheParsedKind() {
        let original = entry("MQTT publish: topic 'zigbee2mqtt/lamp', payload '{\"state\":\"ON\"}'")
        var copy = original
        copy.category = .stateChange
        for candidate in [original, copy] {
            guard case .mqttPublish(_, let topic, let payload) = candidate.parsedMessageKind else {
                return XCTFail("expected .mqttPublish")
            }
            XCTAssertEqual(topic, "zigbee2mqtt/lamp")
            XCTAssertEqual(payload["state"], .string("ON"))
        }
    }
}
