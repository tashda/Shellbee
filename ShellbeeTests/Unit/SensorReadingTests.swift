import XCTest
@testable import Shellbee

@MainActor
final class SensorReadingTests: XCTestCase {
    func testContactTrueDisplaysClosed() {
        let reading = SensorReading(
            expose: contactExpose,
            property: "contact",
            value: .bool(true)
        )

        XCTAssertEqual(reading.displayValue, "Closed")
        XCTAssertEqual(reading.numericDisplayValue, "Closed")
        XCTAssertEqual(reading.icon, "door.sliding.left.hand.closed")
        XCTAssertFalse(reading.binaryActive)
    }

    func testContactFalseDisplaysOpen() {
        let reading = SensorReading(
            expose: contactExpose,
            property: "contact",
            value: .bool(false)
        )

        XCTAssertEqual(reading.displayValue, "Open")
        XCTAssertEqual(reading.numericDisplayValue, "Open")
        XCTAssertEqual(reading.icon, "door.sliding.left.hand.open")
        XCTAssertTrue(reading.binaryActive)
    }

    func testWindowOpenKeepsTrueAsOpen() {
        let reading = SensorReading(
            expose: windowOpenExpose,
            property: "window_open",
            value: .bool(true)
        )

        XCTAssertEqual(reading.displayValue, "Open")
        XCTAssertEqual(reading.icon, "window.vertical.open")
        XCTAssertTrue(reading.binaryActive)
    }

    private var contactExpose: Expose {
        Expose(
            type: "binary",
            name: "contact",
            label: "Contact",
            description: "Indicates if the contact is closed (= true) or open (= false)",
            access: 1,
            property: "contact",
            endpoint: nil,
            features: nil,
            options: nil,
            unit: nil,
            valueMin: nil,
            valueMax: nil,
            valueStep: nil,
            values: nil,
            valueOn: .bool(false),
            valueOff: .bool(true),
            presets: nil
        )
    }

    private var windowOpenExpose: Expose {
        Expose(
            type: "binary",
            name: "window_open",
            label: "Window open",
            description: "Indicates if window is open",
            access: 1,
            property: "window_open",
            endpoint: nil,
            features: nil,
            options: nil,
            unit: nil,
            valueMin: nil,
            valueMax: nil,
            valueStep: nil,
            values: nil,
            valueOn: .bool(true),
            valueOff: .bool(false),
            presets: nil
        )
    }
}
