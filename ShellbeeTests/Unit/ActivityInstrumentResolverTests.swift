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
            forProperty: "battery", from: .int(24), to: .int(18), displayTo: "18"
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

    func testUnknownBridgeResponseUsesFallbackInstrument() {
        let instrument = ActivityInstrumentResolver.instrument(
            for: bridgeEntry(topic: "future_operation")
        )
        XCTAssertEqual(instrument.kind, .unknown)
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
