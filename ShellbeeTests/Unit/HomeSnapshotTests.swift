import XCTest
@testable import Shellbee

@MainActor
final class HomeSnapshotTests: XCTestCase {

    // Behavior: totalDevices excludes the coordinator. Router and
    // end-device counts (used in MeshDetailView's Topology section)
    // likewise ignore the coordinator.
    func testCountsExcludeCoordinator() {
        let devices = [
            DeviceFixture.coordinator(),
            DeviceFixture.light(),
            DeviceFixture.switchPlug(),
            DeviceFixture.sensor(),
        ]
        let snapshot = HomeSnapshot(
            devices: devices,
            availability: [:],
            states: [:],
            isConnected: true,
            isBridgeOnline: true,
            groupCount: 0,
            bridgeVersion: nil,
            bridgeCommit: nil,
            coordinatorType: nil,
            coordinatorIEEEAddress: nil,
            networkChannel: nil,
            panID: nil,
            isPermitJoinActive: false,
            permitJoinEnd: nil,
            restartRequired: false
        )
        XCTAssertEqual(snapshot.totalDevices, 3)
        XCTAssertEqual(snapshot.routerCount, 2,  "light and plug are routers")
        XCTAssertEqual(snapshot.endDeviceCount, 1, "sensor is an end device")
    }

    func testAvailabilityDisabledDeviceDoesNotCountOffline() {
        var remote = DeviceFixture.remote(name: "Untracked Remote")
        remote.options = ["availability": .bool(false)]

        let snapshot = makeSnapshot(
            devices: [remote],
            availability: [remote.friendlyName: false],
            states: [:]
        )

        XCTAssertEqual(snapshot.totalDevices, 1)
        XCTAssertEqual(snapshot.onlineDevices, 0)
        XCTAssertEqual(snapshot.offlineDevices, 0)
        XCTAssertEqual(snapshot.availabilityOffDevices, 1)
    }

    func testAvailabilityOffDeviceDoesNotCountOffline() {
        var remote = DeviceFixture.remote(
            ieee: "0x00000000000000f1",
            name: "Untracked Remote"
        )
        remote.availability = .bool(false)

        let snapshot = makeSnapshot(
            devices: [remote],
            availability: [remote.friendlyName: false],
            states: [:]
        )

        XCTAssertEqual(snapshot.totalDevices, 1)
        XCTAssertEqual(snapshot.onlineDevices, 0)
        XCTAssertEqual(snapshot.offlineDevices, 0)
        XCTAssertEqual(snapshot.availabilityOffDevices, 1)
    }

    // Behavior: averageLinkQuality is the integer mean of linkQuality
    // values reported across non-coordinator devices, and is nil when
    // no device reports a linkQuality. This powers Mesh → Average LQI.
    func testAverageLinkQualityHandlesMissingValues() {
        let devices = [DeviceFixture.light(), DeviceFixture.switchPlug()]

        let emptySnapshot = makeSnapshot(devices: devices, states: [:])
        XCTAssertNil(emptySnapshot.averageLinkQuality)

        let states: [String: [String: JSONValue]] = [
            DeviceFixture.light().friendlyName: StateFixture.lightOn(lqi: 140),
            DeviceFixture.switchPlug().friendlyName: ["linkquality": .int(180)],
        ]
        let populated = makeSnapshot(devices: devices, states: states)
        XCTAssertEqual(populated.averageLinkQuality, 160)
    }

    // Behavior: lowBatteryDevices / weakSignalDevices drive the Home
    // "n low battery" / "n weak signal" banners. Thresholds come from
    // DesignTokens.Threshold.
    func testLowBatteryAndWeakSignalCounts() {
        let devices = [
            DeviceFixture.sensor(),
            DeviceFixture.sensor(ieee: "0x00158d000000abcd", name: "Bed Sensor"),
        ]
        let states: [String: [String: JSONValue]] = [
            "Office Sensor": StateFixture.batteryLow(level: 10),
            "Bed Sensor":    StateFixture.weakSignal(lqi: 10),
        ]
        let snapshot = makeSnapshot(devices: devices, states: states)
        XCTAssertEqual(snapshot.lowBatteryDevices, 1)
        XCTAssertEqual(snapshot.weakSignalDevices, 1)
    }

    // Behavior: the PAN ID label shown on MeshDetailView formats the raw
    // integer as "PAN 0xXXXX" (uppercase, 4-digit zero-padded).
    func testPanIDTextFormatting() {
        let snapshot = makeSnapshot(devices: [], states: [:], panID: 0x0A3F)
        XCTAssertEqual(snapshot.panIDText, "PAN 0x0A3F")
    }

    // Behavior: permitJoinRemaining is derived from the absolute
    // permitJoinEnd timestamp (ms since epoch). A future end returns
    // the seconds remaining; a past end clamps to 0; nil returns nil.
    func testPermitJoinRemainingDerivation() {
        let future = Int(Date().timeIntervalSince1970 * 1000) + 30_000
        let past = Int(Date().timeIntervalSince1970 * 1000) - 30_000

        let active = makeSnapshot(devices: [], states: [:],
                                  isPermitJoinActive: true, permitJoinEnd: future)
        XCTAssertNotNil(active.permitJoinRemaining)
        XCTAssertLessThanOrEqual(active.permitJoinRemaining ?? 0, 30)
        XCTAssertGreaterThan(active.permitJoinRemaining ?? 0, 25)

        let expired = makeSnapshot(devices: [], states: [:], permitJoinEnd: past)
        XCTAssertEqual(expired.permitJoinRemaining, 0)

        let none = makeSnapshot(devices: [], states: [:])
        XCTAssertNil(none.permitJoinRemaining)
    }

    // Behavior: devicesWithUpdates counts devices whose state includes
    // an `update` object with state == "available". Used by the Home
    // bridge card banner "n updates available".
    func testDevicesWithUpdatesCount() {
        let devices = [
            DeviceFixture.light(),
            DeviceFixture.light(ieee: "0xB", name: "Bedroom Light"),
        ]
        let states: [String: [String: JSONValue]] = [
            DeviceFixture.light().friendlyName: StateFixture.withOTA(state: "available"),
            "Bedroom Light": StateFixture.lightOn(),
        ]
        let snapshot = makeSnapshot(devices: devices, states: states)
        XCTAssertEqual(snapshot.devicesWithUpdates, 1)
    }

    private func makeSnapshot(
        devices: [Device],
        availability: [String: Bool] = [:],
        states: [String: [String: JSONValue]],
        panID: Int? = nil,
        isPermitJoinActive: Bool = false,
        permitJoinEnd: Int? = nil
    ) -> HomeSnapshot {
        HomeSnapshot(
            devices: devices,
            availability: availability,
            states: states,
            isConnected: true,
            isBridgeOnline: true,
            groupCount: 0,
            bridgeVersion: nil,
            bridgeCommit: nil,
            coordinatorType: nil,
            coordinatorIEEEAddress: nil,
            networkChannel: nil,
            panID: panID,
            isPermitJoinActive: isPermitJoinActive,
            permitJoinEnd: permitJoinEnd,
            restartRequired: false
        )
    }
}
