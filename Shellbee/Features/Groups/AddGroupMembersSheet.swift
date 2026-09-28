import SwiftUI

/// Picks devices to add to a group. Members must come from the group's own
/// bridge: z2m can't add cross-bridge members.
struct AddGroupMembersSheet: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let group: Group
    let onConfirm: ([(Device, Int)]) -> Void

    private var items: [DevicePickerItem] {
        let memberIEEEs = Set(group.members.map(\.ieeeAddress))
        return environment.devicePickerItems(bridgeID: bridgeID)
            .filter { !memberIEEEs.contains($0.device.ieeeAddress) }
    }

    var body: some View {
        let items = items
        DevicePickerSheet(
            title: "Add Devices",
            items: items,
            showsEndpoints: true,
            confirmTitle: "Add",
            emptyTitle: "No Devices Available",
            emptyDescription: "All devices are already in this group."
        ) { selection in
            onConfirm(items.compactMap { item in
                selection[item.id].map { (item.device, $0) }
            })
        }
    }
}

#Preview {
    AddGroupMembersSheet(bridgeID: UUID(), group: .preview) { _ in }
        .environment(AppEnvironment())
}
