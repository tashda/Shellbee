import Foundation

@Observable
final class GroupsWorkspaceState {
    var selectedGroup: GroupRoute?

    func selectGroup(_ route: GroupRoute?) {
        selectedGroup = route
    }

    func reconcile(groups: [BridgeBoundGroup]) {
        guard let selectedGroup else { return }

        guard let currentGroup = groups.first(where: {
            $0.bridgeID == selectedGroup.bridgeID && $0.group.id == selectedGroup.group.id
        }) else {
            self.selectedGroup = nil
            return
        }

        self.selectedGroup = GroupRoute(
            bridgeID: currentGroup.bridgeID,
            group: currentGroup.group
        )
    }
}
