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
                bridgeMenu
            }
            levelMenu
            categoryMenu
            if !namespaceSnapshot.isEmpty { namespaceMenu }
            deviceButton
            if viewModel.hasActiveFilter {
                Divider()
                Button(role: .destructive) {
                    viewModel.clearAllFilters()
                } label: {
                    Label("Clear Filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                .symbolVariant(viewModel.hasActiveFilter ? .fill : .none)
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

    private var bridgeMenu: some View {
        Menu {
            Picker("Bridge", selection: $viewModel.bridgeFilter) {
                Label("All Bridges", systemImage: "antenna.radiowaves.left.and.right")
                    .tag(UUID?.none)
                ForEach(connectedSessions, id: \.bridgeID) { session in
                    Text(session.displayName).tag(UUID?.some(session.bridgeID))
                }
            }
            .pickerStyle(.inline)
        } label: {
            if let id = viewModel.bridgeFilter,
               let session = connectedSessions.first(where: { $0.bridgeID == id }) {
                Label("Bridge: \(session.displayName)", systemImage: "antenna.radiowaves.left.and.right")
            } else {
                Label("Bridge", systemImage: "antenna.radiowaves.left.and.right")
            }
        }
    }

    private var levelMenu: some View {
        Menu {
            Picker("Level", selection: $viewModel.selectedLevel) {
                Label("All Levels", systemImage: "square.grid.2x2").tag(LogLevel?.none)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Label(level.label, systemImage: level.systemImage).tag(LogLevel?.some(level))
                }
            }
            .pickerStyle(.inline)
        } label: {
            if let level = viewModel.selectedLevel {
                Label("Level: \(level.label)", systemImage: level.systemImage)
            } else {
                Label("Level", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private var categoryMenu: some View {
        Menu {
            Picker("Category", selection: $viewModel.selectedCategory) {
                Label("All Categories", systemImage: "square.grid.2x2").tag(LogCategory?.none)
                ForEach(LogCategory.allCases, id: \.self) { cat in
                    Label(cat.label, systemImage: cat.systemImage).tag(LogCategory?.some(cat))
                }
            }
            .pickerStyle(.inline)
        } label: {
            if let cat = viewModel.selectedCategory {
                Label("Category: \(cat.label)", systemImage: cat.systemImage)
            } else {
                Label("Category", systemImage: "tag")
            }
        }
    }

    private var namespaceMenu: some View {
        Menu {
            Picker("Namespace", selection: $viewModel.selectedNamespace) {
                Label("All Namespaces", systemImage: "square.grid.2x2").tag(String?.none)
                ForEach(namespaceSnapshot, id: \.self) { ns in
                    Text(ns).tag(String?.some(ns))
                }
            }
            .pickerStyle(.inline)
        } label: {
            if let ns = viewModel.selectedNamespace {
                Label(ns, systemImage: "text.magnifyingglass")
            } else {
                Label("Namespace", systemImage: "text.magnifyingglass")
            }
        }
    }

    private var deviceButton: some View {
        Button {
            deviceSheetPresented = true
        } label: {
            switch viewModel.selectedDevices.count {
            case 0:
                Label("Device", systemImage: "cpu")
            case 1:
                Label(viewModel.selectedDevices.first!, systemImage: "cpu.fill")
            default:
                Label("\(viewModel.selectedDevices.count) Devices", systemImage: "cpu.fill")
            }
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

    private func availableDevices() -> [String] {
        Set(
            filteredSessions.flatMap { session in
                session.store.logEntries.compactMap(\.deviceName)
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
    .environment(AppEnvironment())
}
