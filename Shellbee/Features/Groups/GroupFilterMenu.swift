import SwiftUI

/// The Groups filter menu: Bridge (two or more connected), State, Member
/// Type and Scenes, then Empty Groups, with counts that honour the other
/// filters. Follows the layout in `FilterMenuComponents`.
struct GroupFilterMenu: View {
    @Bindable var viewModel: GroupListViewModel

    @Environment(AppEnvironment.self) private var environment

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    /// Stores in the bridge filter, each with its groups.
    private var scoped: [(store: AppStore, group: Group)] {
        connectedSessions
            .filter { session in viewModel.bridgeFilter.map { $0 == session.bridgeID } ?? true }
            .flatMap { session in session.store.groups.map { (session.store, $0) } }
    }

    var body: some View {
        Menu {
            if connectedSessions.count >= 2 {
                BridgeFilterMenu(selection: $viewModel.bridgeFilter, sessions: connectedSessions)
            }
            stateMenu
            memberTypeMenu
            scenesMenu
            Section {
                Toggle(isOn: $viewModel.emptyOnly) {
                    Label("Empty Groups (\(count(ignoring: \.emptyOnly) { $0.group.members.isEmpty }))",
                          systemImage: "square.dashed")
                }
            }
            ClearFiltersMenuItem(isActive: viewModel.hasActiveFilter) { viewModel.clearFilters() }
        } label: {
            FilterMenuLabel(isActive: viewModel.hasActiveFilter)
        }
    }

    private var stateMenu: some View {
        Menu {
            Picker("State", selection: $viewModel.stateFilter) {
                Label("All States", systemImage: FilterMenuSymbol.all).tag(GroupStateFilter?.none)
                ForEach(GroupStateFilter.allCases, id: \.self) { state in
                    let n = count(ignoring: \.stateFilter) { GroupListViewModel.state(of: $0.group, store: $0.store) == state }
                    Label("\(state.rawValue) (\(n))", systemImage: state.systemImage).tag(GroupStateFilter?.some(state))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(name: "State", systemImage: "power", value: viewModel.stateFilter?.rawValue,
                               valueSystemImage: viewModel.stateFilter?.systemImage)
        }
    }

    @ViewBuilder
    private var memberTypeMenu: some View {
        let categories = Device.Category.allCases.filter { category in
            category == viewModel.memberCategory
                || scoped.contains { GroupListViewModel.memberCategories(of: $0.group, store: $0.store).contains(category) }
        }
        if !categories.isEmpty {
            Menu {
                Picker("Member Type", selection: $viewModel.memberCategory) {
                    Label("All Types", systemImage: FilterMenuSymbol.all).tag(Device.Category?.none)
                    ForEach(categories, id: \.self) { category in
                        let n = count(ignoring: \.memberCategory) {
                            GroupListViewModel.memberCategories(of: $0.group, store: $0.store).contains(category)
                        }
                        Label("\(category.label) (\(n))", systemImage: category.systemImage)
                            .tag(Device.Category?.some(category))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                FilterSubmenuLabel(name: "Member Type", systemImage: "tag", value: viewModel.memberCategory?.label,
                                   valueSystemImage: viewModel.memberCategory?.systemImage)
            }
        }
    }

    private var scenesMenu: some View {
        Menu {
            Picker("Scenes", selection: $viewModel.sceneFilter) {
                Label("All Groups", systemImage: FilterMenuSymbol.all).tag(GroupSceneFilter?.none)
                ForEach(GroupSceneFilter.allCases, id: \.self) { filter in
                    let n = count(ignoring: \.sceneFilter) { ($0.group.scenes.isEmpty) == (filter == .withoutScenes) }
                    Label("\(filter.rawValue) (\(n))", systemImage: filter.systemImage).tag(GroupSceneFilter?.some(filter))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(name: "Scenes", systemImage: "sparkles", value: viewModel.sceneFilter?.rawValue,
                               valueSystemImage: viewModel.sceneFilter?.systemImage)
        }
    }

    /// Groups matching `predicate` and every other active filter.
    private func count(
        ignoring filter: PartialKeyPath<GroupListViewModel>,
        where predicate: ((store: AppStore, group: Group)) -> Bool
    ) -> Int {
        scoped.filter { viewModel.matchesFilters($0.group, store: $0.store, ignoring: filter) && predicate($0) }.count
    }
}
