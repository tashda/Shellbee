import SwiftUI

struct LogFilterMenu: View {
    @Bindable var viewModel: LogsViewModel
    let store: AppStore
    @State private var deviceSheetPresented = false
    @State private var namespaceSnapshot: [String] = []

    var body: some View {
        Menu {
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
            namespaceSnapshot = viewModel.availableNamespaces(store: store)
        })
        .onAppear {
            namespaceSnapshot = viewModel.availableNamespaces(store: store)
        }
        .sheet(isPresented: $deviceSheetPresented) {
            LogDeviceFilterSheet(
                selectedDevices: $viewModel.selectedDevices,
                logDevices: viewModel.availableDevices(store: store)
            )
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
                Label("Device\u{2026}", systemImage: "cpu")
            case 1:
                Label(viewModel.selectedDevices.first!, systemImage: "cpu.fill")
            default:
                Label("\(viewModel.selectedDevices.count) Devices", systemImage: "cpu.fill")
            }
        }
    }
}

#Preview {
    NavigationStack {
        Text("Logs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    LogFilterMenu(
                        viewModel: LogsViewModel(),
                        store: { let s = AppStore(); s.logEntries = LogEntry.previewEntries; return s }()
                    )
                }
            }
    }
    .environment(AppEnvironment())
}
