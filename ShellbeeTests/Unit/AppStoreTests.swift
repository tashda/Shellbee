import XCTest
@testable import Shellbee

final class AppStoreTests: XCTestCase, @unchecked Sendable {

    var store: AppStore!

    override func setUp() {
        super.setUp()
        store = MainActor.assumeIsolated { AppStore() }
    }

    override func tearDown() {
        MainActor.assumeIsolated { store = nil }
        super.tearDown()
    }

    // MARK: - bridgeInfo

    @MainActor
    func testApplyBridgeInfoSetsVersion() throws {
        let info = try decodeBridgeInfo()
        store.apply(.bridgeInfo(info))
        XCTAssertEqual(store.bridgeInfo?.version, "2.1.0")
    }

    // MARK: - bridgeState

    @MainActor
    func testBridgeStateOnlineSetsFlag() {
        store.apply(.bridgeState("online"))
        XCTAssertTrue(store.bridgeOnline)
    }

    @MainActor
    func testBridgeStateOfflineClearsFlag() {
        store.apply(.bridgeState("online"))
        store.apply(.bridgeState("offline"))
        XCTAssertFalse(store.bridgeOnline)
    }

    // MARK: - devices

    @MainActor
    func testApplyDevicesReplacesExisting() {
        store.apply(.devices([DeviceFixture.light(), DeviceFixture.sensor()]))
        store.apply(.devices([DeviceFixture.climate()]))
        XCTAssertEqual(store.devices.count, 1)
        XCTAssertEqual(store.devices[0].category, .climate)
    }

    @MainActor
    func testApplyDevicesPopulatesStore() {
        let all = DeviceFixture.allCategoryDevices
        store.apply(.devices(all))
        XCTAssertEqual(store.devices.count, all.count)
    }

    // MARK: - groups

    @MainActor
    func testApplyGroupsReplacesExisting() {
        let group = makeGroup(id: 1, name: "Lights")
        store.apply(.groups([group]))
        XCTAssertEqual(store.groups.count, 1)
        XCTAssertEqual(store.groups[0].friendlyName, "Lights")
    }

    // MARK: - deviceState

    @MainActor
    func testApplyDeviceStateMergesIntoStore() {
        let name = "Living Room Light"
        store.apply(.deviceState(friendlyName: name, state: StateFixture.lightOn()))
        XCTAssertEqual(store.deviceStates[name]?["state"]?.stringValue, "ON")
    }

    @MainActor
    func testApplyDeviceStateUpdatesExisting() {
        let name = "Living Room Light"
        store.apply(.deviceState(friendlyName: name, state: StateFixture.lightOn(brightness: 100)))
        store.apply(.deviceState(friendlyName: name, state: StateFixture.lightOn(brightness: 200)))
        XCTAssertEqual(store.deviceStates[name]?["brightness"]?.intValue, 200)
    }

    @MainActor
    func testStateHelperReturnsCorrectState() {
        let name = "Office Sensor"
        store.apply(.deviceState(friendlyName: name, state: StateFixture.sensor()))
        let state = store.state(for: name)
        XCTAssertEqual(state["temperature"]?.numberValue, 21.5)
    }

    @MainActor
    func testStateHelperReturnsEmptyForUnknownDevice() {
        XCTAssertTrue(store.state(for: "nonexistent").isEmpty)
    }

    // MARK: - deviceAvailability

    @MainActor
    func testApplyAvailabilityOnline() {
        store.apply(.deviceAvailability(friendlyName: "Plug", available: true))
        XCTAssertTrue(store.isAvailable("Plug"))
    }

    @MainActor
    func testApplyAvailabilityOffline() {
        store.apply(.deviceAvailability(friendlyName: "Plug", available: true))
        store.apply(.deviceAvailability(friendlyName: "Plug", available: false))
        XCTAssertFalse(store.isAvailable("Plug"))
    }

    @MainActor
    func testIsAvailableDefaultsFalseForUnknown() {
        XCTAssertFalse(store.isAvailable("unknown"))
    }

    // MARK: - logs

    @MainActor
    func testLogMessageInsertsAtFront() {
        store.apply(.logMessage(makeLogMessage(msg: "first")))
        store.apply(.logMessage(makeLogMessage(msg: "second")))
        XCTAssertEqual(store.logEntries.first?.message, "second")
    }

    @MainActor
    func testLogEntriesCappedAt1000() {
        store.apply(.devices([DeviceFixture.light()]))
        for i in 0..<1001 {
            store.apply(.logMessage(makeLogMessage(msg: "msg\(i)")))
        }
        XCTAssertEqual(store.logEntries.count, AppStore.logLimit)
    }

    @MainActor
    func testLogEntriesDropOldestWhenCapped() {
        for i in 0..<1001 {
            store.apply(.logMessage(makeLogMessage(msg: "msg\(i)")))
        }
        XCTAssertFalse(store.logEntries.contains { $0.message == "msg0" })
    }

    // MARK: - bridgeEvent → log

    @MainActor
    func testDeviceJoinedCreatesLogEntry() {
        store.apply(.bridgeEvent(BridgeDeviceEvent(type: "device_joined",
            data: .object(["friendly_name": .string("NewDev"), "ieee_address": .string("0x1")]))))
        XCTAssertTrue(store.logEntries.contains { $0.category == .deviceJoined })
    }

    @MainActor
    func testDeviceLeaveCreatesLogEntry() {
        store.apply(.bridgeEvent(BridgeDeviceEvent(type: "device_leave",
            data: .object(["friendly_name": .string("OldDev"), "ieee_address": .string("0x2")]))))
        XCTAssertTrue(store.logEntries.contains { $0.category == .deviceLeave })
    }

    // MARK: - OTA startOTAUpdate / startOTACheck

    @MainActor
    func testStartOTAUpdateSetsRequestedPhase() {
        store.apply(.devices([DeviceFixture.light()]))
        store.startOTAUpdate(for: "Living Room Light")
        XCTAssertEqual(store.otaUpdates["Living Room Light"]?.phase, .requested)
    }

    @MainActor
    func testStartOTACheckSetsCheckingPhase() {
        store.apply(.devices([DeviceFixture.light()]))
        store.startOTACheck(for: "Living Room Light")
        XCTAssertEqual(store.otaUpdates["Living Room Light"]?.phase, .checking)
    }

    // MARK: - bridgeHealth

    @MainActor
    func testApplyBridgeHealthSetsHealthy() {
        let health = BridgeHealth(healthy: true, responseTime: 32, process: nil, os: nil, mqtt: nil)
        store.apply(.bridgeHealth(health))
        XCTAssertTrue(store.bridgeHealth?.healthy ?? false)
    }

    @MainActor
    func testApplyHealthMergesSparseResponse() throws {
        let richJSON = """
        {"healthy":true,"response_time":32,
         "process":{"uptime":3600,"memory_usage":42.0,"memory_usage_mb":85.0},
         "os":null,"mqtt":null}
        """
        let rich = try JSONDecoder().decode(BridgeHealth.self, from: Data(richJSON.utf8))
        store.apply(.bridgeHealth(rich))

        let sparse = BridgeHealth(healthy: false, responseTime: nil, process: nil, os: nil, mqtt: nil)
        store.apply(.bridgeHealth(sparse))

        XCTAssertFalse(store.bridgeHealth?.healthy ?? true)
        XCTAssertNotNil(store.bridgeHealth?.process)
    }

    // MARK: - reset

    @MainActor
    func testResetClearsAllState() {
        store.apply(.devices([DeviceFixture.light()]))
        store.apply(.bridgeState("online"))
        store.apply(.logMessage(makeLogMessage(msg: "hello")))
        store.reset()

        XCTAssertTrue(store.devices.isEmpty)
        XCTAssertFalse(store.bridgeOnline)
        XCTAssertTrue(store.logEntries.isEmpty)
        XCTAssertNil(store.bridgeInfo)
    }

    // MARK: - device(named:)

    @MainActor
    func testDeviceNamedFindsDevice() {
        store.apply(.devices([DeviceFixture.light()]))
        XCTAssertNotNil(store.device(named: "Living Room Light"))
    }

    @MainActor
    func testDeviceNamedReturnsNilForUnknown() {
        XCTAssertNil(store.device(named: "Nonexistent"))
    }

    // MARK: - touchlink

    @MainActor
    func testTouchlinkScanResultPopulatesDevices() {
        store.apply(.touchlinkScanResult([TouchlinkDevice(ieeeAddress: "0xABC", channel: 15)]))
        XCTAssertEqual(store.touchlinkDevices.count, 1)
    }

    // MARK: - operationError

    @MainActor
    func testOperationErrorIsAdded() {
        let err = Z2MOperationError(id: UUID(), topic: "bridge/response/device/rename",
                                    message: "not found", timestamp: .now)
        store.apply(.operationError(err))
        XCTAssertFalse(store.operationErrors.isEmpty)
    }

    // MARK: - Helpers

    @MainActor
    private func makeLogMessage(msg: String) -> LogMessage {
        let json = #"{"level":"info","message":"\#(msg)"}"#
        return try! JSONDecoder().decode(LogMessage.self, from: Data(json.utf8))
    }

    @MainActor
    private func makeGroup(id: Int, name: String) -> Group {
        Group(id: id, friendlyName: name, description: nil, members: [], scenes: [])
    }

    @MainActor
    private func decodeBridgeInfo() throws -> BridgeInfo {
        let json = """
        {
          "version": "2.1.0", "commit": "abc",
          "coordinator": {"ieee_address": "0x00124b0000000000", "type": "zStack30x", "meta": {}},
          "network": {"channel": 11, "pan_id": 6754, "extended_pan_id": "0xdd"},
          "log_level": "info", "permit_join": false, "restart_required": false,
          "config": {}
        }
        """
        return try JSONDecoder().decode(BridgeInfo.self, from: Data(json.utf8))
    }
}
