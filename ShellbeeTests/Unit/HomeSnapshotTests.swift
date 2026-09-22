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

    // Regression: the Home banner and the status filter it deep-links into must
    // agree on every side of the threshold.
    func testLowBatteryCountAgreesWithStatusFilterAcrossThreshold() {
        let sensor = DeviceFixture.sensor()
        let threshold = DesignTokens.Threshold.lowBattery
        for level in [threshold - 1, threshold, threshold + 1] {
            let state = StateFixture.batteryLow(level: level)
            let snapshot = makeSnapshot(devices: [sensor], states: [sensor.friendlyName: state])
            let matchesFilter = DeviceCondition.batteryLow.matches(
                device: sensor, state: state, isAvailable: true
            )
            XCTAssertEqual(snapshot.lowBatteryDevices == 1, matchesFilter, "battery \(level)")
        }
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

    // MARK: - Captions and calm
    //
    // Home carries trouble in the figures themselves: a red count with a
    // caption under it. These cover the caption sources and the "nothing to
    // report" state that collapses a card to one line.

    // Behavior: the Offline caption is built from the oldest last_seen among
    // unreachable devices, so it says how long the quiet has lasted rather
    // than repeating the count.
    func testOfflineCaptionUsesOldestSilence() {
        let recent = DeviceFixture.sensor(name: "Hall Sensor")
        let stale = DeviceFixture.sensor(name: "Shed Sensor")
        let now = Date()
        let states: [String: [String: JSONValue]] = [
            recent.friendlyName: ["last_seen": .string(Self.iso(now.addingTimeInterval(-600)))],
            stale.friendlyName: ["last_seen": .string(Self.iso(now.addingTimeInterval(-10_800)))],
        ]
        let snapshot = makeSnapshot(
            devices: [recent, stale],
            availability: [recent.friendlyName: false, stale.friendlyName: false],
            states: states
        )
        XCTAssertEqual(snapshot.offlineDevices, 2)
        XCTAssertEqual(snapshot.offlineCaption, "3h+ quiet",
                       "the caption reports the longest silence, not the shortest")
    }

    // Behavior: no offline devices means no caption. A cell only gets a
    // caption when there is something true to put under it.
    func testOfflineCaptionAbsentWhenEverythingAnswers() {
        let sensor = DeviceFixture.sensor()
        let snapshot = makeSnapshot(
            devices: [sensor],
            availability: [sensor.friendlyName: true],
            states: [sensor.friendlyName: StateFixture.lightOn()]
        )
        XCTAssertNil(snapshot.offlineCaption)
    }

    // Behavior: the battery and signal captions name the worst offender, so
    // "2" reads as "2, and the worst is at 8%".
    func testBatteryAndSignalCaptionsNameTheWorstOffender() {
        let weak = DeviceFixture.sensor(name: "Attic Sensor")
        let flat = DeviceFixture.remote(name: "Porch Remote")
        let snapshot = makeSnapshot(
            devices: [weak, flat],
            availability: [weak.friendlyName: true, flat.friendlyName: true],
            states: [
                weak.friendlyName: StateFixture.weakSignal(lqi: 12),
                flat.friendlyName: StateFixture.batteryLow(level: 8),
            ]
        )
        XCTAssertEqual(snapshot.lowBatteryCaption, "lowest 8%")
        XCTAssertEqual(snapshot.weakSignalCaption, "lowest 12")
    }

    // Behavior: a network with nothing wrong is calm, so its cards collapse.
    // A firmware update waiting is deliberately NOT trouble — it rides along
    // in the collapsed line instead of forcing the card open.
    func testCalmIgnoresPendingFirmwareUpdates() {
        let light = DeviceFixture.light(name: "Bedroom Light")
        var states = StateFixture.lightOn()
        states["update"] = .object(["state": .string("available")])
        let snapshot = makeSnapshot(
            devices: [light],
            availability: [light.friendlyName: true],
            states: [light.friendlyName: states]
        )
        XCTAssertTrue(snapshot.devicesAreCalm)
        XCTAssertTrue(snapshot.networkIsCalm)
        XCTAssertEqual(snapshot.devicesWithUpdates, 1)
    }

    // Behavior: one unreachable device is enough to keep the Devices card open.
    func testOneOfflineDeviceBreaksCalm() {
        let sensor = DeviceFixture.sensor()
        let offline = makeSnapshot(
            devices: [sensor],
            availability: [sensor.friendlyName: false],
            states: [sensor.friendlyName: StateFixture.lightOn()]
        )
        XCTAssertFalse(offline.devicesAreCalm)
        XCTAssertEqual(offline.deviceAttentionCount, 1)
    }

    // Behavior: permit join does NOT break the Network card's calm. The
    // pinned "right now" card owns everything in flight — if this card
    // reported it too, Home would say the same thing twice.
    func testPermitJoinIsOwnedByThePinnedCardNotTheNetworkCard() {
        let sensor = DeviceFixture.sensor()
        let joining = makeSnapshot(
            devices: [sensor],
            availability: [sensor.friendlyName: true],
            states: [sensor.friendlyName: StateFixture.lightOn()],
            isPermitJoinActive: true
        )
        XCTAssertTrue(joining.networkIsCalm)
        XCTAssertTrue(joining.isPermitJoinActive)
    }

    // Behavior: the compact duration is short enough to sit under a figure in
    // a three-across row, and rounds down to the unit it names.
    func testCompactDurationUnits() {
        let now = Date()
        XCTAssertEqual(HomeSnapshot.compactDuration(since: now.addingTimeInterval(-30), now: now), "1m+",
                       "under a minute still reads as a minute, never 0m")
        XCTAssertEqual(HomeSnapshot.compactDuration(since: now.addingTimeInterval(-900), now: now), "15m+")
        XCTAssertEqual(HomeSnapshot.compactDuration(since: now.addingTimeInterval(-7_200), now: now), "2h+")
        XCTAssertEqual(HomeSnapshot.compactDuration(since: now.addingTimeInterval(-172_800), now: now), "2d+")
    }

    private static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
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
