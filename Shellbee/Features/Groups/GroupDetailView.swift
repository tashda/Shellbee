import SwiftUI

private enum GroupMenuDestination: Hashable {
    case settings
}

struct GroupDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = GroupDetailViewModel()
    @State private var showAddMembers = false
    @State private var showAddScene = false
    @State private var memberToRemove: GroupMember?
    @State private var menuDestination: GroupMenuDestination?
    let group: Group

    private var currentGroup: Group {
        environment.store.groups.first { $0.id == group.id } ?? group
    }

    private var memberDevices: [Device] {
        currentGroup.members.compactMap { member in
            environment.store.devices.first { $0.ieeeAddress == member.ieeeAddress }
        }
    }

    private var groupState: [String: JSONValue] {
        viewModel.synthesizedState(for: currentGroup, environment: environment)
    }

    private var groupLightContext: LightControlContext? {
        for member in currentGroup.members {
            guard let device = environment.store.devices.first(where: { $0.ieeeAddress == member.ieeeAddress }) else { continue }
            if let ctx = LightControlContext(device: device, state: groupState) { return ctx }
        }
        return nil
    }

    var body: some View {
        List {
            Section {
                GroupCard(group: currentGroup, memberDevices: memberDevices, state: groupState)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if let lightContext = groupLightContext {
                Section {
                    LightControlCard(context: lightContext, mode: .interactive) { payload in
                        environment.sendDeviceState(currentGroup.friendlyName, payload: payload)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            } else if !groupState.isEmpty {
                BeautifulPayloadView(payload: groupState)
            }

            GroupMembersSection(group: currentGroup) { memberToRemove = $0 }

            GroupScenesSection(group: currentGroup, viewModel: viewModel)
        }
        .contentMargins(.top, DesignTokens.Spacing.sm, for: .scrollContent)
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
            case .settings: GroupSettingsView(group: group)
            }
        }
        .sheet(isPresented: $showAddMembers) {
            AddGroupMembersSheet(group: currentGroup) { selections in
                viewModel.addMembers(selections.map { ($0.0, $0.1) }, to: currentGroup, environment: environment)
            }
        }
        .sheet(isPresented: $showAddScene) {
            AddSceneSheet { name in
                viewModel.addScene(name: name, in: currentGroup, environment: environment)
            }
        }
        .alert(
            "Remove from Group",
            isPresented: Binding(get: { memberToRemove != nil }, set: { if !$0 { memberToRemove = nil } })
        ) {
            Button("Remove", role: .destructive) {
                if let member = memberToRemove {
                    viewModel.removeMember(member, from: currentGroup, environment: environment)
                    memberToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) {
                memberToRemove = nil
            }
        } message: {
            if let member = memberToRemove {
                let name = environment.store.devices
                    .first { $0.ieeeAddress == member.ieeeAddress }?.friendlyName ?? member.ieeeAddress
                Text("Remove \(name) from this group?")
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: .previewWithMembers)
            .environment(AppEnvironment())
    }
}
