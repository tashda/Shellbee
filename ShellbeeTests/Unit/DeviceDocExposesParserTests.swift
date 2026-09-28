import XCTest
@testable import Shellbee

/// The Exposes section of z2m's generated device pages, parsed into the
/// capabilities a Device Library entry shows. Samples are copied from the
/// bundled docs (ADEO ZBEK-32, a Tuya switch, a Datek cover and an Aqara
/// occupancy sensor).
@MainActor
final class DeviceDocExposesParserTests: XCTestCase {
    func testTypedExposesReadLabelPropertyAccessAndValues() throws {
        let exposes = parse(Self.light)

        let effect = try XCTUnwrap(exposes.first { $0.property == "effect" })
        XCTAssertEqual(effect.label, "Effect")
        XCTAssertEqual(effect.type, "enum")
        XCTAssertEqual(effect.values, ["blink", "breathe", "okay", "channel_change", "finish_effect", "stop_effect"])
        XCTAssertFalse(effect.isReadable, "Effect is not published in the state")
        XCTAssertTrue(effect.isWritable)
        XCTAssertEqual(effect.description, "Triggers an effect on the light (e.g. make light blink for a few seconds).")

        let power = try XCTUnwrap(exposes.first { $0.property == "power_on_behavior" })
        XCTAssertEqual(power.label, "Power-on behavior")
        XCTAssertTrue(power.isReadable)
        XCTAssertEqual(power.values, ["off", "on", "toggle", "previous"])
    }

    func testCompositeLightListsItsFeatures() throws {
        let exposes = parse(Self.light)

        let state = try XCTUnwrap(exposes.first { $0.property == "state" })
        XCTAssertEqual(state.label, "State")
        XCTAssertEqual(state.type, "binary")
        XCTAssertTrue(state.isWritable)

        let brightness = try XCTUnwrap(exposes.first { $0.property == "brightness" })
        XCTAssertEqual(brightness.type, "numeric")
        XCTAssertEqual(brightness.valueMin, 0)
        XCTAssertEqual(brightness.valueMax, 254)
    }

    func testNumericReadsRangeUnitAndEndpoint() throws {
        let countdown = try XCTUnwrap(parse(Self.switchDevice).first { $0.property == "countdown_l1" })
        XCTAssertEqual(countdown.label, "Countdown")
        XCTAssertEqual(countdown.endpoint, "l1")
        XCTAssertEqual(countdown.valueMin, 0)
        XCTAssertEqual(countdown.valueMax, 43200)
        XCTAssertEqual(countdown.unit, "s")
    }

    func testSwitchAndCoverProseBecomeStateAndPosition() throws {
        let switchState = try XCTUnwrap(parse(Self.switchDevice).first { $0.property == "state" })
        XCTAssertEqual(switchState.values, ["ON", "OFF"])
        XCTAssertTrue(switchState.isWritable)

        let cover = parse(Self.cover)
        XCTAssertEqual(cover.first { $0.property == "state" }?.values, ["OPEN", "CLOSE"])
        let position = try XCTUnwrap(cover.first { $0.property == "position" })
        XCTAssertEqual(position.valueMax, 100)
    }

    func testBinaryReadsItsValuesAndReadOnlyAccess() throws {
        let occupancy = try XCTUnwrap(parse(Self.sensor).first { $0.property == "occupancy" })
        XCTAssertEqual(occupancy.type, "binary")
        XCTAssertEqual(occupancy.values, ["true", "false"])
        XCTAssertTrue(occupancy.isReadable)
        XCTAssertFalse(occupancy.isWritable)
    }

    func testLibraryEntryGetsCapabilitiesInsteadOfTheMarkdownSection() {
        let normalized = DeviceDocNormalizer.normalize(
            parsed: DocParser.parse("## Exposes\n" + Self.light),
            device: DeviceFixture.coordinator()
        )

        XCTAssertEqual(
            Set(normalized.capabilities.compactMap(\.property)),
            ["state", "brightness", "effect", "power_on_behavior"]
        )
        XCTAssertFalse(
            normalized.additionalSections.contains { $0.title == "Exposes" },
            "Parsed exposes shouldn't also appear as a reading page"
        )
    }

    func testUnreadableExposesKeepTheMarkdownSection() {
        let normalized = DeviceDocNormalizer.normalize(
            parsed: DocParser.parse("## Exposes\nThis device exposes nothing we can read.\n"),
            device: DeviceFixture.coordinator()
        )

        XCTAssertTrue(normalized.capabilities.isEmpty)
        XCTAssertTrue(normalized.additionalSections.contains { $0.title == "Exposes" })
    }

    // MARK: - Helpers

    private func parse(_ markdown: String) -> [Expose] {
        let section = DocParser.parse("## Exposes\n" + markdown).sections.first { $0.title == "Exposes" }
        return section.map(DeviceDocExposesParser.exposes(from:)) ?? []
    }

    private static let light = """
    ### Light
    This light supports the following features: `state`, `brightness`.
    - `state`: To control the state publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"state": "ON"}`, `{"state": "OFF"}` or `{"state": "TOGGLE"}`. To read the state send a message to `zigbee2mqtt/FRIENDLY_NAME/get` with payload `{"state": ""}`.
    - `brightness`: To control the brightness publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"brightness": VALUE}` where `VALUE` is a number between `0` and `254`. To read the brightness send a message to `zigbee2mqtt/FRIENDLY_NAME/get` with payload `{"brightness": ""}`.
    #### Transition
    For all of the above mentioned features it is possible to do a transition of the value over time.
    ### Effect (enum)
    Triggers an effect on the light (e.g. make light blink for a few seconds).
    Value will **not** be published in the state.
    It's not possible to read (`/get`) this value.
    To write (`/set`) a value publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"effect": NEW_VALUE}`.
    The possible values are: `blink`, `breathe`, `okay`, `channel_change`, `finish_effect`, `stop_effect`.
    ### Power-on behavior (enum)
    Controls the behavior when the device is powered on after power loss.
    Value can be found in the published state on the `power_on_behavior` property.
    To read (`/get`) the value publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/get` with payload `{"power_on_behavior": ""}`.
    To write (`/set`) a value publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"power_on_behavior": NEW_VALUE}`.
    The possible values are: `off`, `on`, `toggle`, `previous`.
    """

    private static let switchDevice = """
    ### Switch
    The current state of this switch is in the published state under the `state` property (value is `ON` or `OFF`).
    To control this switch publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"state": "ON"}`, `{"state": "OFF"}` or `{"state": "TOGGLE"}`.
    To read the current state of this switch publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/get` with payload `{"state": ""}`.
    ### Countdown (numeric, l1 endpoint)
    Toggle the device after a set duration (one time action).
    Value can be found in the published state on the `countdown_l1` property.
    To read (`/get`) the value publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/get` with payload `{"countdown_l1": ""}`.
    To write (`/set`) a value publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"countdown_l1": NEW_VALUE}`.
    The minimal value is `0` and the maximum value is `43200`.
    The unit of this value is `s`.
    """

    private static let cover = """
    ### Cover
    The current state of this cover is in the published state under the `state` property (value is `OPEN` or `CLOSE`).
    To control this cover publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"state": "OPEN"}`, `{"state": "CLOSE"}`, `{"state": "STOP"}`.
    It's not possible to read (`/get`) this value.
    To change the position publish a message to topic `zigbee2mqtt/FRIENDLY_NAME/set` with payload `{"position": VALUE}` where `VALUE` is a number between `0` and `100`.
    """

    private static let sensor = """
    ### Occupancy (binary)
    Indicates whether the device detected occupancy.
    Value can be found in the published state on the `occupancy` property.
    It's not possible to read (`/get`) or write (`/set`) this value.
    If value equals `true` occupancy is ON, if `false` OFF.
    """
}
