import SwiftUI

struct GroupMembersSection: View {
    @Environment(AppEnvironment.self) private var environment
    let bridgeID: UUID
    let group: Group
    let onRemove: (GroupMember) -> Void
    var onAdd: (() -> Void)? = nil

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    var body: some View {
        if group.members.isEmpty {
            emptySection
        } else {
            populatedSection
        }
    }

    private var emptySection: some View {
        Section("Members") {
            VStack(spacing: DesignTokens.Spacing.lg) {
                Image(systemName: "person.2")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.secondary)
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Text("No Members")
                        .font(.headline)
                    Text("Add devices to this group to control them together.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                }
                if let onAdd {
                    Button(action: onAdd) {
                        Label("Add Members", systemImage: "plus")
                            .fontWeight(.semibold)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .padding(.top, DesignTokens.Spacing.xs)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.xl)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var populatedSection: some View {
        Section("Members") {
            ForEach(group.members, id: \.ieeeAddress) { member in
                let device = scope.store.devices.first { $0.ieeeAddress == member.ieeeAddress }
                SwiftUI.Group {
                    if let device {
                        NavigationLink(value: DeviceRoute(bridgeID: bridgeID, device: device)) {
                            GroupMemberRow(
                                member: member,
                                device: device,
                                state: scope.store.state(for: device.friendlyName),
                                isAvailable: scope.store.isAvailable(device.friendlyName)
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

#Preview {
    List {
        GroupMembersSection(bridgeID: UUID(), group: .previewWithMembers, onRemove: { _ in })
    }
    .environment(AppEnvironment())
}
