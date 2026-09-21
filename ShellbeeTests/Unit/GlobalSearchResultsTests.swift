import XCTest
@testable import Shellbee

@MainActor
final class GlobalSearchResultsTests: XCTestCase {
    private let bridgeA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!

    func testEmptyQueryReturnsNothing() {
        let results = makeResults(query: "   ")

        XCTAssertTrue(results.isEmpty)
    }

    func testTokensMatchInAnyOrderAcrossFields() {
        let results = makeResults(query: "sensor office")

        XCTAssertEqual(results.devices.map(\.device.friendlyName), ["Office Sensor"])
    }

    func testMatchingIgnoresCaseAndDiacritics() {
        let results = makeResults(query: "KÜCHE")

        XCTAssertEqual(results.groups.map(\.group.friendlyName), ["Kuche Lights"])
    }

    func testTitlePrefixRanksBeforeOtherFieldMatches() {
        let results = makeResults(query: "living")

        XCTAssertEqual(results.devices.first?.device.friendlyName, "Living Room Light")
    }

    func testEveryCategoryIsSearched() {
        let results = makeResults(query: "office")

        XCTAssertEqual(results.count(for: .devices), 1)
        XCTAssertEqual(results.count(for: .activity), 1)
        XCTAssertEqual(results.count(for: .logs), 1)
        XCTAssertEqual(results.count(for: .all), 3)
    }

    func testLogResultsKeepChronologicalOrderAndCap() {
        let entries = (0..<(GlobalSearchResults.logLimit + 10)).map { index in
            bound(log(message: "ping \(index)", minutesAgo: index))
        }

        let results = GlobalSearchResults(
            query: "ping", devices: [], groups: [], bridges: [],
            activity: [], logs: entries, docs: []
        )

        XCTAssertEqual(results.logs.count, GlobalSearchResults.logLimit)
        XCTAssertEqual(results.logs.first?.entry.message, "ping 0")
    }

    func testDocsMatchVendorAndModel() {
        let results = makeResults(query: "ikea tradfri")

        XCTAssertEqual(results.docs.map(\.model), ["TRADFRI bulb"])
    }

    // MARK: - Fixtures

    private func makeResults(query: String) -> GlobalSearchResults {
        GlobalSearchResults(
            query: query,
            devices: [
                BridgeBoundDevice(bridgeID: bridgeA, bridgeName: "Home", device: DeviceFixture.sensor(name: "Office Sensor")),
                BridgeBoundDevice(bridgeID: bridgeA, bridgeName: "Home", device: DeviceFixture.light(name: "Living Room Light"))
            ],
            groups: [
                BridgeBoundGroup(
                    bridgeID: bridgeA, bridgeName: "Home",
                    group: Group(id: 5, friendlyName: "Kuche Lights", description: nil, members: [], scenes: [])
                )
            ],
            bridges: [GlobalSearchBridge(id: bridgeA, name: "Home", version: "2.1.0", isConnected: true)],
            activity: [bound(log(message: "state changed", deviceName: "Office Sensor"))],
            logs: [bound(log(message: "MQTT publish: topic 'zigbee2mqtt/Office Sensor'"))],
            docs: [
                DocBrowserEntry(docKey: "tradfri", imageKey: nil, model: "TRADFRI bulb", vendor: "IKEA", description: "Smart bulb", exposes: ["light"])
            ]
        )
    }

    private func log(message: String, deviceName: String? = nil, minutesAgo: Int = 0) -> LogEntry {
        LogEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 1_000_000 - Double(minutesAgo * 60)),
            level: .info,
            category: .general,
            namespace: nil,
            message: message,
            deviceName: deviceName
        )
    }

    private func bound(_ entry: LogEntry) -> BridgeBoundLogEntry {
        BridgeBoundLogEntry(bridgeID: bridgeA, bridgeName: "Home", entry: entry)
    }
}
