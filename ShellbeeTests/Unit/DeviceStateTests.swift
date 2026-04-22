import XCTest
@testable import Shellbee

final class DeviceStateTests: XCTestCase {

    // MARK: - battery

    @MainActor

    func testBatteryPresent() {
        let state: [String: JSONValue] = ["battery": .int(75)]
        XCTAssertEqual(state.battery, 75)
    }

    @MainActor

    func testBatteryAbsent() {
        let state: [String: JSONValue] = [:]
        XCTAssertNil(state.battery)
    }

    // MARK: - linkQuality

    @MainActor

    func testLinkQualityPresent() {
        let state: [String: JSONValue] = ["linkquality": .int(142)]
        XCTAssertEqual(state.linkQuality, 142)
    }

    @MainActor

    func testLinkQualityAbsent() {
        let state: [String: JSONValue] = [:]
        XCTAssertNil(state.linkQuality)
    }

    // MARK: - hasUpdateAvailable

    @MainActor

    func testHasUpdateAvailableTrue() {
        let state: [String: JSONValue] = [
            "update": .object([
                "state": .string("available"),
                "installed_version": .int(1),
                "latest_version": .int(2)
            ])
        ]
        XCTAssertTrue(state.hasUpdateAvailable)
    }

    @MainActor

    func testHasUpdateAvailableFalse_sameVersions() {
        let state: [String: JSONValue] = [
            "update": .object([
                "state": .string("available"),
                "installed_version": .int(2),
                "latest_version": .int(2)
            ])
        ]
        XCTAssertFalse(state.hasUpdateAvailable)
    }

    @MainActor

    func testHasUpdateAvailableFalse_stateIsIdle() {
        let state: [String: JSONValue] = [
            "update": .object([
                "state": .string("idle"),
                "installed_version": .int(1),
                "latest_version": .int(2)
            ])
        ]
        XCTAssertFalse(state.hasUpdateAvailable)
    }

    @MainActor

    func testHasUpdateAvailableFalse_noUpdateKey() {
        let state: [String: JSONValue] = ["linkquality": .int(100)]
        XCTAssertFalse(state.hasUpdateAvailable)
    }

    @MainActor

    func testIsUpdating() {
        let state: [String: JSONValue] = [
            "update": .object(["state": .string("updating"), "progress": .double(50)])
        ]
        XCTAssertTrue(state.isUpdating)
    }

    // MARK: - lastSeen (epoch ms)

    @MainActor

    func testLastSeenEpoch() {
        let epoch = 1_700_000_000_000.0  // 2023-11-14 in ms
        let state: [String: JSONValue] = ["last_seen": .double(epoch)]
        let date = state.lastSeen
        XCTAssertNotNil(date)
        XCTAssertEqual(date!.timeIntervalSince1970, epoch / 1000, accuracy: 0.1)
    }

    @MainActor

    func testLastSeenISO8601() {
        let state: [String: JSONValue] = ["last_seen": .string("2023-11-14T10:00:00+00:00")]
        XCTAssertNotNil(state.lastSeen)
    }

    @MainActor

    func testLastSeenISO8601WithFractional() {
        let state: [String: JSONValue] = ["last_seen": .string("2023-11-14T10:00:00.123+00:00")]
        XCTAssertNotNil(state.lastSeen)
    }

    @MainActor

    func testLastSeenAbsent() {
        let state: [String: JSONValue] = [:]
        XCTAssertNil(state.lastSeen)
    }

    @MainActor

    func testLastSeenInvalidString() {
        let state: [String: JSONValue] = ["last_seen": .string("not-a-date")]
        XCTAssertNil(state.lastSeen)
    }

    // MARK: - otaUpdateStatus

    @MainActor

    func testOTAUpdateStatusAvailable() {
        let state = StateFixture.withOTA(state: "available", installed: 1, latest: 2)
        let status = state.otaUpdateStatus(for: "TestDevice")
        XCTAssertNotNil(status)
        XCTAssertEqual(status?.phase, .available)
        XCTAssertEqual(status?.deviceName, "TestDevice")
    }

    @MainActor

    func testOTAUpdateStatusUpdating() {
        let state: [String: JSONValue] = [
            "update": .object([
                "state": .string("updating"),
                "progress": .double(75.0),
                "remaining": .int(120)
            ])
        ]
        let status = state.otaUpdateStatus(for: "Dev")
        XCTAssertEqual(status?.phase, .updating)
        XCTAssertEqual(status?.progress, 75.0)
        XCTAssertEqual(status?.remaining, 120)
    }

    @MainActor

    func testOTAUpdateStatusNilWhenNoUpdateKey() {
        let state: [String: JSONValue] = ["battery": .int(100)]
        XCTAssertNil(state.otaUpdateStatus(for: "Dev"))
    }

    @MainActor

    func testOTAUpdateStatusNilWhenUnknownPhase() {
        let state: [String: JSONValue] = [
            "update": .object(["state": .string("unknown_phase")])
        ]
        XCTAssertNil(state.otaUpdateStatus(for: "Dev"))
    }
}
