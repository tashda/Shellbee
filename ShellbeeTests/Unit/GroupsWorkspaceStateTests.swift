import XCTest
@testable import Shellbee

@MainActor
final class GroupsWorkspaceStateTests: XCTestCase {
    func testMovingBetweenMembersPreservesSelectedGroup() {
        let bridgeID = UUID()
        let first = makeDevice(name: "Lamp", ieee: "0x01")
        let second = makeDevice(name: "Plug", ieee: "0x02")
        let group = makeGroup(id: 1, name: "Living", members: [first, second])
        let state = GroupsWorkspaceState()

        state.selectGroup(GroupRoute(bridgeID: bridgeID, group: group))
        state.selectMember(DeviceRoute(bridgeID: bridgeID, device: first))
        state.selectMember(DeviceRoute(bridgeID: bridgeID, device: second))

        XCTAssertEqual(state.selectedGroup?.group.id, group.id)
        XCTAssertEqual(state.selectedMember?.device.ieeeAddress, second.ieeeAddress)
    }

    func testRemovingSelectedMemberClearsOnlyMemberSelection() {
        let bridgeID = UUID()
        let device = makeDevice(name: "Lamp", ieee: "0x01")
        let group = makeGroup(id: 1, name: "Living", members: [device])
        let updated = makeGroup(id: 1, name: "Living", members: [])
        let state = GroupsWorkspaceState()
        state.selectGroup(GroupRoute(bridgeID: bridgeID, group: group))
        state.selectMember(DeviceRoute(bridgeID: bridgeID, device: device))

        state.reconcile(
            groups: [boundGroup(updated, bridgeID: bridgeID)],
            devices: [boundDevice(device, bridgeID: bridgeID)]
        )

        XCTAssertEqual(state.selectedGroup?.group.id, group.id)
        XCTAssertNil(state.selectedMember)
    }

    func testRenameRefreshesRoutesWithoutLosingSelection() {
        let bridgeID = UUID()
        let device = makeDevice(name: "Lamp", ieee: "0x01")
        let renamedDevice = makeDevice(name: "Reading Lamp", ieee: "0x01")
        let group = makeGroup(id: 1, name: "Living", members: [device])
        let renamedGroup = makeGroup(id: 1, name: "Living Room", members: [device])
        let state = GroupsWorkspaceState()
        state.selectGroup(GroupRoute(bridgeID: bridgeID, group: group))
        state.selectMember(DeviceRoute(bridgeID: bridgeID, device: device))

        state.reconcile(
            groups: [boundGroup(renamedGroup, bridgeID: bridgeID)],
            devices: [boundDevice(renamedDevice, bridgeID: bridgeID)]
        )

        XCTAssertEqual(state.selectedGroup?.group.friendlyName, "Living Room")
        XCTAssertEqual(state.selectedMember?.device.friendlyName, "Reading Lamp")
    }

    func testRemovingSelectedGroupClearsGroupAndMember() {
        let bridgeID = UUID()
        let device = makeDevice(name: "Lamp", ieee: "0x01")
        let group = makeGroup(id: 1, name: "Living", members: [device])
        let state = GroupsWorkspaceState()
        state.selectGroup(GroupRoute(bridgeID: bridgeID, group: group))
        state.selectMember(DeviceRoute(bridgeID: bridgeID, device: device))

        state.reconcile(groups: [], devices: [boundDevice(device, bridgeID: bridgeID)])

        XCTAssertNil(state.selectedGroup)
        XCTAssertNil(state.selectedMember)
    }

    func testDuplicateNamesAndGroupIDsStayScopedToBridge() {
        let firstBridge = UUID()
        let secondBridge = UUID()
        let firstDevice = makeDevice(name: "Lamp", ieee: "0x01")
        let secondDevice = makeDevice(name: "Lamp", ieee: "0x02")
        let firstGroup = makeGroup(id: 1, name: "Living", members: [firstDevice])
        let secondGroup = makeGroup(id: 1, name: "Living", members: [secondDevice])
        let state = GroupsWorkspaceState()
        state.selectGroup(GroupRoute(bridgeID: secondBridge, group: secondGroup))

        state.selectMember(DeviceRoute(bridgeID: firstBridge, device: firstDevice))
        XCTAssertNil(state.selectedMember)

        state.selectMember(DeviceRoute(bridgeID: secondBridge, device: secondDevice))
        state.reconcile(
            groups: [
                boundGroup(firstGroup, bridgeID: firstBridge),
                boundGroup(secondGroup, bridgeID: secondBridge)
            ],
            devices: [
                boundDevice(firstDevice, bridgeID: firstBridge),
                boundDevice(secondDevice, bridgeID: secondBridge)
            ]
        )

        XCTAssertEqual(state.selectedGroup?.bridgeID, secondBridge)
        XCTAssertEqual(state.selectedMember?.bridgeID, secondBridge)
    }

    private func makeGroup(id: Int, name: String, members: [Device]) -> Group {
        Group(
            id: id,
            friendlyName: name,
            members: members.map { GroupMember(ieeeAddress: $0.ieeeAddress, endpoint: 1) },
            scenes: []
        )
    }

    private func makeDevice(name: String, ieee: String) -> Device {
        Device(
            ieeeAddress: ieee,
            type: .endDevice,
            networkAddress: 1,
            supported: true,
            friendlyName: name,
            disabled: false,
            definition: nil,
            powerSource: nil,
            interviewCompleted: true,
            interviewing: false
        )
    }

    private func boundGroup(_ group: Group, bridgeID: UUID) -> BridgeBoundGroup {
        BridgeBoundGroup(bridgeID: bridgeID, bridgeName: "Bridge", group: group)
    }

    private func boundDevice(_ device: Device, bridgeID: UUID) -> BridgeBoundDevice {
        BridgeBoundDevice(bridgeID: bridgeID, bridgeName: "Bridge", device: device)
    }
}
