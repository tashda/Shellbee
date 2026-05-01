import SwiftUI

struct GroupListView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel = GroupListViewModel()
    @State private var groupToRename: Group?
    @State private var groupToRemove: Group?
    @State private var showAddGroup = false

    var body: some View {
        NavigationStack {
            List {
                let groups = viewModel.filteredGroups(store: environment.store)
                ForEach(groups) { group in
                    GroupListRow(
                        group: group,
                        memberDevices: memberDevices(for: group),
                        onRename: { groupToRename = group },
                        onRemove: { groupToRemove = group }
                    )
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Groups")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: Group.self) { group in
                GroupDetailView(group: group)
            }
            .navigationDestination(for: Device.self) { device in
                DeviceDetailView(device: device)
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
                    sortMenu
                }
            }
            .refreshable { await environment.refreshBridgeData() }
            .overlay {
                if environment.store.groups.isEmpty {
                    ContentUnavailableView(
                        "No Groups",
                        systemImage: "rectangle.3.group.fill",
                        description: Text("Create a group to control multiple devices together.")
                    )
                } else if !viewModel.searchText.isEmpty && viewModel.filteredGroups(store: environment.store).isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
        }
        .sheet(isPresented: $showAddGroup) {
            AddGroupSheet { name, id in
                viewModel.addGroup(name: name, id: id, environment: environment)
            }
        }
        .sheet(item: $groupToRename) { group in
            RenameGroupSheet(group: group, memberDevices: memberDevices(for: group)) { newName in
                viewModel.renameGroup(group, to: newName, environment: environment)
            }
        }
        .sheet(item: $groupToRemove) { group in
            RemoveGroupSheet(group: group, memberDevices: memberDevices(for: group)) { force in
                viewModel.removeGroup(group, force: force, environment: environment)
            }
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

    private func memberDevices(for group: Group) -> [Device] {
        let ieees = Set(group.members.map(\.ieeeAddress))
        return environment.store.devices.filter { ieees.contains($0.ieeeAddress) }
    }
}

#Preview {
    GroupListView()
        .environment(AppEnvironment())
}
