import XCTest
@testable import Shellbee

@MainActor
final class ActivityChangeWordingTests: XCTestCase {
    func testColourShowsNameNotCoordinates() {
        let wording = ActivityChangeWording(
            change: change("color.x", from: .double(0.36), to: .double(0.63)),
            state: ["color": .object(["x": .double(0.64), "y": .double(0.33)]), "color_mode": .string("xy")]
        )
        XCTAssertNil(wording.compact, "Minimized shows no value for colour")
        XCTAssertEqual(wording.to, "Red")
        XCTAssertEqual(wording.sentence, "Colour set to Red")
    }

    func testColourTemperatureReadsInKelvin() {
        let wording = ActivityChangeWording(change: change("color_temp", from: .int(250), to: .int(370)))
        XCTAssertEqual(wording.to, "2703 K")
        XCTAssertNil(wording.compact)
    }

    func testStatesUsePlainWordsAndNoCompactValue() {
        let on = ActivityChangeWording(change: change("state", from: .string("OFF"), to: .string("ON")))
        XCTAssertEqual(on.to, "On")
        XCTAssertEqual(on.sentence, "Turned on")
        XCTAssertNil(on.compact)

        let open = ActivityChangeWording(change: change("contact", from: .bool(true), to: .bool(false)))
        XCTAssertEqual(open.to, "Open")
        XCTAssertEqual(open.sentence, "Opened")

        let leak = ActivityChangeWording(change: change("water_leak", from: .bool(false), to: .bool(true)))
        XCTAssertEqual(leak.to, "Detected")
    }

    func testActionsAreHumanized() {
        let wording = ActivityChangeWording(change: change("action", from: nil, to: .string("brightness_move_up")))
        XCTAssertEqual(wording.to, "Brightness Move Up")
        XCTAssertEqual(wording.sentence, "Pressed Brightness Move Up")
        XCTAssertNil(wording.compact)
    }

    func testMeasurementsKeepAShortValueWithUnit() {
        let changes = LogMapperEngine.diff(["humidity": .double(48)], ["humidity": .double(53)], units: ["humidity": "%"])
        let wording = ActivityChangeWording(change: changes[0])
        XCTAssertEqual(wording.compact, "53%")
        XCTAssertEqual(wording.from, "48%")

        let power = LogMapperEngine.diff(["power": .int(4)], ["power": .int(812)])
        XCTAssertEqual(ActivityChangeWording(change: power[0]).compact, "812 W")
    }

    func testTextDropsFromMinimizedButKeepsFromToExpanded() {
        let wording = ActivityChangeWording(change: change("system_mode", from: .string("heat"), to: .string("auto")))
        XCTAssertNil(wording.compact)
        XCTAssertEqual(wording.from, "heat")
        XCTAssertEqual(wording.to, "auto")
    }

    func testIdenticalDisplayedValuesDropTheArrow() {
        let wording = ActivityChangeWording(change: LogContext.StateChange(
            id: UUID(), property: "voltage", from: .double(3.001), to: .double(3.002),
            displayLabel: "Voltage", displayFrom: "3 V", displayTo: "3 V"
        ))
        XCTAssertNil(wording.from)
        XCTAssertEqual(wording.sentence, "Voltage: 3 V")
    }

    func testSplitColourReportReadsAsOneChange() {
        let state: [String: JSONValue] = ["color": .object(["x": .double(0.64), "y": .double(0.33)]), "color_mode": .string("xy")]
        let entry = LogEntry(
            id: UUID(), timestamp: .now, level: .info, category: .stateChange, namespace: nil,
            message: "", deviceName: "Lamp",
            context: LogContext(
                devices: [],
                stateChanges: [change("color.x", from: .double(0.3), to: .double(0.64)), change("color.y", from: .double(0.3), to: .double(0.33))],
                action: .stateChange,
                payload: state
            )
        )
        XCTAssertEqual(entry.activityChangeWordings.map(\.sentence), ["Colour set to Red"])
    }

    private func change(_ property: String, from: JSONValue?, to: JSONValue) -> LogContext.StateChange {
        LogContext.StateChange(
            id: UUID(), property: property, from: from, to: to,
            displayLabel: LogMapperEngine.humanize(property),
            displayFrom: from.map { LogMapperEngine.format($0, property: property) },
            displayTo: LogMapperEngine.format(to, property: property)
        )
    }
}
