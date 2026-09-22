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
    /// The hero shows the name; the navigation title appears once it scrolls away.
    @State private var isNameHidden = false
    @State private var memberToRemove: GroupMember?
    @State private var menuDestination: GroupMenuDestination?
    /// Phase 1 multi-bridge: bridge that owns this group. Pushed in via
    /// `GroupRoute` so reads/writes stay scoped to the right Z2M instance.
    /// Group ids are scoped per-instance, not globally unique — the route
    /// is the only reliable way to disambiguate.
    let bridgeID: UUID
    let group: Group
    private let memberSelection: Binding<DeviceRoute?>?

    init(
        bridgeID: UUID,
        group: Group,
        memberSelection: Binding<DeviceRoute?>? = nil
    ) {
        self.bridgeID = bridgeID
        self.group = group
        self.memberSelection = memberSelection
    }

    private var scope: BridgeScope { environment.scope(for: bridgeID) }

    private var currentGroup: Group {
        scope.store.groups.first { $0.id == group.id } ?? group
    }

    private var memberDevices: [Device] {
        currentGroup.members.compactMap { member in
            scope.store.devices.first { $0.ieeeAddress == member.ieeeAddress }
        }
    }

    /// Members reporting ON, or nil when no member reports a state.
    private var membersOnCount: Int? {
        let states = memberDevices.compactMap { scope.store.state(for: $0.friendlyName)["state"]?.stringValue }
        guard !states.isEmpty else { return nil }
        return states.filter { $0.uppercased() == "ON" }.count
    }

    private var groupState: [String: JSONValue] {
        viewModel.synthesizedState(for: currentGroup, environment: environment, bridgeID: bridgeID)
    }

    @ViewBuilder
    private var logsSection: some View {
        ActivitySubjectLogsSection(
            bridgeID: bridgeID,
            subjectName: currentGroup.friendlyName,
            subjectLabel: "group"
        ) {
            GroupLogsView(bridgeID: bridgeID, group: currentGroup)
        }
    }

    private var groupLightContext: LightControlContext? {
        for member in currentGroup.members {
            guard let device = scope.store.devices.first(where: { $0.ieeeAddress == member.ieeeAddress }) else { continue }
            if let ctx = LightControlContext(device: device, state: groupState) { return ctx }
        }
        return nil
    }

    /// A control card is only offered when every member shares the same
    /// category — a mixed group falls back to read-only rows, since there's
    /// no one control that speaks for the whole group.
    private var isUniformCategory: Device.Category? {
        let categories = Set(memberDevices.map(\.category))
        return categories.count == 1 ? categories.first : nil
    }

    private var groupSwitchContext: SwitchControlContext? {
        guard isUniformCategory == .switchPlug, let device = memberDevices.first else { return nil }
        return SwitchControlContext.contexts(for: device, state: groupState).first
    }

    private var groupCoverContext: CoverControlContext? {
        guard isUniformCategory == .cover, let device = memberDevices.first else { return nil }
        return CoverControlContext.contexts(for: device, state: groupState).first
    }

    var body: some View {
        List {
            GroupCard(
                group: currentGroup,
                memberDevices: memberDevices,
                state: groupState,
                bridgeID: bridgeID,
                bridgeName: environment.attributionBridgeName(for: bridgeID),
                membersOnCount: membersOnCount,
                onRenameTapped: { showRenameSheet = true },
                onNameHiddenChange: { isNameHidden = $0 }
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
            } else if let switchContext = groupSwitchContext {
                Section {
                    SwitchControlCard(context: switchContext, mode: .interactive) { payload in
                        scope.send(topic: Z2MTopics.deviceSet(currentGroup.friendlyName), payload: payload)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } else if let coverContext = groupCoverContext {
                Section {
                    CoverControlCard(context: coverContext, mode: .interactive) { payload in
                        scope.send(topic: Z2MTopics.deviceSet(currentGroup.friendlyName), payload: payload)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                if let device = memberDevices.first {
                    FeatureSectionsList(
                        exposes: CoverFeatureSections.tiltExposes(for: device),
                        state: groupState
                    ) { payload in
                        scope.send(topic: Z2MTopics.deviceSet(currentGroup.friendlyName), payload: payload)
                    }
                }
            } else if !groupState.isEmpty {
                PayloadSectionsView(payload: groupState)
            }

            GroupMembersSection(
                bridgeID: bridgeID,
                group: currentGroup,
                selection: memberSelection,
                onRemove: { memberToRemove = $0 },
                onAdd: { showAddMembers = true }
            )

            GroupScenesSection(bridgeID: bridgeID, group: currentGroup, viewModel: viewModel)

            logsSection
        }
        .contentMargins(.top, 0, for: .scrollContent)
        .listSectionSpacing(DesignTokens.Spacing.lg)
        .toolbarBackground(.automatic, for: .navigationBar)
        .navigationTitle(isNameHidden ? currentGroup.friendlyName : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    OpenInNewWindowButton(destination: .group(
                        bridgeID: bridgeID,
                        groupID: currentGroup.id
                    ))
                    Divider()
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
    .configuredTopScrollEdgeEffect()
}
