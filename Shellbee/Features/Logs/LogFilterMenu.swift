import SwiftUI

struct LogFilterMenu: View {
    @Bindable var viewModel: LogsViewModel
    @Environment(AppEnvironment.self) private var environment
    @State private var deviceSheetPresented = false
    @State private var namespaceSnapshot: [String] = []

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
            if !namespaceSnapshot.isEmpty { namespaceMenu }
            deviceButton
            Divider()
            // LQI drift is hidden by default — see LogsViewModel.
            // showLinkQualityChanges. The toggle exposes it for diagnostic
            // sessions without polluting the default view.
            Toggle(isOn: $viewModel.showLinkQualityChanges) {
                Label("Show Signal Changes", systemImage: "dot.radiowaves.left.and.right")
            }
            ClearFiltersMenuItem(isActive: viewModel.hasActiveFilter) {
                viewModel.clearAllFilters()
            }
        } label: {
            FilterMenuLabel(isActive: viewModel.hasActiveFilter)
        }
        .simultaneousGesture(TapGesture().onEnded {
            namespaceSnapshot = availableNamespaces()
        })
        .onAppear {
            namespaceSnapshot = availableNamespaces()
        }
        .sheet(isPresented: $deviceSheetPresented) {
            LogDeviceFilterSheet(
                selectedDevices: $viewModel.selectedDevices,
                logDevices: availableDevices()
            )
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

    private var namespaceMenu: some View {
        Menu {
            Picker("Namespace", selection: $viewModel.selectedNamespace) {
                Label("All Namespaces", systemImage: FilterMenuSymbol.all).tag(String?.none)
                ForEach(namespaceSnapshot, id: \.self) { ns in
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
            deviceSheetPresented = true
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

    private func availableNamespaces() -> [String] {
        Set(
            filteredSessions.flatMap { session in
                session.store.logEntries.compactMap(\.namespace)
            }
        ).sorted()
    }

    /// Devices to offer in the picker. Mirrors the activity-log filter
    /// pipeline (minus the device selection itself, which would create a
    /// chicken-and-egg) so the list only contains devices the user can
    /// actually pick *and* see rows for. Without this, picking a device
    /// whose every entry was hidden by the Signal Changes toggle would
    /// leave the user staring at an empty list.
    private func availableDevices() -> [String] {
        let snapshot = LogsViewModel()
        snapshot.searchText = viewModel.searchText
        snapshot.selectedLevel = viewModel.selectedLevel
        snapshot.selectedCategory = viewModel.selectedCategory
        snapshot.selectedNamespace = viewModel.selectedNamespace
        snapshot.entryIDFilter = viewModel.entryIDFilter
        snapshot.bridgeFilter = viewModel.bridgeFilter
        snapshot.showLinkQualityChanges = viewModel.showLinkQualityChanges
        return Set(
            filteredSessions.flatMap { session in
                snapshot.filteredEntries(store: session.store).compactMap {
                    LogRowIconography.subjectName(for: $0, in: session.store) ?? $0.deviceName
                }
            }
        ).sorted()
    }
}

#Preview {
    NavigationStack {
        Text("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LogFilterMenu(
                        viewModel: LogsViewModel()
                    )
                }
            }
    }
    .configuredTopScrollEdgeEffect()
    .environment(AppEnvironment())
}
