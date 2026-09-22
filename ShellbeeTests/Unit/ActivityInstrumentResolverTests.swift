import XCTest
@testable import Shellbee

@MainActor
final class ActivityInstrumentResolverTests: XCTestCase {
    func testStatePropertiesResolveToSemanticInstruments() {
        let expectations: [(String, JSONValue, ActivityInstrumentKind)] = [
            ("brightness", .int(80), .level),
            ("state", .string("ON"), .binary),
            ("pressure", .double(1_008), .trend),
            ("temperature", .double(21.4), .temperature),
            ("humidity", .int(53), .humidity),
            ("co2", .int(920), .airQuality),
            ("power", .int(812), .energy),
            ("position", .int(67), .position),
            ("color", .string("#6874ff"), .colour),
            ("linkquality", .int(120), .signal),
            ("battery", .int(18), .battery),
            ("occupancy", .bool(true), .presence),
            ("water_leak", .bool(true), .safety),
            ("action", .string("rotate_right"), .action),
            ("manufacturer_value", .string("alpha"), .unknown)
        ]

        for (property, value, expectedKind) in expectations {
            let instrument = ActivityInstrumentResolver.instrument(forProperty: property, to: value)
            XCTAssertEqual(instrument.kind, expectedKind, "Unexpected instrument for \(property)")
        }
    }

    func testBridgeRequestsResolveToSemanticInstruments() {
        let expectations: [String: ActivityInstrumentKind] = [
            "action": .action,
            "backup": .backup,
            "device/bind": .pairing,
            "device/configure": .options,
            "device/configure_reporting": .options,
            "device/interview": .pairing,
            "device/options": .options,
            "device/ota_update/check": .update,
            "device/ota_update/schedule": .update,
            "device/ota_update/unschedule": .update,
            "device/ota_update/update": .update,
            "device/remove": .lifecycle,
            "device/rename": .lifecycle,
            "device/unbind": .pairing,
            "devices": .network,
            "group/add": .group,
            "group/members/add": .group,
            "group/members/remove": .group,
            "group/options": .options,
            "group/remove": .group,
            "group/rename": .group,
            "groups": .group,
            "health_check": .health,
            "info": .message,
            "install_code/add": .pairing,
            "networkmap": .network,
            "options": .options,
            "permit_join": .pairing,
            "restart": .restart,
            "touchlink/factory_reset": .touchlink,
            "touchlink/identify": .touchlink,
            "touchlink/scan": .touchlink
        ]

        for (topic, expectedKind) in expectations {
            let instrument = ActivityInstrumentResolver.instrument(for: bridgeEntry(topic: topic))
            XCTAssertEqual(instrument.kind, expectedKind, "Unexpected instrument for \(topic)")
        }
    }

    func testEventCategoriesResolveToSemanticInstruments() {
        let expectations: [(LogCategory, String, ActivityInstrumentKind)] = [
            (.deviceJoined, "Device joined", .lifecycle),
            (.deviceAnnounce, "Device announced", .signal),
            (.interview, "Interview successful", .pairing),
            (.deviceLeave, "Device left", .lifecycle),
            (.availability, "Device online", .lifecycle),
            (.bridgeState, "Bridge offline", .lifecycle),
            (.permitJoin, "Pairing opened", .pairing),
            (.general, "Informational message", .message)
        ]

        for (category, message, expectedKind) in expectations {
            let entry = LogEntry(
                id: UUID(), timestamp: .now, level: .info, category: category,
                namespace: nil, message: message, deviceName: nil
            )
            XCTAssertEqual(
                ActivityInstrumentResolver.instrument(for: entry).kind,
                expectedKind,
                "Unexpected instrument for \(category)"
            )
        }
    }

    func testValuesDriveTrendFillAndSeverity() {
        let battery = ActivityInstrumentResolver.instrument(
            forProperty: "battery", from: .int(24), to: .int(18)
        )
        XCTAssertEqual(battery.normalizedValue, 0.18, accuracy: 0.001)
        XCTAssertEqual(battery.trend, .falling)
        XCTAssertEqual(battery.severity, .warning)

        let safety = ActivityInstrumentResolver.instrument(
            forProperty: "smoke", from: .bool(false), to: .bool(true)
        )
        XCTAssertEqual(safety.normalizedValue, 1)
        XCTAssertEqual(safety.trend, .rising)
        XCTAssertEqual(safety.severity, .failure)

        let signal = ActivityInstrumentResolver.instrument(
            forProperty: "linkquality", from: .int(124), to: .int(120)
        )
        XCTAssertEqual(signal.normalizedValue, 120.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(signal.severity, .quiet)
    }

    func testSwitchFlipHeadlinesOverBrightness() {
        let entry = stateEntry([
            change("brightness", from: .int(0), to: .int(204)),
            change("state", from: .string("OFF"), to: .string("ON"))
        ])
        let instrument = ActivityInstrumentResolver.instrument(for: entry)
        XCTAssertEqual(instrument.kind, .binary)
        XCTAssertTrue(instrument.isOn)
    }

    func testManyChangesUseTheMostImportantPropertyNotGroup() {
        let entry = stateEntry([
            change("temperature", from: .double(20), to: .double(21)),
            change("pressure", from: .int(1008), to: .int(1007)),
            change("voltage", from: .int(3000), to: .int(2990))
        ])
        XCTAssertEqual(ActivityInstrumentResolver.instrument(for: entry).kind, .temperature)
    }

    func testContactIsLitWhenOpen() {
        let open = ActivityInstrumentResolver.instrument(forProperty: "contact", from: .bool(true), to: .bool(false))
        XCTAssertEqual(open.variant, .contact)
        XCTAssertTrue(open.isOn)
        let closed = ActivityInstrumentResolver.instrument(forProperty: "contact", to: .bool(true))
        XCTAssertFalse(closed.isOn)
    }

    func testLockValuesResolveToPadlockState() {
        let locked = ActivityInstrumentResolver.instrument(forProperty: "lock", to: .string("LOCK"))
        XCTAssertEqual(locked.variant, .lock)
        XCTAssertTrue(locked.isOn)
        XCTAssertFalse(ActivityInstrumentResolver.instrument(forProperty: "lock", to: .string("UNLOCK")).isOn)
    }

    func testColourChangesCarryTheLightColour() {
        XCTAssertNotNil(ActivityInstrumentResolver.instrument(forProperty: "color", to: .string("#6874ff")).swatch)
        XCTAssertNotNil(ActivityInstrumentResolver.instrument(forProperty: "color_temp", to: .int(370)).swatch)
    }

    func testSplitColourChangesUseTheStateSnapshot() {
        let entry = LogEntry(
            id: UUID(), timestamp: .now, level: .info, category: .stateChange,
            namespace: nil, message: "State change", deviceName: "Lamp",
            context: LogContext(
                devices: [],
                stateChanges: [change("color.x", from: .double(0.36), to: .double(0.63))],
                action: .stateChange,
                payload: ["color": .object(["x": .double(0.63), "y": .double(0.28)]), "color_mode": .string("xy")]
            )
        )
        let instrument = ActivityInstrumentResolver.instrument(for: entry)
        XCTAssertEqual(instrument.kind, .colour)
        XCTAssertNotNil(instrument.swatch)
    }

    func testPermitJoinClosedIsUnlit() {
        let entry = LogEntry(
            id: UUID(), timestamp: .now, level: .info, category: .bridgeActivity, namespace: "z2m:mqtt",
            message: "MQTT publish: topic 'zigbee2mqtt/bridge/response/permit_join', payload '{\"status\":\"ok\",\"data\":{\"time\":0}}'",
            deviceName: nil
        )
        let instrument = ActivityInstrumentResolver.instrument(for: entry)
        XCTAssertEqual(instrument.variant, .permitJoin)
        XCTAssertFalse(instrument.isOn)
    }

    func testUnknownBridgeResponseUsesFallbackInstrument() {
        let instrument = ActivityInstrumentResolver.instrument(
            for: bridgeEntry(topic: "future_operation")
        )
        XCTAssertEqual(instrument.kind, .unknown)
    }

    private func stateEntry(_ changes: [LogContext.StateChange]) -> LogEntry {
        LogEntry(
            id: UUID(), timestamp: .now, level: .info, category: .stateChange,
            namespace: nil, message: "State change", deviceName: "Lamp",
            context: LogContext(devices: [], stateChanges: changes, action: .stateChange)
        )
    }

    private func change(_ property: String, from: JSONValue, to: JSONValue) -> LogContext.StateChange {
        LogContext.StateChange(
            id: UUID(), property: property, from: from, to: to,
            displayLabel: property, displayFrom: from.stringified, displayTo: to.stringified
        )
    }

    private func bridgeEntry(topic: String) -> LogEntry {
        let payload = topic == "health_check"
            ? #"{"status":"ok","data":{"healthy":true}}"#
            : #"{"status":"ok","data":{"progress":42}}"#
        return LogEntry(
            id: UUID(), timestamp: .now, level: .info, category: .bridgeActivity,
            namespace: "z2m:mqtt",
            message: "MQTT publish: topic 'zigbee2mqtt/bridge/response/\(topic)', payload '\(payload)'",
            deviceName: nil
        )
    }
}
