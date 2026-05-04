import SwiftUI

struct GroupListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = GroupListViewModel()
    @State private var groupToRename: BridgeBoundGroup?
    @State private var groupToRemove: BridgeBoundGroup?
    @State private var showAddGroup = false

    private var isMergedMode: Bool {
        environment.registry.sessions.values.filter(\.isConnected).count >= 2
    }

    private var singleBridgeID: UUID? {
        environment.registry.orderedSessions.first(where: \.isConnected)?.bridgeID
    }

    var body: some View {
        NavigationStack {
            List {
                if isMergedMode {
                    let merged = mergedFilteredGroups()
                    ForEach(merged) { item in
                        // Bridge attribution lives on the row's leading-bar
                        // background (handled inside `GroupListRow`), so the
                        // merged path no longer wraps in an HStack with a
                        // separate dot — the bar is the uniform multi-bridge
                        // indicator across Devices, Groups, and Logs.
                        GroupListRow(
                            group: item.group,
                            memberDevices: mergedMembers(for: item),
                            bridgeID: item.bridgeID,
                            onRename: { groupToRename = item },
                            onRemove: { groupToRemove = item }
                        )
                    }
                } else if let bridgeID = singleBridgeID,
                          let session = environment.registry.session(for: bridgeID) {
                    let groups = viewModel.filteredGroups(store: session.store)
                    ForEach(groups) { group in
                        GroupListRow(
                            group: group,
                            memberDevices: memberDevices(for: group, store: session.store),
                            bridgeID: bridgeID,
                            onRename: { groupToRename = BridgeBoundGroup(bridgeID: bridgeID, bridgeName: session.displayName, group: group) },
                            onRemove: { groupToRemove = BridgeBoundGroup(bridgeID: bridgeID, bridgeName: session.displayName, group: group) }
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: GroupRoute.self) { route in
                GroupDetailView(bridgeID: route.bridgeID, group: route.group)
            }
            .navigationDestination(for: DeviceRoute.self) { route in
                DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .minimizeSearchToolbarIfAvailable()
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showAddGroup = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Group")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if isMergedMode {
                        bridgeFilterMenu
                    }
                    sortMenu
                }
            }
            .refreshable {
                if let id = singleBridgeID ?? environment.registry.primaryBridgeID {
                    await environment.refreshBridgeData(bridgeID: id)
                }
            }
            .overlay {
                let totalGroups = environment.allGroups.count
                if totalGroups == 0 {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "rectangle.3.group.fill",
                        description: Text("Create a group to control multiple devices together.")
                    )
                } else if !viewModel.searchText.isEmpty && (isMergedMode ? mergedFilteredGroups().isEmpty : (singleBridgeID.flatMap { environment.registry.session(for: $0) }.map { viewModel.filteredGroups(store: $0.store).isEmpty } ?? true)) {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
        }
        .sheet(isPresented: $showAddGroup) {
            AddGroupSheet { name, id, bridgeID in
                viewModel.addGroup(name: name, id: id, environment: environment, bridgeID: bridgeID)
            }
            .environment(environment)
        }
        .sheet(item: $groupToRename) { bound in
            RenameGroupSheet(group: bound.group, memberDevices: mergedMembers(for: bound)) { newName in
                viewModel.renameGroup(bound.group, to: newName, environment: environment, bridgeID: bound.bridgeID)
            }
        }
        .sheet(item: $groupToRemove) { bound in
            RemoveGroupSheet(group: bound.group, memberDevices: mergedMembers(for: bound)) { force in
                viewModel.removeGroup(bound.group, force: force, environment: environment, bridgeID: bound.bridgeID)
            }
        }
    }

    private var bridgeFilterMenu: some View {
        let connected = environment.registry.orderedSessions.filter(\.isConnected)
        return Menu {
            Picker("Bridge", selection: $viewModel.bridgeFilter) {
                Label("All Bridges", systemImage: "antenna.radiowaves.left.and.right")
                    .tag(UUID?.none)
                ForEach(connected, id: \.bridgeID) { session in
                    Text(session.displayName).tag(UUID?.some(session.bridgeID))
                }
            }
            .pickerStyle(.inline)
            if viewModel.bridgeFilter != nil {
                Divider()
                Button(role: .destructive) {
                    viewModel.bridgeFilter = nil
                } label: {
                    Label("Clear Filter", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .symbolVariant(viewModel.bridgeFilter != nil ? .fill : .none)
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $viewModel.sortOrder) {
                ForEach(GroupSortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button {
                viewModel.sortAscending.toggle()
            } label: {
                Label(
                    viewModel.sortAscending ? "Ascending" : "Descending",
                    systemImage: viewModel.sortAscending ? "arrow.up" : "arrow.down"
                )
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private func memberDevices(for group: Group, store: AppStore) -> [Device] {
        let ieees = Set(group.members.map(\.ieeeAddress))
        return store.devices.filter { ieees.contains($0.ieeeAddress) }
    }

    private func mergedMembers(for item: BridgeBoundGroup) -> [Device] {
        let session = environment.registry.session(for: item.bridgeID)
        let ieees = Set(item.group.members.map(\.ieeeAddress))
        return session?.store.devices.filter { ieees.contains($0.ieeeAddress) } ?? []
    }

    private func mergedFilteredGroups() -> [BridgeBoundGroup] {
        let q = viewModel.searchText.lowercased()
        let sessions = environment.registry.orderedSessions.filter { session in
            viewModel.bridgeFilter.map { $0 == session.bridgeID } ?? true
        }
        return sessions
            .flatMap { session -> [BridgeBoundGroup] in
                let groups = q.isEmpty
                    ? session.store.groups
                    : session.store.groups.filter { $0.friendlyName.lowercased().contains(q) }
                return groups.map { BridgeBoundGroup(bridgeID: session.bridgeID, bridgeName: session.displayName, group: $0) }
            }
            .sorted { $0.group.friendlyName.localizedCompare($1.group.friendlyName) == .orderedAscending }
    }
}

#Preview {
    GroupListView()
        .environment(AppEnvironment())
}
