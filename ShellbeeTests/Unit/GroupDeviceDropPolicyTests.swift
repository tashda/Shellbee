import XCTest
@testable import Shellbee

@MainActor
final class GroupDeviceDropPolicyTests: XCTestCase {
    func testSameBridgeDropBuildsOneExactAddMemberRequest() {
        let bridgeID = UUID()
        var device = makeDevice(ieee: "0x01")
        device.endpoints = ["2": .object([:])]
        let payload = DeviceTransferPayload(device: device, bridgeID: bridgeID, bridgeName: "Home")

        let outcome = GroupDeviceDropPolicy.evaluate(
            payload,
            targetGroup: makeGroup(),
            targetBridgeID: bridgeID,
            availableDevices: [device]
        )

        XCTAssertEqual(
            outcome,
            .request(
                GroupMemberAddRequest(
                    bridgeID: bridgeID,
                    groupID: 7,
                    ieeeAddress: "0x01",
                    endpoint: 2
                ),
                deviceName: "Lamp"
            )
        )
    }

    func testCrossBridgeDropIsRejected() {
        let device = makeDevice(ieee: "0x01")
        let payload = DeviceTransferPayload(device: device, bridgeID: UUID(), bridgeName: "Home")

        let outcome = GroupDeviceDropPolicy.evaluate(
            payload,
            targetGroup: makeGroup(),
            targetBridgeID: UUID(),
            availableDevices: [device]
        )

        guard case .rejected(let reason) = outcome else {
            return XCTFail("Expected a rejected drop")
        }
        XCTAssertTrue(reason.contains("same bridge"))
    }

    func testDuplicateMembershipDoesNotBuildRequest() {
        let bridgeID = UUID()
        let device = makeDevice(ieee: "0x01")
        let payload = DeviceTransferPayload(device: device, bridgeID: bridgeID, bridgeName: "Home")
        var group = makeGroup()
        group.members = [GroupMember(ieeeAddress: device.ieeeAddress, endpoint: 1)]

        XCTAssertEqual(
            GroupDeviceDropPolicy.evaluate(
                payload,
                targetGroup: group,
                targetBridgeID: bridgeID,
                availableDevices: [device]
            ),
            .alreadyMember(deviceName: "Lamp")
        )
    }

    func testMissingSourceBridgeAndMissingDeviceAreRejected() {
        let device = makeDevice(ieee: "0x01")
        let noBridge = DeviceTransferPayload(device: device, bridgeID: nil, bridgeName: nil)
        let bridgeID = UUID()
        let missing = DeviceTransferPayload(device: device, bridgeID: bridgeID, bridgeName: "Home")

        guard case .rejected = GroupDeviceDropPolicy.evaluate(
            noBridge,
            targetGroup: makeGroup(),
            targetBridgeID: bridgeID,
            availableDevices: [device]
        ) else { return XCTFail("Expected missing bridge rejection") }
        guard case .rejected = GroupDeviceDropPolicy.evaluate(
            missing,
            targetGroup: makeGroup(),
            targetBridgeID: bridgeID,
            availableDevices: []
        ) else { return XCTFail("Expected missing device rejection") }
    }

    private func makeGroup() -> Group {
        Group(id: 7, friendlyName: "Living", members: [], scenes: [])
    }

    private func makeDevice(ieee: String) -> Device {
        Device(
            ieeeAddress: ieee,
            type: .router,
            networkAddress: 1,
            supported: true,
            friendlyName: "Lamp",
            disabled: false,
            definition: nil,
            powerSource: nil,
            interviewCompleted: true,
            interviewing: false
        )
    }
}
