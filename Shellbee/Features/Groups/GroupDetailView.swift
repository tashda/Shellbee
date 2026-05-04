import SwiftUI

private enum GroupMenuDestination: Hashable {
    case settings
}

struct GroupDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = GroupDetailViewModel()
    @State private var showAddMembers = false
    @State private var showAddScene = false
    @State private var showRenameSheet = false
    @State private var memberToRemove: GroupMember?
    @State private var menuDestination: GroupMenuDestination?
    /// Phase 1 multi-bridge: bridge that owns this group. Pushed in via
    /// `GroupRoute` so reads/writes stay scoped to the right Z2M instance.
    /// Group ids are scoped per-instance, not globally unique — the route
    /// is the only reliable way to disambiguate.
    let bridgeID: UUID
    let group: Group

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var currentGroup: Group {
        scope.store.groups.first { $0.id == group.id } ?? group
    }

    private var memberDevices: [Device] {
        currentGroup.members.compactMap { member in
            scope.store.devices.first { $0.ieeeAddress == member.ieeeAddress }
        }
    }

    private var groupState: [String: JSONValue] {
        viewModel.synthesizedState(for: currentGroup, environment: environment, bridgeID: bridgeID)
    }

    private static let recentLogLimit = 5

    @ViewBuilder
    private var logsSection: some View {
        let groupEntries = scope.store.logEntries.filter { $0.deviceName == currentGroup.friendlyName }
        let recent = Array(groupEntries.prefix(Self.recentLogLimit))

        Section("Logs") {
            if groupEntries.isEmpty {
                Text("No logs for this group yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recent) { entry in
                    NavigationLink {
                        LogDetailView(bridgeID: bridgeID, entry: entry)
                    } label: {
                        LogRowView(entry: entry, store: scope.store, bridgeID: bridgeID)
                    }
                    .listRowBackground(BridgeRowLeadingBar(bridgeID: bridgeID))
                }
                NavigationLink {
                    GroupLogsView(bridgeID: bridgeID, group: currentGroup)
                } label: {
                    Label("See All Logs", systemImage: "list.bullet")
                }
            }
        }
    }

    private var groupLightContext: LightControlContext? {
        for member in currentGroup.members {
            guard let device = scope.store.devices.first(where: { $0.ieeeAddress == member.ieeeAddress }) else { continue }
            if let ctx = LightControlContext(device: device, state: groupState) { return ctx }
        }
        return nil
    }

    var body: some View {
        List {
            GroupCard(
                group: currentGroup,
                memberDevices: memberDevices,
                state: groupState,
                bridgeID: bridgeID,
                bridgeName: environment.registry.session(for: bridgeID)?.displayName,
                onRenameTapped: { showRenameSheet = true }
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let lightContext = groupLightContext {
                Section {
                    LightControlCard(context: lightContext, mode: .interactive) { payload in
                        scope.send(topic: Z2MTopics.deviceSet(currentGroup.friendlyName), payload: payload)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } else if !groupState.isEmpty {
                BeautifulPayloadView(payload: groupState)
            }

            GroupMembersSection(
                bridgeID: bridgeID,
                group: currentGroup,
                onRemove: { memberToRemove = $0 },
                onAdd: { showAddMembers = true }
            )

            GroupScenesSection(bridgeID: bridgeID, group: currentGroup, viewModel: viewModel)

            logsSection
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .toolbarBackground(.automatic, for: .navigationBar)
        .navigationTitle(currentGroup.friendlyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { menuDestination = .settings } label: {
                        Label("Group Settings", systemImage: "slider.horizontal.3")
                    }
                    Divider()
                    Button {
                        showAddMembers = true
                    } label: {
                        Label("Add Member", systemImage: "person.badge.plus")
                    }
                    Button {
                        showAddScene = true
                    } label: {
                        Label("Save Scene", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuIndicator(.hidden)
                .accessibilityLabel("Group Actions")
            }
        }
        .navigationDestination(item: $menuDestination) { destination in
            switch destination {
            case .settings: GroupSettingsView(bridgeID: bridgeID, group: group)
            }
        }
        .sheet(isPresented: $showAddMembers) {
            AddGroupMembersSheet(bridgeID: bridgeID, group: currentGroup) { selections in
                viewModel.addMembers(selections.map { ($0.0, $0.1) }, to: currentGroup, environment: environment, bridgeID: bridgeID)
            }
        }
        .sheet(isPresented: $showAddScene) {
            AddSceneSheet { name in
                viewModel.addScene(name: name, in: currentGroup, environment: environment, bridgeID: bridgeID)
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameGroupSheet(group: currentGroup, memberDevices: memberDevices) { newName in
                scope.send(topic: Z2MTopics.Request.groupRename, payload: .object([
                    "from": .string(currentGroup.friendlyName),
                    "to": .string(newName)
                ]))
                Haptics.impact(.medium)
            }
        }
        .alert(
            "Remove from Group",
            isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } })
        ) {
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    viewModel.removeMember(member, from: currentGroup, environment: environment, bridgeID: bridgeID)
                    memberToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
        } message: {
            if let member = memberToRemove {
                let name = scope.store.devices
                    .first { $0.ieeeAddress == member.ieeeAddress }?.friendlyName ?? member.ieeeAddress
                Text("Remove \(name) from this group?")
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(bridgeID: UUID(), group: .previewWithMembers)
            .environment(AppEnvironment())
    }
}
