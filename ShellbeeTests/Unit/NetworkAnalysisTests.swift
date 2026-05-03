import XCTest
@testable import Shellbee

final class NetworkAnalysisTests: XCTestCase {

    // MARK: - online / offline

    @MainActor

    func testOnlineWhenAvailable() {
        XCTAssertTrue(DeviceCondition.online.matches(
            device: dev(), state: [:], isAvailable: true
        ))
    }

    @MainActor

    func testOfflineWhenNotAvailable() {
        XCTAssertTrue(DeviceCondition.offline.matches(
            device: dev(), state: [:], isAvailable: false
        ))
    }

    @MainActor

    func testNotOnlineWhenUnavailable() {
        XCTAssertFalse(DeviceCondition.online.matches(
            device: dev(), state: [:], isAvailable: false
        ))
    }

    @MainActor

    func testAvailabilityOffOnlyMatchesUntrackedDevices() {
        let device = dev()

        XCTAssertTrue(DeviceCondition.availabilityOff.matches(
            device: device, state: [:], availabilityStatus: .untracked
        ))
        XCTAssertFalse(DeviceCondition.online.matches(
            device: device, state: [:], availabilityStatus: .untracked
        ))
        XCTAssertFalse(DeviceCondition.offline.matches(
            device: device, state: [:], availabilityStatus: .untracked
        ))
    }

    // MARK: - batteryLow (threshold = 20)

    @MainActor

    func testBatteryLowBelow20() {
        XCTAssertTrue(DeviceCondition.batteryLow.matches(
            device: dev(), state: ["battery": .int(19)], isAvailable: true
        ))
    }

    @MainActor

    func testBatteryLowExactlyAt20IsNotLow() {
        XCTAssertFalse(DeviceCondition.batteryLow.matches(
            device: dev(), state: ["battery": .int(20)], isAvailable: true
        ))
    }

    @MainActor

    func testBatteryLowWhenNoBatteryKey() {
        // Missing battery → defaults to 100, not low
        XCTAssertFalse(DeviceCondition.batteryLow.matches(
            device: dev(), state: [:], isAvailable: true
        ))
    }

    @MainActor

    func testBatteryLowAt1() {
        XCTAssertTrue(DeviceCondition.batteryLow.matches(
            device: dev(), state: ["battery": .int(1)], isAvailable: true
        ))
    }

    @MainActor

    func testBatteryLowAt0() {
        XCTAssertTrue(DeviceCondition.batteryLow.matches(
            device: dev(), state: ["battery": .int(0)], isAvailable: true
        ))
    }

    // MARK: - weakSignal (threshold = 40)

    @MainActor

    func testWeakSignalBelow40() {
        XCTAssertTrue(DeviceCondition.weakSignal.matches(
            device: dev(), state: ["linkquality": .int(39)], isAvailable: true
        ))
    }

    @MainActor

    func testWeakSignalExactlyAt40IsNotWeak() {
        XCTAssertFalse(DeviceCondition.weakSignal.matches(
            device: dev(), state: ["linkquality": .int(40)], isAvailable: true
        ))
    }

    @MainActor

    func testWeakSignalWhenNoLQIKey() {
        // Missing LQI → defaults to 999, not weak
        XCTAssertFalse(DeviceCondition.weakSignal.matches(
            device: dev(), state: [:], isAvailable: true
        ))
    }

    // MARK: - updatesAvailable

    @MainActor

    func testUpdatesAvailableWhenOTAReady() {
        let state = StateFixture.withOTA(state: "available", installed: 1, latest: 2)
        XCTAssertTrue(DeviceCondition.updatesAvailable.matches(
            device: dev(), state: state, isAvailable: true
        ))
    }

    @MainActor

    func testUpdatesAvailableWhenSameVersion() {
        let state = StateFixture.withOTA(state: "available", installed: 2, latest: 2)
        XCTAssertFalse(DeviceCondition.updatesAvailable.matches(
            device: dev(), state: state, isAvailable: true
        ))
    }

    // MARK: - interviewing

    @MainActor

    func testInterviewingWhenFlagSet() {
        var d = DeviceFixture.sensor()
        // Create a device that is interviewing
        let interviewing = Device(
            ieeeAddress: d.ieeeAddress, type: d.type, networkAddress: d.networkAddress,
            supported: d.supported, friendlyName: d.friendlyName, disabled: d.disabled,
            description: d.description, definition: d.definition,
            powerSource: d.powerSource, modelId: d.modelId, manufacturer: d.manufacturer,
            interviewCompleted: false, interviewing: true,
            softwareBuildId: nil, dateCode: nil, endpoints: nil, options: nil
        )
        XCTAssertTrue(DeviceCondition.interviewing.matches(
            device: interviewing, state: [:], isAvailable: false
        ))
    }

    @MainActor

    func testNotInterviewingWhenComplete() {
        XCTAssertFalse(DeviceCondition.interviewing.matches(
            device: dev(), state: [:], isAvailable: true
        ))
    }

    // MARK: - unsupported

    @MainActor

    func testUnsupported() {
        let unsupported = Device(
            ieeeAddress: "0x1", type: .endDevice, networkAddress: 1,
            supported: false, friendlyName: "Unknown", disabled: false,
            description: nil, definition: nil,
            powerSource: "Battery", modelId: nil, manufacturer: nil,
            interviewCompleted: true, interviewing: false,
            softwareBuildId: nil, dateCode: nil, endpoints: nil, options: nil
        )
        XCTAssertTrue(DeviceCondition.unsupported.matches(
            device: unsupported, state: [:], isAvailable: false
        ))
    }

    @MainActor

    func testSupportedDeviceNotUnsupported() {
        XCTAssertFalse(DeviceCondition.unsupported.matches(
            device: dev(), state: [:], isAvailable: true
        ))
    }

    // MARK: - Helpers

    private func dev() -> Device { DeviceFixture.sensor() }
}
