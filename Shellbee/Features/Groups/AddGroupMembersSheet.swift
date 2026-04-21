import SwiftUI

struct AddGroupMembersSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let group: Group
    let onConfirm: ([(Device, Int)]) -> Void

    @State private var selectedDevices: [String: Int] = [:]
    @State private var searchText = ""

    private var eligibleDevices: [Device] {
        let memberIEEEs = Set(group.members.map(\.ieeeAddress))
        return environment.store.devices
            .filter { $0.type != .coordinator && !memberIEEEs.contains($0.ieeeAddress) }
            .sorted { $0.friendlyName.localizedCaseInsensitiveCompare($1.friendlyName) == .orderedAscending }
    }

    private var filteredDevices: [Device] {
        guard !searchText.isEmpty else { return eligibleDevices }
        let q = searchText.lowercased()
        return eligibleDevices.filter {
            $0.friendlyName.lowercased().contains(q)
            || $0.definition?.vendor.lowercased().contains(q) == true
            || $0.definition?.model.lowercased().contains(q) == true
        }
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if eligibleDevices.isEmpty {
                    ContentUnavailableView(
                        "No Devices Available",
                        systemImage: "cpu",
                        description: Text("All devices are already in this group.")
                    )
                } else {
                    deviceList
                }
            }
            .navigationTitle("Add Devices")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let selections = selectedDevices.compactMap { ieee, endpoint -> (Device, Int)? in
                            guard let device = environment.store.devices.first(where: { $0.ieeeAddress == ieee }) else { return nil }
                            return (device, endpoint)
                        }
                        onConfirm(selections)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedDevices.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var deviceList: some View {
        List {
            ForEach(filteredDevices) { device in
                AddGroupMemberDeviceRow(
                    device: device,
                    isSelected: selectedDevices[device.ieeeAddress] != nil,
                    selectedEndpoint: selectedDevices[device.ieeeAddress] ?? device.availableEndpoints[0],
                    onTap: { toggleSelection(device) },
                    onEndpointChange: { selectedDevices[device.ieeeAddress] = $0 }
                )
            }
        }
        .listStyle(.plain)
        .overlay {
            if !searchText.isEmpty && filteredDevices.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func toggleSelection(_ device: Device) {
        if selectedDevices[device.ieeeAddress] != nil {
            selectedDevices.removeValue(forKey: device.ieeeAddress)
        } else {
            selectedDevices[device.ieeeAddress] = device.availableEndpoints[0]
        }
    }
}

#Preview {
    AddGroupMembersSheet(group: .preview) { _ in }
        .environment(AppEnvironment())
}
