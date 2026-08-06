import Foundation

@Observable
final class GroupsWorkspaceState {
    var selectedGroup: GroupRoute?
    var selectedMember: DeviceRoute?

    func selectGroup(_ route: GroupRoute?) {
        guard let route else {
            selectedGroup = nil
            selectedMember = nil
            return
        }

        if !Self.sameGroup(selectedGroup, route) {
            selectedMember = nil
        }
        selectedGroup = route
        reconcileMemberWithSelectedGroup()
    }

    func selectMember(_ route: DeviceRoute?) {
        guard let route else {
            selectedMember = nil
            return
        }
        guard let group = selectedGroup,
              group.bridgeID == route.bridgeID,
              group.group.members.contains(where: { $0.ieeeAddress == route.device.ieeeAddress })
        else { return }
        selectedMember = route
    }

    func reconcile(groups: [BridgeBoundGroup], devices: [BridgeBoundDevice]) {
        guard let selectedGroup else {
            selectedMember = nil
            return
        }

        guard let currentGroup = groups.first(where: {
            $0.bridgeID == selectedGroup.bridgeID && $0.group.id == selectedGroup.group.id
        }) else {
            self.selectedGroup = nil
            selectedMember = nil
            return
        }

        self.selectedGroup = GroupRoute(
            bridgeID: currentGroup.bridgeID,
            group: currentGroup.group
        )

        guard let selectedMember else { return }
        guard currentGroup.group.members.contains(where: {
            $0.ieeeAddress == selectedMember.device.ieeeAddress
        }), let currentDevice = devices.first(where: {
            $0.bridgeID == selectedMember.bridgeID
                && $0.device.ieeeAddress == selectedMember.device.ieeeAddress
        }) else {
            self.selectedMember = nil
            return
        }

        self.selectedMember = DeviceRoute(
            bridgeID: currentDevice.bridgeID,
            device: currentDevice.device
        )
    }

    private func reconcileMemberWithSelectedGroup() {
        guard let group = selectedGroup, let member = selectedMember else { return }
        if group.bridgeID != member.bridgeID
            || !group.group.members.contains(where: { $0.ieeeAddress == member.device.ieeeAddress }) {
            selectedMember = nil
        }
    }

    private static func sameGroup(_ lhs: GroupRoute?, _ rhs: GroupRoute) -> Bool {
        lhs?.bridgeID == rhs.bridgeID && lhs?.group.id == rhs.group.id
    }
}
