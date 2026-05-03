import XCTest
@testable import Shellbee

/// Smoke tests for the merged multi-bridge accessors that the device, group,
/// log, and home views rely on. Two bridges connect, populate their per-bridge
/// stores, and we assert the aggregated views see both.
final class MultiBridgeAggregationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
        UserDefaults.standard.removeObject(forKey: "savedBridges.defaultID")
        UserDefaults.standard.removeObject(forKey: "savedBridges.autoConnectIDs")
        UserDefaults.standard.removeObject(forKey: "AppStore.deviceFirstSeenByBridge")
        UserDefaults.standard.removeObject(forKey: "AppStore.deviceFirstSeen")
        MainActor.assumeIsolated { ConnectionConfig.clearPersistedSecretsForTests() }
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "connectionHistory")
        UserDefaults.standard.removeObject(forKey: "savedBridges.defaultID")
        UserDefaults.standard.removeObject(forKey: "savedBridges.autoConnectIDs")
        UserDefaults.standard.removeObject(forKey: "AppStore.deviceFirstSeenByBridge")
        UserDefaults.standard.removeObject(forKey: "AppStore.deviceFirstSeen")
        MainActor.assumeIsolated { ConnectionConfig.clearPersistedSecretsForTests() }
        super.tearDown()
    }

    // MARK: - AppEnvironment.allDevices

    @MainActor
    func testAllDevicesAggregatesAcrossSessions() {
        let env = AppEnvironment()
        let cfgA = makeConfig(name: "Main")
        let cfgB = makeConfig(name: "Lab")
        env.connect(config: cfgA)
        env.connect(config: cfgB)

        // Inject devices directly into each session's store (simulating a
        // bridge/devices snapshot landing).
        env.registry.session(for: cfgA.id)?.store.devices = [
            makeDevice(ieee: "0x1", name: "OfficeLight"),
        ]
        env.registry.session(for: cfgB.id)?.store.devices = [
            makeDevice(ieee: "0x2", name: "LabSensor"),
            makeDevice(ieee: "0x3", name: "LabPlug"),
        ]

        let merged = env.allDevices
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(Set(merged.map(\.bridgeName)), ["Main", "Lab"])
        XCTAssertEqual(Set(merged.map(\.device.friendlyName)), ["OfficeLight", "LabSensor", "LabPlug"])
    }

    @MainActor
    func testAllDevicesIDNamespacingAvoidsCollision() {
        let env = AppEnvironment()
        let cfgA = makeConfig(name: "Main")
        let cfgB = makeConfig(name: "Lab")
        env.connect(config: cfgA)
        env.connect(config: cfgB)

        // Same IEEE on both bridges — a real concern when the user has
        // identical device fleets on separate networks.
        env.registry.session(for: cfgA.id)?.store.devices = [makeDevice(ieee: "0x1", name: "Sensor")]
        env.registry.session(for: cfgB.id)?.store.devices = [makeDevice(ieee: "0x1", name: "Sensor")]

        let merged = env.allDevices
        XCTAssertEqual(merged.count, 2)
        XCTAssertEqual(Set(merged.map(\.id)).count, 2,
            "Identifiable.id must namespace by bridgeID — duplicate IEEEs across bridges are valid.")
    }

    // MARK: - AppEnvironment.allLogEntries

    @MainActor
    func testAllLogEntriesSortedNewestFirst() {
        let env = AppEnvironment()
        let cfgA = makeConfig(name: "Main")
        let cfgB = makeConfig(name: "Lab")
        env.connect(config: cfgA)
        env.connect(config: cfgB)

        let now = Date()
        env.registry.session(for: cfgA.id)?.store.logEntries = [
            makeLog(message: "A_old", at: now.addingTimeInterval(-60)),
            makeLog(message: "A_new", at: now),
        ]
        env.registry.session(for: cfgB.id)?.store.logEntries = [
            makeLog(message: "B_mid", at: now.addingTimeInterval(-30)),
        ]

        let merged = env.allLogEntries
        XCTAssertEqual(merged.count, 3)
        XCTAssertEqual(merged.map(\.entry.message), ["A_new", "B_mid", "A_old"])
    }

    // MARK: - bridge(forDevice:)

    @MainActor
    func testAllDevicesAttributesEachToItsBridge() {
        // Phase 3 multi-bridge: `environment.bridge(forDevice:)` is gone —
        // name-based lookup was ambiguous when two bridges share a name.
        // The replacement is `allDevices`: every entry already carries its
        // source bridge id, so attribution is unambiguous and routing by
        // bridge id is the only correct option.
        let env = AppEnvironment()
        let cfgA = makeConfig(name: "Main")
        let cfgB = makeConfig(name: "Lab")
        env.connect(config: cfgA)
        env.connect(config: cfgB)

        env.registry.session(for: cfgA.id)?.store.devices = [makeDevice(ieee: "0xA", name: "OnA")]
        env.registry.session(for: cfgB.id)?.store.devices = [makeDevice(ieee: "0xB", name: "OnB")]

        let bound = env.allDevices.first { $0.device.friendlyName == "OnB" }
        XCTAssertEqual(bound?.bridgeID, cfgB.id)
    }

    // MARK: - Helpers

    private func makeConfig(name: String) -> ConnectionConfig {
        ConnectionConfig(
            id: UUID(),
            host: "\(name.lowercased()).local",
            port: 8080,
            useTLS: false,
            basePath: "/",
            authToken: nil,
            name: name
        )
    }

    private func makeDevice(ieee: String, name: String) -> Device {
        Device(
            ieeeAddress: ieee,
            type: .router,
            networkAddress: 0,
            supported: true,
            friendlyName: name,
            disabled: false,
            interviewCompleted: true,
            interviewing: false
        )
    }

    @MainActor
    private func makeLog(message: String, at timestamp: Date) -> LogEntry {
        LogEntry(
            id: UUID(),
            timestamp: timestamp,
            level: .info,
            category: .general,
            namespace: nil,
            message: message,
            deviceName: nil
        )
    }
}
