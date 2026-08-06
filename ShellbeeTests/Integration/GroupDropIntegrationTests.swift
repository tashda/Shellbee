import XCTest
@testable import Shellbee

final class GroupDropIntegrationTests: XCTestCase, @unchecked Sendable {
    @MainActor
    func testRealDualBridgeFixturesRejectCrossBridgeDrop() async throws {
        let primary = try await snapshot(
            port: 8080,
            token: "shellbee-integration-token"
        )
        let secondary = try await snapshot(
            port: 8082,
            token: "shellbee-integration-token-2"
        )
        let primaryBridgeID = UUID()
        let secondaryBridgeID = UUID()
        let source = try XCTUnwrap(primary.devices.first(where: { $0.type != .coordinator }))
        let target = try XCTUnwrap(secondary.groups.first)
        let payload = DeviceTransferPayload(
            device: source,
            bridgeID: primaryBridgeID,
            bridgeName: "Primary"
        )

        let crossBridge = GroupDeviceDropPolicy.evaluate(
            payload,
            targetGroup: target,
            targetBridgeID: secondaryBridgeID,
            availableDevices: secondary.devices
        )

        guard case .rejected(let reason) = crossBridge else {
            return XCTFail("A primary-bridge device must not produce a secondary-bridge request")
        }
        XCTAssertTrue(reason.contains("same bridge"))
    }

    @MainActor
    func testRealPrimaryFixtureBuildsRequestForOwningBridgeOnly() async throws {
        let snapshot = try await snapshot(
            port: 8080,
            token: "shellbee-integration-token"
        )
        let bridgeID = UUID()
        let group = try XCTUnwrap(snapshot.groups.first)
        let memberIEEEs = Set(group.members.map(\.ieeeAddress))
        let device = try XCTUnwrap(snapshot.devices.first(where: {
            $0.type != .coordinator && !memberIEEEs.contains($0.ieeeAddress)
        }))
        let payload = DeviceTransferPayload(
            device: device,
            bridgeID: bridgeID,
            bridgeName: "Primary"
        )

        let outcome = GroupDeviceDropPolicy.evaluate(
            payload,
            targetGroup: group,
            targetBridgeID: bridgeID,
            availableDevices: snapshot.devices
        )

        guard case .request(let request, _) = outcome else {
            return XCTFail("Expected a request for an eligible fixture device")
        }
        XCTAssertEqual(request.bridgeID, bridgeID)
        XCTAssertEqual(request.groupID, group.id)
        XCTAssertEqual(request.ieeeAddress, device.ieeeAddress)
    }

    @MainActor
    private func snapshot(port: Int, token: String) async throws -> BridgeSnapshot {
        guard await MockBridgeProbe.isReachable(host: "localhost", port: port) else {
            throw XCTSkip("Mock bridge is not reachable on port \(port)")
        }
        let config = ConnectionConfig(
            host: "localhost",
            port: port,
            useTLS: false,
            basePath: "/",
            authToken: token
        )
        let client = Z2MWebSocketClient()
        let router = Z2MMessageRouter()
        let stream = try await client.connect(url: try XCTUnwrap(config.webSocketURL))
        var devices: [Device]?
        var groups: [Group]?
        let deadline = Date().addingTimeInterval(20)

        for await socketEvent in stream {
            guard case .message(let data) = socketEvent else { break }
            if let event = router.route(data) {
                switch event {
                case .devices(let value): devices = value
                case .groups(let value): groups = value
                default: break
                }
            }
            if let devices, let groups {
                await client.disconnect()
                return BridgeSnapshot(devices: devices, groups: groups)
            }
            if Date() > deadline { break }
        }

        await client.disconnect()
        XCTFail("Bridge on port \(port) did not publish devices and groups")
        return BridgeSnapshot(devices: devices ?? [], groups: groups ?? [])
    }

    private struct BridgeSnapshot {
        let devices: [Device]
        let groups: [Group]
    }
}
