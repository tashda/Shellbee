import XCTest
@testable import Shellbee

final class Z2MMessageRouterTests: XCTestCase, @unchecked Sendable {

    var router: Z2MMessageRouter!

    override func setUp() {
        super.setUp()
        router = MainActor.assumeIsolated { Z2MMessageRouter() }
    }

    override func tearDown() {
        MainActor.assumeIsolated { router = nil }
        super.tearDown()
    }

    // MARK: - bridge/info

    @MainActor

    func testRoutesBridgeInfo() {
        let data = Z2MFrame.makeJSON(topic: "bridge/info", payloadJSON: bridgeInfoJSON)
        let event = router.route(data)
        guard case .bridgeInfo(let info) = event else {
            return XCTFail("Expected .bridgeInfo, got \(String(describing: event))")
        }
        XCTAssertEqual(info.version, "2.1.0")
    }

    // MARK: - bridge/state

    @MainActor

    func testRoutesBridgeStateOnline() {
        let data = Z2MFrame.make(topic: "bridge/state", payload: "online")
        guard case .bridgeState(let s) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(s, "online")
    }

    @MainActor

    func testRoutesBridgeStateOffline() {
        let data = Z2MFrame.make(topic: "bridge/state", payload: "offline")
        guard case .bridgeState(let s) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(s, "offline")
    }

    @MainActor

    func testRoutesBridgeStateObjectFormat() {
        let data = Z2MFrame.make(topic: "bridge/state", payload: ["state": "online"])
        guard case .bridgeState(let s) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(s, "online")
    }

    // MARK: - bridge/devices

    @MainActor

    func testRoutesBridgeDevices() {
        let devices = [DeviceFixture.light(), DeviceFixture.sensor()]
        let data = FrameFixture.bridgeDevices(devices)
        guard case .devices(let list) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(list.count, 2)
    }

    // MARK: - bridge/groups

    @MainActor

    func testRoutesBridgeGroups() {
        let data = Z2MFrame.make(topic: "bridge/groups", payload: [
            ["id": 1, "friendly_name": "All Lights", "description": NSNull(),
             "members": [], "scenes": []]
        ])
        guard case .groups(let list) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].friendlyName, "All Lights")
    }

    // MARK: - bridge/logging

    @MainActor

    func testRoutesLogMessage() {
        let data = FrameFixture.logMessage(level: "info", message: "Test log")
        guard case .logMessage(let msg) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(msg.level, "info")
        XCTAssertEqual(msg.message, "Test log")
    }

    // MARK: - bridge/event

    @MainActor

    func testRoutesBridgeEventDeviceJoined() {
        let data = FrameFixture.bridgeEvent(type: "device_joined", friendlyName: "NewDevice")
        guard case .bridgeEvent(let e) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(e.type, "device_joined")
    }

    @MainActor

    func testRoutesBridgeEventDeviceLeave() {
        let data = FrameFixture.bridgeEvent(type: "device_leave", friendlyName: "OldDevice")
        guard case .bridgeEvent(let e) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(e.type, "device_leave")
    }

    @MainActor

    func testRoutesBridgeEventInterview() {
        let data = FrameFixture.bridgeEvent(type: "device_interview", friendlyName: "Dev")
        guard case .bridgeEvent(_) = router.route(data) else { return XCTFail() }
    }

    // MARK: - bridge/health

    @MainActor

    func testRoutesBridgeHealth() {
        let data = Z2MFrame.make(topic: "bridge/health", payload: [
            "healthy": true, "response_time": 32,
            "process": ["uptime": 3600, "memory_usage": 42.5, "memory_usage_mb": 85.2],
            "os": ["load_average_5m": 1.2, "memory_usage": 55.3, "memory_usage_gb": 3.7],
            "mqtt": ["connected": true, "queued": 0, "published": 100, "received": 200]
        ])
        guard case .bridgeHealth(let h) = router.route(data) else { return XCTFail() }
        XCTAssertTrue(h.healthy == true)
    }

    // MARK: - OTA

    @MainActor

    func testRoutesOTAUpdateResponse() {
        let data = FrameFixture.otaUpdateResponse(deviceName: "TestBulb")
        guard case .deviceOTAUpdateResponse(let r) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(r.deviceName, "TestBulb")
    }

    @MainActor

    func testRoutesOTACheckResponse() {
        let data = FrameFixture.otaCheckResponse(deviceName: "TestBulb")
        guard case .deviceOTACheckResponse(let r) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(r.deviceName, "TestBulb")
    }

    @MainActor

    func testRoutesOTAUpdateError() {
        let data = Z2MFrame.make(
            topic: "bridge/response/device/ota_update/update",
            payload: ["status": "error", "error": "Update failed for 'TestBulb': timeout"]
        )
        guard case .deviceOTAUpdateResponse(let r) = router.route(data) else { return XCTFail() }
        XCTAssertFalse(r.isSuccess)
        XCTAssertEqual(r.deviceName, "TestBulb")
    }

    // MARK: - bridge/response/options

    @MainActor

    func testRoutesBridgeResponseOptions() {
        let data = FrameFixture.bridgeResponse(topic: "bridge/response/options",
                                               data: ["restart_required": false])
        guard case .bridgeResponse(let topic, _) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(topic, "bridge/response/options")
    }

    // MARK: - Touchlink

    @MainActor

    func testRoutesTouchlinkScan() {
        let data = Z2MFrame.make(
            topic: "bridge/response/touchlink/scan",
            payload: ["status": "ok", "data": ["found": []]]
        )
        guard case .touchlinkScanResult(_) = router.route(data) else { return XCTFail() }
    }

    @MainActor

    func testRoutesTouchlinkIdentifyDone() {
        let data = FrameFixture.bridgeResponse(topic: "bridge/response/touchlink/identify")
        // Error path: the router returns .bridgeResponse for non-scan touchlink
        // since these are handled via the default generic response path
        let event = router.route(data)
        XCTAssertNotNil(event)
    }

    // MARK: - Device topics (dynamic routing)

    @MainActor

    func testRoutesDeviceState() {
        let data = FrameFixture.deviceState(name: "Living Room Light",
                                             state: StateFixture.lightOn())
        guard case .deviceState(let name, let state) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(name, "Living Room Light")
        XCTAssertEqual(state["state"]?.stringValue, "ON")
    }

    @MainActor

    func testRoutesDeviceAvailabilityOnline() {
        let data = FrameFixture.availability(name: "Kitchen Plug", online: true)
        guard case .deviceAvailability(let name, let available) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(name, "Kitchen Plug")
        XCTAssertTrue(available)
    }

    @MainActor

    func testRoutesDeviceAvailabilityOffline() {
        let data = FrameFixture.availability(name: "Office Sensor", online: false)
        guard case .deviceAvailability(_, let available) = router.route(data) else { return XCTFail() }
        XCTAssertFalse(available)
    }

    @MainActor

    func testRoutesGenericBridgeError() {
        let data = Z2MFrame.make(
            topic: "bridge/response/device/rename",
            payload: ["status": "error", "error": "Device not found"]
        )
        guard case .operationError(_) = router.route(data) else { return XCTFail() }
    }

    // MARK: - Malformed / Unknown

    @MainActor

    func testMalformedJSONReturnsNil() {
        let data = Data("not json at all".utf8)
        XCTAssertNil(router.route(data))
    }

    @MainActor

    func testUnknownTopicWithNonObjectPayload() {
        let data = Z2MFrame.make(topic: "random/topic", payload: "string-payload")
        guard case .unknown(let topic) = router.route(data) else { return XCTFail() }
        XCTAssertEqual(topic, "random/topic")
    }

    // MARK: - Topic constants

    @MainActor

    func testTopicConstantsMatchExpected() {
        XCTAssertEqual(Z2MTopics.bridgeInfo, "bridge/info")
        XCTAssertEqual(Z2MTopics.bridgeDevices, "bridge/devices")
        XCTAssertEqual(Z2MTopics.bridgeGroups, "bridge/groups")
        XCTAssertEqual(Z2MTopics.bridgeLogging, "bridge/logging")
        XCTAssertEqual(Z2MTopics.bridgeEvent, "bridge/event")
        XCTAssertEqual(Z2MTopics.availabilitySuffix, "/availability")
    }

    @MainActor

    func testDeviceSetTopic() {
        XCTAssertEqual(Z2MTopics.deviceSet("My Light"), "My Light/set")
    }

    @MainActor

    func testDeviceSetTopicWithSpaces() {
        XCTAssertEqual(Z2MTopics.deviceSet("Living Room Lamp"), "Living Room Lamp/set")
    }

    // MARK: - Fixtures

    private let bridgeInfoJSON = """
    {
      "version": "2.1.0",
      "commit": "abc123",
      "coordinator": {
        "ieee_address": "0x00124b0000000000",
        "type": "zStack30x",
        "meta": {"revision": 20230507}
      },
      "network": {"channel": 11, "pan_id": 6754, "extended_pan_id": "0xdddddddddddddddd"},
      "log_level": "info",
      "permit_join": false,
      "restart_required": false,
      "config": {}
    }
    """
}
