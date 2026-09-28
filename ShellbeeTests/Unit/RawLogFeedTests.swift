import XCTest
@testable import Shellbee

@MainActor
final class RawLogFeedTests: XCTestCase {
    private let bridge = UUID()
    private let base = Date(timeIntervalSince1970: 1_800_000_000) // on a minute boundary

    func testLinesGroupIntoNewestFirstMinuteBlocks() {
        let entries = [
            line(secondsAfterBase: 125),
            line(secondsAfterBase: 70),
            line(secondsAfterBase: 61),
            line(secondsAfterBase: 5)
        ]

        let blocks = RawLogBlock.blocks(from: entries, calendar: utc)

        XCTAssertEqual(blocks.map(\.lines.count), [1, 2, 1])
        XCTAssertEqual(blocks.map(\.minute), [
            base.addingTimeInterval(120), base.addingTimeInterval(60), base
        ])
    }

    func testNoLinesProducesNoBlocks() {
        XCTAssertTrue(RawLogBlock.blocks(from: []).isEmpty)
    }

    func testMQTTPublishShowsTopicWithoutBaseAndCompactPayload() {
        let entry = LogEntry(
            id: UUID(), timestamp: base, level: .info, category: .general, namespace: "z2m:mqtt",
            message: "z2m:mqtt: MQTT publish: topic 'zigbee2mqtt/bedroom_lamp', payload '{\"state\":\"ON\",\"brightness\":254,\"color\":{\"x\":0.3}}'",
            deviceName: nil
        )

        let content = RawLogLineContent(entry: entry)

        XCTAssertEqual(content.title, "bedroom_lamp")
        XCTAssertEqual(content.tag, "mqtt")
        XCTAssertEqual(content.message, "brightness 254 · color {\"x\":0.3} · state ON")
    }

    func testPlainLineShowsNamespaceAndMessage() {
        let entry = LogEntry(
            id: UUID(), timestamp: base, level: .warning, category: .general, namespace: "z2m",
            message: "z2m: Failed to ping 'Hallway Motion'", deviceName: nil
        )

        let content = RawLogLineContent(entry: entry)

        XCTAssertEqual(content.title, "z2m")
        XCTAssertNil(content.tag)
        XCTAssertEqual(content.message, "Failed to ping 'Hallway Motion'")
    }

    func testRowPositionsShapeTheCard() {
        XCTAssertEqual(RawLogRow.Position(index: 0, count: 1), .only)
        XCTAssertEqual(RawLogRow.Position(index: 0, count: 3), .first)
        XCTAssertEqual(RawLogRow.Position(index: 1, count: 3), .middle)
        XCTAssertEqual(RawLogRow.Position(index: 2, count: 3), .last)
    }

    // MARK: - Helpers

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func line(secondsAfterBase: TimeInterval) -> BridgeBoundLogEntry {
        BridgeBoundLogEntry(
            bridgeID: bridge,
            bridgeName: "Bridge",
            entry: LogEntry(
                id: UUID(), timestamp: base.addingTimeInterval(secondsAfterBase), level: .info,
                category: .general, namespace: "z2m", message: "line", deviceName: nil
            )
        )
    }
}
