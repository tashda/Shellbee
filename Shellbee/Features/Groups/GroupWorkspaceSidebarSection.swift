import SwiftUI

struct GroupWorkspaceSidebarSection: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var workspace: GroupsWorkspaceState

    private var groups: [BridgeBoundGroup] {
        environment.allGroups.sorted {
            let nameOrder = $0.group.friendlyName.localizedCompare($1.group.friendlyName)
            if nameOrder == .orderedSame {
                return $0.bridgeName.localizedCompare($1.bridgeName) == .orderedAscending
            }
            return nameOrder == .orderedAscending
        }
    }

    private var showsBridgeNames: Bool {
        environment.registry.orderedSessions.filter(\.isConnected).count > 1
    }

    var body: some View {
        Section("Groups") {
            if groups.isEmpty {
                Text("No Groups")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups) { bound in
                    groupButton(bound)
                }
            }
        }
        .onAppear { consumePendingNavigation() }
        .onChange(of: environment.pendingGroupNavigation) { _, route in
            guard route != nil else { return }
            consumePendingNavigation()
        }
    }

    private func groupButton(_ bound: BridgeBoundGroup) -> some View {
        let route = GroupRoute(bridgeID: bound.bridgeID, group: bound.group)
        let isSelected = workspace.selectedGroup?.bridgeID == bound.bridgeID
            && workspace.selectedGroup?.group.id == bound.group.id

        return Button {
            workspace.selectGroup(route)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Label(bound.group.friendlyName, systemImage: "rectangle.3.group.fill")
                    if showsBridgeNames {
                        Text(bound.bridgeName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "")
    }

    private func consumePendingNavigation() {
        guard let route = environment.pendingGroupNavigation else { return }
        environment.pendingGroupNavigation = nil
        workspace.selectGroup(route)
    }
}
