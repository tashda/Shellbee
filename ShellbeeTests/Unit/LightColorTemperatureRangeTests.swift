import XCTest
@testable import Shellbee

final class LightColorTemperatureRangeTests: XCTestCase {
    @MainActor
    func testUsesTheRangeTheDeviceReports() {
        let ikea = LightControlContext(device: DeviceFixture.light(), state: StateFixture.lightOn())!
        XCTAssertEqual(ikea.colorTemperatureRange, 250...454)
    }

    @MainActor
    func testPlaceholderRangeFallsBackToZ2MDefault() {
        // GL-SPI-206P reports 0–1000 mireds: 1000 K to infinity.
        XCTAssertEqual(LightControlContext.plausibleColorTemperatureRange(0...1000), 150...500)
        XCTAssertEqual(LightControlContext.plausibleColorTemperatureRange(nil), 150...500)
        XCTAssertEqual(LightControlContext.plausibleColorTemperatureRange(158...495), 158...495)
    }

    @MainActor
    func testPayloadNeverAsksForMoreThanTheDeviceHas() {
        let ikea = LightControlContext(device: DeviceFixture.light(), state: StateFixture.lightOn())!
        XCTAssertEqual(ikea.colorTemperaturePayload(153), .object(["color_temp": .int(250)]))
        XCTAssertEqual(ikea.colorTemperaturePayload(500), .object(["color_temp": .int(454)]))
    }

    @MainActor
    func testGroupIsLimitedToWhatEveryMemberCanReach() {
        let state = StateFixture.lightOn()
        let hue = LightControlContext(device: CardGalleryCatalog.light.device, state: state)!
        let ikea = LightControlContext(device: DeviceFixture.light(), state: state)!
        XCTAssertEqual(hue.colorTemperatureRange, 153...500)

        let group = hue.limitingColorTemperature(toMembers: [hue, ikea])
        XCTAssertEqual(group.colorTemperatureRange, 250...454)
    }
}
