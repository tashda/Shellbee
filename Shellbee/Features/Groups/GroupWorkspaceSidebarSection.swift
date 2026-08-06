import SwiftUI

struct GroupWorkspaceSidebarSection: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.sceneNavigation) private var sceneNavigation
    @Bindable var workspace: GroupsWorkspaceState
    @State private var favorites = DeviceFavoritesStore()
    @State private var activeDropTargetID: String?
    @State private var dropAlert: DropAlert?

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
        SwiftUI.Group {
            favoritesSection
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
        }
        .onAppear { consumePendingNavigation() }
        .onChange(of: sceneNavigation.pendingGroupNavigation) { _, route in
            guard route != nil else { return }
            consumePendingNavigation()
        }
        .alert(item: $dropAlert) { alert in
            switch alert {
            case .confirm(let addition):
                Alert(
                    title: Text("Add to \(addition.groupName)?"),
                    message: Text("Add \(addition.deviceName) to this Zigbee2MQTT group?"),
                    primaryButton: .default(Text("Add Member")) {
                        environment.send(
                            bridge: addition.request.bridgeID,
                            topic: addition.request.topic,
                            payload: addition.request.payload
                        )
                        Haptics.impact(.medium)
                    },
                    secondaryButton: .cancel()
                )
            case .feedback(let feedback):
                Alert(
                    title: Text(feedback.title),
                    message: Text(feedback.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private var favoritesSection: some View {
        Section("Favorites") {
            favoriteDropTarget
            ForEach(favorites.items) { favorite in
                favoriteButton(favorite)
            }
            .onMove(perform: favorites.move)
        }
    }

    private var favoriteDropTarget: some View {
        Label("Drop Device to Add", systemImage: "star")
            .foregroundStyle(activeDropTargetID == "favorites" ? Color.accentColor : Color.secondary)
            .dropDestination(for: DeviceTransferPayload.self) { payloads, _ in
                guard payloads.count == 1, let payload = payloads.first else {
                    showFeedback(
                        title: "One Device at a Time",
                        message: "Drop a single device into Favorites."
                    )
                    return false
                }
                if favorites.add(payload) {
                    Haptics.impact(.light)
                    return true
                }
                showFeedback(
                    title: payload.bridgeID == nil ? "Bridge Required" : "Already a Favorite",
                    message: payload.bridgeID == nil
                        ? "Only devices dragged from Shellbee can be added to Favorites."
                        : "\(payload.friendlyName) is already in Favorites."
                )
                return false
            } isTargeted: { isTargeted in
                activeDropTargetID = isTargeted ? "favorites" : nil
            }
            .listRowBackground(
                activeDropTargetID == "favorites"
                    ? Color.accentColor.opacity(DesignTokens.Opacity.chipFill)
                    : Color.clear
            )
    }

    private func favoriteButton(_ favorite: FavoriteDeviceReference) -> some View {
        Button {
            guard let bound = environment.allDevices.first(where: {
                $0.bridgeID == favorite.bridgeID && $0.device.ieeeAddress == favorite.ieeeAddress
            }) else {
                showFeedback(
                    title: "Device Unavailable",
                    message: "Connect \(favorite.bridgeName ?? "the source bridge") to open this favorite."
                )
                return
            }
            sceneNavigation.pendingDeviceNavigation = DeviceRoute(
                bridgeID: bound.bridgeID,
                device: bound.device
            )
            sceneNavigation.selectedTab = .devices
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                Label(favorite.friendlyName, systemImage: "star.fill")
                if showsBridgeNames, let bridgeName = favorite.bridgeName {
                    Text(bridgeName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { favorites.move(id: favorite.id, offset: -1) } label: {
                Label("Move Up", systemImage: "arrow.up")
            }
            Button { favorites.move(id: favorite.id, offset: 1) } label: {
                Label("Move Down", systemImage: "arrow.down")
            }
            Divider()
            Button(role: .destructive) { favorites.remove(id: favorite.id) } label: {
                Label("Remove from Favorites", systemImage: "star.slash")
            }
        }
        .accessibilityAction(named: "Move Up") { favorites.move(id: favorite.id, offset: -1) }
        .accessibilityAction(named: "Move Down") { favorites.move(id: favorite.id, offset: 1) }
        .accessibilityAction(named: "Remove from Favorites") { favorites.remove(id: favorite.id) }
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
        .dropDestination(for: DeviceTransferPayload.self) { payloads, _ in
            handleGroupDrop(payloads, target: bound)
        } isTargeted: { isTargeted in
            activeDropTargetID = isTargeted ? bound.id : nil
        }
        .listRowBackground(
            activeDropTargetID == bound.id
                ? Color.accentColor.opacity(DesignTokens.Opacity.chipFill)
                : Color.clear
        )
    }

    private func consumePendingNavigation() {
        guard let route = sceneNavigation.pendingGroupNavigation else { return }
        sceneNavigation.pendingGroupNavigation = nil
        workspace.selectGroup(route)
    }

    private func handleGroupDrop(
        _ payloads: [DeviceTransferPayload],
        target: BridgeBoundGroup
    ) -> Bool {
        guard payloads.count == 1, let payload = payloads.first else {
            showFeedback(
                title: "One Device at a Time",
                message: "Drop a single device onto a group."
            )
            return false
        }
        let devices = environment.registry.session(for: target.bridgeID)?.store.devices ?? []
        switch GroupDeviceDropPolicy.evaluate(
            payload,
            targetGroup: target.group,
            targetBridgeID: target.bridgeID,
            availableDevices: devices
        ) {
        case .request(let request, let deviceName):
            dropAlert = .confirm(
                PendingGroupAddition(
                    request: request,
                    deviceName: deviceName,
                    groupName: target.group.friendlyName
                )
            )
            return true
        case .alreadyMember(let deviceName):
            showFeedback(
                title: "Already a Member",
                message: "\(deviceName) already belongs to \(target.group.friendlyName)."
            )
            return false
        case .rejected(let reason):
            showFeedback(title: "Cannot Add Device", message: reason)
            return false
        }
    }

    private func showFeedback(title: String, message: String) {
        dropAlert = .feedback(DropFeedback(title: title, message: message))
    }

    private struct PendingGroupAddition: Identifiable {
        let id = UUID()
        let request: GroupMemberAddRequest
        let deviceName: String
        let groupName: String
    }

    private struct DropFeedback: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private enum DropAlert: Identifiable {
        case confirm(PendingGroupAddition)
        case feedback(DropFeedback)

        var id: UUID {
            switch self {
            case .confirm(let value): value.id
            case .feedback(let value): value.id
            }
        }
    }
}
