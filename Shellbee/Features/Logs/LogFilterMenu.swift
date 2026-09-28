import SwiftUI

struct LogFilterMenu: View {
    @Bindable var viewModel: LogsViewModel
    @Environment(AppEnvironment.self) private var environment
    /// Opens the device picker. The host presents it, because a sheet
    /// attached inside a toolbar item is torn down whenever the toolbar
    /// rebuilds, such as when a new filter adds the Clear Filters button.
    let onSelectDevices: () -> Void
    private var namespaces: [String] {
        filteredSessions.reduce(into: Set<String>()) { $0.formUnion($1.store.logNamespaces) }.sorted()
    }

    private var connectedSessions: [BridgeSession] {
        environment.registry.orderedSessions.filter(\.isConnected)
    }

    var body: some View {
        Menu {
            if connectedSessions.count >= 2 {
                BridgeFilterMenu(selection: $viewModel.bridgeFilter, sessions: connectedSessions)
            }
            levelMenu
            categoryMenu
            let namespaces = namespaces
            if !namespaces.isEmpty || viewModel.selectedNamespace != nil { namespaceMenu(namespaces) }
            deviceButton
            ActivityDisplayToggles(showsSignalChanges: $viewModel.showLinkQualityChanges)
            ClearFiltersMenuItem(isActive: viewModel.hasActiveFilter) {
                viewModel.clearAllFilters()
            }
        } label: {
            FilterMenuLabel(isActive: viewModel.hasActiveFilter)
        }
    }

    private var levelMenu: some View {
        Menu {
            Picker("Level", selection: $viewModel.selectedLevel) {
                Label("All Levels", systemImage: FilterMenuSymbol.all).tag(LogLevel?.none)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.label, systemImage: level.systemImage).tag(LogLevel?.some(level))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(
                name: "Level",
                systemImage: "exclamationmark.triangle",
                value: viewModel.selectedLevel?.label,
                valueSystemImage: viewModel.selectedLevel?.systemImage
            )
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $viewModel.selectedCategory) {
                Label("All Categories", systemImage: FilterMenuSymbol.all).tag(LogCategory?.none)
                ForEach(LogCategory.allCases, id: \.self) { cat in
                    Label(cat.label, systemImage: cat.systemImage).tag(LogCategory?.some(cat))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(
                name: "Category",
                systemImage: "tag",
                value: viewModel.selectedCategory?.label,
                valueSystemImage: viewModel.selectedCategory?.systemImage
            )
        }
    }

    private func namespaceMenu(_ namespaces: [String]) -> some View {
        Menu {
            Picker("Namespace", selection: $viewModel.selectedNamespace) {
                Label("All Namespaces", systemImage: FilterMenuSymbol.all).tag(String?.none)
                ForEach(namespaces, id: \.self) { ns in
                    Text(ns).tag(String?.some(ns))
                }
            }
            .pickerStyle(.inline)
        } label: {
            FilterSubmenuLabel(name: "Namespace", systemImage: "text.magnifyingglass", value: viewModel.selectedNamespace)
        }
    }

    private var deviceButton: some View {
        Button {
            onSelectDevices()
        } label: {
            FilterSubmenuLabel(name: "Device", systemImage: "cpu", value: selectedDevicesValue)
        }
    }

    private var selectedDevicesValue: String? {
        switch viewModel.selectedDevices.count {
        case 0: nil
        case 1: viewModel.selectedDevices.first
        default: "\(viewModel.selectedDevices.count) selected"
        }
    }

    private var filteredSessions: [BridgeSession] {
        connectedSessions.filter { session in
            viewModel.bridgeFilter.map { $0 == session.bridgeID } ?? true
        }
    }
}

#Preview {
    NavigationStack {
        Text("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LogFilterMenu(viewModel: LogsViewModel(), onSelectDevices: {})
                }
            }
    }
    .configuredTopScrollEdgeEffect()
    .environment(AppEnvironment())
}
