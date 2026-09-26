import XCTest
@testable import Shellbee

final class GroupDeviceDropPolicyTests: XCTestCase {
    func testSameBridgeDropBuildsOneExactAddMemberRequest() {
        let bridgeID = UUID()

        let outcome = evaluate(sourceBridgeID: bridgeID, targetBridgeID: bridgeID)

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
        let outcome = evaluate(sourceBridgeID: UUID(), targetBridgeID: UUID())

        guard case .rejected(let reason) = outcome else {
            return XCTFail("Expected a rejected drop")
        }
        XCTAssertTrue(reason.contains("same bridge"))
    }

    func testDuplicateMembershipDoesNotBuildRequest() {
        let bridgeID = UUID()
        let outcome = evaluate(sourceBridgeID: bridgeID, targetBridgeID: bridgeID, groupMembers: ["0x01"])

        XCTAssertEqual(outcome, .alreadyMember(deviceName: "Lamp"))
    }

    func testMissingSourceBridgeAndMissingDeviceAreRejected() {
        let bridgeID = UUID()
        let noBridge = evaluate(sourceBridgeID: nil, targetBridgeID: bridgeID)
        let missingDevice = evaluate(sourceBridgeID: bridgeID, targetBridgeID: bridgeID, availableDevice: nil)

        guard case .rejected = noBridge else {
            return XCTFail("Expected missing bridge rejection")
        }
        guard case .rejected = missingDevice else {
            return XCTFail("Expected missing device rejection")
        }
    }

    func testCoordinatorCannotBeAddedToAGroup() {
        let bridgeID = UUID()
        let outcome = evaluate(sourceBridgeID: bridgeID, targetBridgeID: bridgeID, availableDevice: GroupDeviceDropCandidate(
            ieeeAddress: "0x01",
            name: "Coordinator",
            isCoordinator: true,
            endpoint: 1
        ))

        guard case .rejected = outcome else {
            return XCTFail("Expected coordinator rejection")
        }
    }

    private func evaluate(
        sourceBridgeID: UUID?,
        targetBridgeID: UUID,
        groupMembers: Set<String> = [],
        availableDevice: GroupDeviceDropCandidate? = GroupDeviceDropCandidate(
            ieeeAddress: "0x01",
            name: "Lamp",
            isCoordinator: false,
            endpoint: 2
        )
    ) -> GroupDeviceDropOutcome {
        GroupDeviceDropDecision.evaluate(
            sourceBridgeID: sourceBridgeID,
            targetBridgeID: targetBridgeID,
            draggedIEEEAddress: "0x01",
            targetGroupID: 7,
            targetGroupMembers: groupMembers,
            availableDevice: availableDevice
        )
    }
}
