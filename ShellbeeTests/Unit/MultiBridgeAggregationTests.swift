import XCTest
@testable import Shellbee

/// Coverage for merged multi-bridge attribution without opening live sessions.
final class MultiBridgeAggregationTests: XCTestCase {
    @MainActor
    func testDevicesAggregateAcrossBridgesWithTheirAttribution() async {
        let mainID = UUID()
        let labID = UUID()
        let snapshots = [
            snapshot(id: mainID, name: "Main", devices: [makeDevice(ieee: "0x1", name: "OfficeLight")]),
            snapshot(id: labID, name: "Lab", devices: [
                makeDevice(ieee: "0x2", name: "LabSensor"),
                makeDevice(ieee: "0x3", name: "LabPlug"),
            ]),
        ]

        let merged = BridgeDataAggregation.devices(from: snapshots)

        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(Set(merged.map(\.bridgeName)), ["Main", "Lab"])
        XCTAssertEqual(Set(merged.map(\.device.friendlyName)), ["OfficeLight", "LabSensor", "LabPlug"])
    }

    @MainActor
    func testDeviceIDsAreNamespacedAcrossBridges() async {
        let snapshots = [
            snapshot(id: UUID(), name: "Main", devices: [makeDevice(ieee: "0x1", name: "Sensor")]),
            snapshot(id: UUID(), name: "Lab", devices: [makeDevice(ieee: "0x1", name: "Sensor")]),
        ]

        let merged = BridgeDataAggregation.devices(from: snapshots)

        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(Set(merged.map(\.id)).count, 2,
            "Identifiable.id must namespace by bridgeID — duplicate IEEEs across bridges are valid.")
    }

    @MainActor
    func testGroupsKeepTheirSourceBridge() async {
        let mainID = UUID()
        let labID = UUID()
        let snapshots = [
            snapshot(id: mainID, name: "Main", groups: [makeGroup(id: 1, name: "Downstairs")]),
            snapshot(id: labID, name: "Lab", groups: [makeGroup(id: 2, name: "Workshop")]),
        ]

        let merged = BridgeDataAggregation.groups(from: snapshots)

        XCTAssertEqual(merged.map(\.bridgeID), [mainID, labID])
        XCTAssertEqual(merged.map(\.bridgeName), ["Main", "Lab"])
    }

    @MainActor
    func testLogEntriesAreSortedNewestFirstAndAttributed() async {
        let mainID = UUID()
        let labID = UUID()
        let now = Date()
        let snapshots = [
            snapshot(id: mainID, name: "Main", logEntries: [
                makeLog(message: "A_old", at: now.addingTimeInterval(-60)),
                makeLog(message: "A_new", at: now),
            ]),
            snapshot(id: labID, name: "Lab", logEntries: [
                makeLog(message: "B_mid", at: now.addingTimeInterval(-30)),
            ]),
        ]

        let merged = BridgeDataAggregation.logEntries(from: snapshots)

        XCTAssertEqual(merged.map(\.entry.message), ["A_new", "B_mid", "A_old"])
        XCTAssertEqual(merged.map(\.bridgeID), [mainID, labID, mainID])
    }

    @MainActor
    private func snapshot(
        id: UUID,
        name: String,
        devices: [Device] = [],
        groups: [Group] = [],
        logEntries: [LogEntry] = []
    ) -> BridgeDataSnapshot {
        BridgeDataSnapshot(
            bridgeID: id,
            bridgeName: name,
            devices: devices,
            groups: groups,
            logEntries: logEntries
        )
    }

    @MainActor
    private func makeGroup(id: Int, name: String) -> Group {
        Group(id: id, friendlyName: name, members: [], scenes: [])
    }

    @MainActor
    private func makeDevice(ieee: String, name: String) -> Device {
        Device(
            ieeeAddress: ieee,
            type: .router,
            networkAddress: 0,
            supported: true,
            friendlyName: name,
            disabled: false,
            interviewCompleted: true,
            interviewing: false
        )
    }

    @MainActor
    private func makeLog(message: String, at timestamp: Date) -> LogEntry {
        LogEntry(
            id: UUID(),
            timestamp: timestamp,
            level: .info,
            category: .general,
            namespace: nil,
            message: message,
            deviceName: nil
        )
    }
}
