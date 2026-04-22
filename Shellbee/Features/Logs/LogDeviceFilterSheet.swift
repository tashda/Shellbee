import SwiftUI

struct LogDeviceFilterSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDevices: Set<String>
    let logDevices: [String]

    @State private var showAll = false
    @State private var searchText = ""

    private var candidates: [Device] {
        let base: [Device]
        if showAll {
            base = environment.store.devices
        } else {
            base = logDevices.compactMap { environment.store.device(named: $0) }
        }
        let sorted = base.sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
        guard !searchText.isEmpty else { return sorted }
        let q = searchText.lowercased()
        return sorted.filter {
            $0.friendlyName.lowercased().contains(q)
                || $0.definition?.vendor.lowercased().contains(q) == true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Show All Devices", isOn: $showAll)
                }
                Section {
                    ForEach(candidates) { device in
                        Button {
                            let name = device.friendlyName
                            if selectedDevices.contains(name) {
                                selectedDevices.remove(name)
                            } else {
                                selectedDevices.insert(name)
                            }
                        } label: {
                            HStack {
                                DevicePickerRow(device: device)
                                if selectedDevices.contains(device.friendlyName) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                        .font(.body.weight(.semibold))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $searchText, prompt: "Search devices")
            .overlay {
                if !searchText.isEmpty && candidates.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .navigationTitle("Filter by Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !selectedDevices.isEmpty {
                        Button("Clear") { selectedDevices.removeAll() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            LogDeviceFilterSheet(
                selectedDevices: .constant([]),
                logDevices: []
            )
            .environment(AppEnvironment())
        }
}
