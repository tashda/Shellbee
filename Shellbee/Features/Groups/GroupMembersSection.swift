import SwiftUI

struct GroupMembersSection: View {
    @Environment(AppEnvironment.self) private var environment
    let group: Group
    let onRemove: (GroupMember) -> Void
    var onAdd: (() -> Void)? = nil

    var body: some View {
        Section("Members") {
            if group.members.isEmpty {
                ContentUnavailableView {
                    Label("No Members", systemImage: "person.2")
                } description: {
                    Text("Add devices to this group to control them together.")
                } actions: {
                    if let onAdd {
                        Button(action: onAdd) {
                            Label("Add Members", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } else {
                ForEach(group.members, id: \.ieeeAddress) { member in
                    let device = environment.store.devices.first { $0.ieeeAddress == member.ieeeAddress }
                    SwiftUI.Group {
                        if let device {
                            NavigationLink(value: device) {
                                GroupMemberRow(
                                    member: member,
                                    device: device,
                                    state: environment.store.state(for: device.friendlyName),
                                    isAvailable: environment.store.isAvailable(device.friendlyName)
                                )
                            }
                        } else {
                            GroupMemberRow(member: member, device: nil, state: [:], isAvailable: false)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            onRemove(member)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    List {
        GroupMembersSection(group: .previewWithMembers, onRemove: { _ in })
    }
    .environment(AppEnvironment())
}
