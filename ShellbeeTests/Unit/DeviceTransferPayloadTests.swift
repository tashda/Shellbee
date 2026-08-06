import XCTest
@testable import Shellbee

final class DeviceTransferPayloadTests: XCTestCase {
    func testPayloadUsesStableDeviceAndBridgeIdentity() throws {
        let bridgeID = UUID(uuidString: "6D7EA320-BA2B-4827-AE54-1EF0795C5878")!
        let payload = DeviceTransferPayload(
            device: DeviceFixture.sensor(),
            bridgeID: bridgeID,
            bridgeName: "Home"
        )

        XCTAssertEqual(payload.schemaVersion, 1)
        XCTAssertEqual(payload.friendlyName, "Office Sensor")
        XCTAssertEqual(payload.ieeeAddress, "0x00158d0001234567")
        XCTAssertEqual(payload.model, "WSDCGQ11LM")
        XCTAssertEqual(payload.manufacturer, "Aqara")
        XCTAssertEqual(payload.deviceType, "End Device")
        XCTAssertEqual(payload.bridgeID, bridgeID)
        XCTAssertEqual(payload.bridgeName, "Home")
    }

    func testJSONUsesDocumentedKeysAndExcludesPrivateConnectionData() throws {
        let payload = DeviceTransferPayload(
            device: DeviceFixture.light(),
            bridgeID: UUID(uuidString: "5B1FF50A-F77D-487B-9A26-5C5660B11A26"),
            bridgeName: "Workshop"
        )

        let data = try JSONEncoder().encode(payload)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["schema_version"] as? Int, 1)
        XCTAssertEqual(object["friendly_name"] as? String, "Living Room Light")
        XCTAssertEqual(object["ieee_address"] as? String, "0x000b57fffec6a5b3")
        XCTAssertEqual(object["bridge_name"] as? String, "Workshop")
        XCTAssertNil(object["auth_token"])
        XCTAssertNil(object["hostname"])
        XCTAssertNil(object["state"])
        XCTAssertNil(object["endpoints"])
        XCTAssertEqual(Set(object.keys), [
            "schema_version", "friendly_name", "ieee_address", "model",
            "manufacturer", "device_type", "bridge_id", "bridge_name"
        ])
    }

    func testPlainTextIsUsefulAndDisambiguatesBridge() {
        let payload = DeviceTransferPayload(
            device: DeviceFixture.switchPlug(),
            bridgeID: UUID(),
            bridgeName: "Lab"
        )

        XCTAssertEqual(
            payload.plainText,
            "Kitchen Plug — 0x000b57fffec51378 — Bridge: Lab"
        )
    }

    func testBlankBridgeNameIsOmitted() {
        let payload = DeviceTransferPayload(
            device: DeviceFixture.switchPlug(),
            bridgeID: nil,
            bridgeName: "  "
        )

        XCTAssertNil(payload.bridgeName)
        XCTAssertEqual(payload.plainText, "Kitchen Plug — 0x000b57fffec51378")
    }

    func testPayloadRoundTripsThroughJSON() throws {
        let original = DeviceTransferPayload(
            device: DeviceFixture.sensor(),
            bridgeID: UUID(),
            bridgeName: "Home"
        )

        let decoded = try JSONDecoder().decode(
            DeviceTransferPayload.self,
            from: JSONEncoder().encode(original)
        )

        XCTAssertEqual(decoded, original)
    }
}
