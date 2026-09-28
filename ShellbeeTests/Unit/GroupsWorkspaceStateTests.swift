import XCTest
@testable import Shellbee

@MainActor
final class GroupsWorkspaceStateTests: XCTestCase {
    func testRenameRefreshesRouteWithoutLosingSelection() {
        let bridgeID = UUID()
        let group = makeGroup(id: 1, name: "Living", members: [])
        let renamedGroup = makeGroup(id: 1, name: "Living Room", members: [])
        let state = GroupsWorkspaceState()
        state.selectGroup(GroupRoute(bridgeID: bridgeID, group: group))

        state.reconcile(groups: [boundGroup(renamedGroup, bridgeID: bridgeID)])

        XCTAssertEqual(state.selectedGroup?.group.friendlyName, "Living Room")
    }

    func testRemovingSelectedGroupClearsSelection() {
        let bridgeID = UUID()
        let group = makeGroup(id: 1, name: "Living", members: [])
        let state = GroupsWorkspaceState()
        state.selectGroup(GroupRoute(bridgeID: bridgeID, group: group))

        state.reconcile(groups: [])

        XCTAssertNil(state.selectedGroup)
    }

    func testDuplicateGroupIDsStayScopedToBridge() {
        let firstBridge = UUID()
        let secondBridge = UUID()
        let firstGroup = makeGroup(id: 1, name: "Living", members: [])
        let secondGroup = makeGroup(id: 1, name: "Living", members: [])
        let state = GroupsWorkspaceState()
        state.selectGroup(GroupRoute(bridgeID: secondBridge, group: secondGroup))

        state.reconcile(groups: [boundGroup(firstGroup, bridgeID: firstBridge)])
        XCTAssertNil(state.selectedGroup)

        state.selectGroup(GroupRoute(bridgeID: secondBridge, group: secondGroup))
        state.reconcile(groups: [
            boundGroup(firstGroup, bridgeID: firstBridge),
            boundGroup(secondGroup, bridgeID: secondBridge)
        ])
        XCTAssertEqual(state.selectedGroup?.bridgeID, secondBridge)
    }

    private func makeGroup(id: Int, name: String, members: [Device]) -> Group {
        Group(
            id: id,
            friendlyName: name,
            members: members.map { GroupMember(ieeeAddress: $0.ieeeAddress, endpoint: 1) },
            scenes: []
        )
    }

    private func boundGroup(_ group: Group, bridgeID: UUID) -> BridgeBoundGroup {
        BridgeBoundGroup(bridgeID: bridgeID, bridgeName: "Bridge", group: group)
    }
}
