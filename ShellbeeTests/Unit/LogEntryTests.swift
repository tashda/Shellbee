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
        XCTAssertEqual(String(describing: entry.parsedMessageKind), String(describing: entry.parsedMessageKind))
        guard case .simple = entry.parsedMessageKind else { return XCTFail("expected .simple") }
    }

    func testCopiesOfAnEntryAgreeOnTheParsedKind() {
        let original = entry("MQTT publish: topic 'zigbee2mqtt/lamp', payload '{\"state\":\"ON\"}'")
        var copy = original
        copy.category = .stateChange
        XCTAssertEqual(String(describing: original.parsedMessageKind), String(describing: copy.parsedMessageKind))
    }
}
