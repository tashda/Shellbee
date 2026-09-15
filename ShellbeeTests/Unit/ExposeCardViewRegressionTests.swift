import XCTest
@testable import Shellbee

/// Regression coverage for issue #135: a sensor-category device with both
/// readable sensor values (presence, illuminance, temperature, humidity) and
/// writable `definition.exposes` config properties (fading_time, indicator,
/// illuminance_interval, motion_detection_sensitivity) must surface both —
/// not just the read-only readings. Fixture is the real Z2M definition for
/// the HOBEIAN ZG-204ZV reported in the issue, captured from the mock bridge
/// (`docker/seeder`, "Attic Presence Sensor").
final class ExposeCardViewRegressionTests: XCTestCase {

    @MainActor
    func testZG204ZVIsSensorCategory() throws {
        XCTAssertEqual(try Self.loadDevice().category, .sensor)
    }

    @MainActor
    func testZG204ZVHasSensorReadings() throws {
        let device = try Self.loadDevice()
        XCTAssertTrue(SensorCard.hasReadings(device: device, state: Self.state))
    }

    @MainActor
    func testZG204ZVHasWritableConfigExposes() throws {
        let device = try Self.loadDevice()
        XCTAssertTrue(GenericExposeCard.hasWritableRows(device: device, state: Self.state))
    }

    @MainActor
    func testZG204ZVWritableRowsIncludeEveryMissingSetting() throws {
        let device = try Self.loadDevice()
        let rows = GenericExposeCard.rows(for: device, state: Self.state, writableOnly: true)
        let properties = Set(rows.map(\.property))

        // These are exactly the settings issue #135 reported as missing —
        // present in definition.exposes (not definition.options), writable,
        // and with no "config" category tag to key off of.
        for expected in [
            "fading_time", "indicator", "illuminance_interval",
            "motion_detection_sensitivity", "temperature_unit",
        ] {
            XCTAssertTrue(properties.contains(expected), "Missing writable row for \(expected)")
        }

        // Read-only readings (already shown by SensorCard) must not be duplicated.
        for readingOnly in ["presence", "illuminance", "temperature", "humidity"] {
            XCTAssertFalse(properties.contains(readingOnly), "\(readingOnly) should not appear in writable-only rows")
        }
    }

    // MARK: - Fixture

    private static let state: [String: JSONValue] = [
        "presence": .bool(false),
        "illuminance": .int(0),
        "temperature": .double(-0.3),
        "humidity": .double(0.9),
        "temperature_unit": .string("celsius"),
        "temperature_calibration": .int(-2),
        "humidity_calibration": .int(-30),
        "battery": .int(76),
        "fading_time": .int(0),
        "indicator": .string("OFF"),
        "illuminance_interval": .int(1),
        "motion_detection_sensitivity": .int(0),
        "linkquality": .int(208),
    ]

    @MainActor
    private static func loadDevice() throws -> Device {
        try JSONDecoder().decode(Device.self, from: Data(deviceJSON.utf8))
    }

    // Captured verbatim from `zigbee2mqtt/bridge/devices` on the mock bridge
    // (docker/seeder, model ZG-204ZV / "Attic Presence Sensor", issue #135).
    private static let deviceJSON = """
    {
      "ieee_address": "0x00158d00055ee005",
      "type": "EndDevice",
      "network_address": 10016,
      "supported": true,
      "friendly_name": "Attic Presence Sensor",
      "disabled": false,
      "description": null,
      "definition": {
        "model": "ZG-204ZV",
        "vendor": "HOBEIAN",
        "description": "Millimeter wave motion detection",
        "exposes": [
          {"name": "presence", "label": "Presence", "access": 1, "type": "binary", "property": "presence", "description": "Indicates whether the device detected presence", "value_on": true, "value_off": false},
          {"name": "illuminance", "label": "Illuminance", "access": 1, "type": "numeric", "property": "illuminance", "description": "Measured illuminance", "unit": "lx"},
          {"name": "temperature", "label": "Temperature", "access": 1, "type": "numeric", "property": "temperature", "description": "Measured temperature value", "unit": "\\u00b0C"},
          {"name": "humidity", "label": "Humidity", "access": 1, "type": "numeric", "property": "humidity", "description": "Measured relative humidity", "unit": "%"},
          {"name": "temperature_unit", "label": "Temperature unit", "access": 3, "type": "enum", "property": "temperature_unit", "description": "Temperature unit", "values": ["celsius", "fahrenheit"]},
          {"name": "temperature_calibration", "label": "Temperature calibration", "access": 3, "type": "numeric", "property": "temperature_calibration", "description": "Temperature calibration", "unit": "\\u00b0C", "value_max": 2, "value_min": -2, "value_step": 0.1},
          {"name": "humidity_calibration", "label": "Humidity calibration", "access": 3, "type": "numeric", "property": "humidity_calibration", "description": "Humidity calibration", "unit": "%", "value_max": 30, "value_min": -30, "value_step": 1},
          {"name": "battery", "label": "Battery", "access": 1, "type": "numeric", "property": "battery", "description": "Remaining battery in %, can take up to 24 hours before reported", "category": "diagnostic", "unit": "%", "value_max": 100, "value_min": 0},
          {"name": "fading_time", "label": "Fading time", "access": 3, "type": "numeric", "property": "fading_time", "description": "Motion keep time", "unit": "s", "value_max": 28800, "value_min": 0, "value_step": 1},
          {"name": "indicator", "label": "Indicator", "access": 3, "type": "binary", "property": "indicator", "description": "LED indicator mode", "value_on": "ON", "value_off": "OFF"},
          {"name": "illuminance_interval", "label": "Illuminance interval", "access": 3, "type": "numeric", "property": "illuminance_interval", "description": "Light sensing sampling(refresh and update only while active)", "unit": "minutes", "value_max": 720, "value_min": 1, "value_step": 1},
          {"name": "motion_detection_sensitivity", "label": "Motion detection sensitivity", "access": 3, "type": "numeric", "property": "motion_detection_sensitivity", "description": "The larger the value, the more sensitive it is (refresh and update only while active)", "value_max": 19, "value_min": 0, "value_step": 1}
        ],
        "options": [
          {"name": "illuminance_calibration", "label": "Illuminance calibration", "access": 2, "type": "numeric", "property": "illuminance_calibration", "description": "Calibrates the illuminance value (percentual offset), takes into effect on next report of device.", "value_step": 0.1},
          {"name": "temperature_calibration", "label": "Temperature calibration", "access": 2, "type": "numeric", "property": "temperature_calibration", "description": "Calibrates the temperature value (absolute offset), takes into effect on next report of device.", "value_step": 0.1},
          {"name": "humidity_calibration", "label": "Humidity calibration", "access": 2, "type": "numeric", "property": "humidity_calibration", "description": "Calibrates the humidity value (absolute offset), takes into effect on next report of device.", "value_step": 0.1}
        ]
      },
      "power_source": "Battery",
      "model_id": "ZG-204ZV",
      "manufacturer": "HOBEIAN",
      "interview_completed": true,
      "interviewing": false,
      "interview_state": "SUCCESSFUL",
      "software_build_id": null,
      "date_code": null,
      "options": {}
    }
    """
}
