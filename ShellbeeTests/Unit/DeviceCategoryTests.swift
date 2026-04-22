import XCTest
@testable import Shellbee

final class DeviceCategoryTests: XCTestCase {

    @MainActor
    func testLightCategory() {
        XCTAssertEqual(DeviceFixture.light().category, .light)
    }

    @MainActor
    func testColorLightCategory() {
        XCTAssertEqual(DeviceFixture.light(colorCapable: true).category, .light)
    }

    @MainActor
    func testSwitchPlugCategory() {
        XCTAssertEqual(DeviceFixture.switchPlug().category, .switchPlug)
    }

    @MainActor
    func testSensorCategory() {
        XCTAssertEqual(DeviceFixture.sensor().category, .sensor)
    }

    @MainActor
    func testClimateCategory() {
        XCTAssertEqual(DeviceFixture.climate().category, .climate)
    }

    @MainActor
    func testCoverCategory() {
        XCTAssertEqual(DeviceFixture.cover().category, .cover)
    }

    @MainActor
    func testLockCategory() {
        XCTAssertEqual(DeviceFixture.lock().category, .lock)
    }

    @MainActor
    func testFanCategory() {
        XCTAssertEqual(DeviceFixture.fan().category, .fan)
    }

    @MainActor
    func testRemoteCategory() {
        XCTAssertEqual(DeviceFixture.remote().category, .remote)
    }

    @MainActor
    func testNoExposes_returnsRemote() {
        let noExposeDevice = Device(
            ieeeAddress: "0xfeed", type: .endDevice, networkAddress: 1,
            supported: true, friendlyName: "Mystery",
            disabled: false, description: nil, definition: nil,
            powerSource: "Battery", modelId: nil, manufacturer: nil,
            interviewCompleted: true, interviewing: false,
            softwareBuildId: nil, dateCode: nil, endpoints: nil, options: nil
        )
        XCTAssertEqual(noExposeDevice.category, .remote)
    }

    @MainActor
    func testLightTakesPriorityOverSwitch() {
        let lightExpose = Expose(
            type: "light", name: "light", label: "Light", description: nil,
            access: 0, property: nil, endpoint: nil, features: [], options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil, values: nil,
            valueOn: nil, valueOff: nil, presets: nil
        )
        let switchExpose = Expose(
            type: "switch", name: "switch", label: "Switch", description: nil,
            access: 0, property: nil, endpoint: nil, features: [], options: nil,
            unit: nil, valueMin: nil, valueMax: nil, valueStep: nil, values: nil,
            valueOn: nil, valueOff: nil, presets: nil
        )
        let def = DeviceDefinition(
            model: "X", vendor: "X", description: "",
            supportsOTA: false,
            exposes: [lightExpose, switchExpose],
            options: nil,
            icon: nil
        )
        let device = Device(
            ieeeAddress: "0xtest", type: .router, networkAddress: 1,
            supported: true, friendlyName: "Multi", disabled: false,
            description: nil, definition: def,
            powerSource: "Mains (single phase)", modelId: nil,
            manufacturer: nil, interviewCompleted: true, interviewing: false,
            softwareBuildId: nil, dateCode: nil, endpoints: nil, options: nil
        )
        XCTAssertEqual(device.category, .light)
    }

    @MainActor
    func testAllCategoriesHaveLabels() {
        for category in Device.Category.allCases {
            XCTAssertFalse(category.label.isEmpty, "Category \(category) has no label")
        }
    }

    @MainActor
    func testAllCategoriesHaveSystemImages() {
        for category in Device.Category.allCases {
            XCTAssertFalse(category.systemImage.isEmpty, "Category \(category) has no system image")
        }
    }
}
