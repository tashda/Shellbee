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
    func testGenericExposeRowsSkipDeviceCardFields() {
        let device = genericDevice(exposes: [
            Expose(
                type: "numeric", name: "linkquality", label: "Linkquality", description: nil,
                access: 1, property: "linkquality", endpoint: nil, features: nil, options: nil,
                unit: nil, valueMin: nil, valueMax: nil, valueStep: nil, values: nil,
                valueOn: nil, valueOff: nil, presets: nil
            ),
            Expose(
                type: "enum", name: "identify", label: "Identify", description: nil,
                access: 2, property: "identify", endpoint: nil, features: nil, options: nil,
                unit: nil, valueMin: nil, valueMax: nil, valueStep: nil, values: ["identify"],
                valueOn: nil, valueOff: nil, presets: nil
            ),
            Expose(
                type: "numeric", name: "transition", label: "Transition", description: nil,
                access: 7, property: "transition", endpoint: nil, features: nil, options: nil,
                unit: nil, valueMin: 0, valueMax: 10, valueStep: nil, values: nil,
                valueOn: nil, valueOff: nil, presets: nil
            )
        ])

        let rows = GenericExposeCard.rows(for: device, state: [
            "linkquality": .int(120),
            "transition": .int(1)
        ])

        XCTAssertEqual(rows.map(\.property), ["transition"])
    }

    @MainActor
    func testGenericExposeRowsEmptyForInfrastructureOnlyDevice() {
        let device = genericDevice(exposes: [
            Expose(
                type: "numeric", name: "linkquality", label: "Linkquality", description: nil,
                access: 1, property: "linkquality", endpoint: nil, features: nil, options: nil,
                unit: nil, valueMin: nil, valueMax: nil, valueStep: nil, values: nil,
                valueOn: nil, valueOff: nil, presets: nil
            ),
            Expose(
                type: "enum", name: "identify", label: "Identify", description: nil,
                access: 2, property: "identify", endpoint: nil, features: nil, options: nil,
                unit: nil, valueMin: nil, valueMax: nil, valueStep: nil, values: ["identify"],
                valueOn: nil, valueOff: nil, presets: nil
            )
        ])

        let rows = GenericExposeCard.rows(for: device, state: ["linkquality": .int(120)])

        XCTAssertTrue(rows.isEmpty)
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

    private func genericDevice(exposes: [Expose]) -> Device {
        let def = DeviceDefinition(
            model: "EXT",
            vendor: "IKEA",
            description: "Signal repeater",
            supportsOTA: false,
            exposes: exposes,
            options: nil,
            icon: nil
        )
        return Device(
            ieeeAddress: "0xextender",
            type: .router,
            networkAddress: 1,
            supported: true,
            friendlyName: "Extender",
            disabled: false,
            description: nil,
            definition: def,
            powerSource: "Mains (single phase)",
            modelId: "EXT",
            manufacturer: "IKEA",
            interviewCompleted: true,
            interviewing: false,
            softwareBuildId: nil,
            dateCode: nil,
            endpoints: nil,
            options: nil
        )
    }
}
