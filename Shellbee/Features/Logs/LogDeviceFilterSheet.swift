import SwiftUI

/// Picks the devices Activity is filtered to. Devices with activity come
/// first; the rest of the network follows. Choices apply on confirm, so the
/// feed doesn't change underneath the sheet.
struct LogDeviceFilterSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Binding var selectedDevices: Set<String>
    let logDevices: [String]

    var body: some View {
        let items = environment.devicePickerItems()
        let active = Set(logDevices)
        DevicePickerSheet(
            title: "Filter by Device",
            items: items,
            selection: Dictionary(
                items.filter { selectedDevices.contains($0.device.friendlyName) }.map { ($0.id, 0) },
                uniquingKeysWith: { first, _ in first }
            ),
            pinnedIDs: Set(items.filter { active.contains($0.device.friendlyName) }.map(\.id)),
            pinnedTitle: "With activity",
            confirmTitle: "Apply"
        ) { selection in
            selectedDevices = Set(items.filter { selection[$0.id] != nil }.map(\.device.friendlyName))
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true)) {
            LogDeviceFilterSheet(selectedDevices: .constant([]), logDevices: [])
                .environment(AppEnvironment())
        }
}
