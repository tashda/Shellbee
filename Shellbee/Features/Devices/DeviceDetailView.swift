import SwiftUI

private enum DeviceMenuDestination: Hashable {
    case settings, bind, reporting
}

struct DeviceDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device
    @State private var showPairingSheet = false
    @State private var menuDestination: DeviceMenuDestination?
    @State private var pendingDeviceAlert: PendingDeviceAlert?
    @State private var showRemoveSheet = false
    @State private var showRenameSheet = false

    var body: some View {
        let state = environment.store.state(for: device.friendlyName)
        let isAvailable = environment.store.isAvailable(device.friendlyName)
        let otaStatus = environment.store.otaStatus(for: device.friendlyName)

        List {
            Section {
                DeviceCard(
                    device: device,
                    state: state,
                    isAvailable: isAvailable,
                    otaStatus: otaStatus,
                    onRenameTapped: { showRenameSheet = true }
                )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section {
                ExposeCardView(device: device, state: state, mode: .interactive) { payload in
                    environment.sendDeviceState(device.friendlyName, payload: payload)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if let otaStatus, otaStatus.isActive {
                Section("Upgrade Status") {
                    LabeledContent("Phase", value: otaStatus.phase.rawValue.capitalized)
                    if let progress = otaStatus.progress {
                        LabeledContent("Progress") {
                            ProgressView(value: progress, total: 100)
                                .frame(width: 100)
                            Text("\(Int(progress))%")
                        }
                    }
                }
            }

            if device.definition != nil {
                Section("Documentation") {
                    NavigationLink {
                        DeviceDocView(device: device)
                    } label: {
                        Label("Device Documentation", systemImage: "doc.text")
                    }
                    Button {
                        showPairingSheet = true
                    } label: {
                        Label("How to Pair", systemImage: "personalhotspot")
                    }
                }
            }

            Section("Device Info") {
                CopyableRow(label: "Zigbee Model", value: device.modelId ?? "Unknown")
                CopyableRow(label: "IEEE Address", value: device.ieeeAddress)
                CopyableRow(label: "Network Address", value: "\(device.networkAddress)")
                CopyableRow(label: "MQTT Topic", value: "zigbee2mqtt/\(device.friendlyName)")
                if let fw = device.softwareBuildId {
                    CopyableRow(label: "Firmware", value: fw)
                }
            }

            if let description = device.definition?.description, !description.isEmpty {
                Section("About") {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .contentMargins(.top, DesignTokens.Spacing.sm, for: .scrollContent)
        .navigationTitle(device.friendlyName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                deviceConfigMenu
            }
        }
        .navigationDestination(item: $menuDestination) { destination in
            switch destination {
            case .settings:  DeviceSettingsView(device: device)
            case .bind:      DeviceBindView(device: device)
            case .reporting: DeviceReportingView(device: device)
            }
        }
        .sheet(isPresented: $showPairingSheet) {
            DevicePairingSheet(device: device)
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameDeviceSheet(device: device) { newName, updateHA in
                environment.send(topic: Z2MTopics.Request.deviceRename, payload: .object([
                    "from": .string(device.friendlyName),
                    "to": .string(newName),
                    "homeassistant_rename": .bool(updateHA)
                ]))
            }
        }
        .sheet(isPresented: $showRemoveSheet) {
            RemoveDeviceSheet(device: device) { force, block in
                environment.send(topic: Z2MTopics.Request.deviceRemove, payload: .object([
                    "id": .string(device.friendlyName),
                    "force": .bool(force),
                    "block": .bool(block)
                ]))
            }
        }
        .alert(
            pendingDeviceAlert?.title ?? "",
            isPresented: Binding(
                get: { pendingDeviceAlert != nil },
                set: { if !$0 { pendingDeviceAlert = nil } }
            ),
            presenting: pendingDeviceAlert
        ) { alert in
            Button(alert.confirmTitle, role: alert.role) {
                switch alert {
                case .reconfigure(let device):
                    environment.send(topic: Z2MTopics.Request.deviceConfigure, payload: .object(["id": .string(device.friendlyName)]))
                case .interview(let device):
                    environment.send(topic: Z2MTopics.Request.deviceInterview, payload: .object(["id": .string(device.friendlyName)]))
                }
                pendingDeviceAlert = nil
            }
            Button("Cancel", role: .cancel) { pendingDeviceAlert = nil }
        } message: { alert in
            Text(alert.message)
        }
    }

    private var deviceConfigMenu: some View {
        Menu {
            Button { menuDestination = .settings } label: {
                Label("Device Settings", systemImage: "slider.horizontal.3")
            }
            Button { menuDestination = .bind } label: {
                Label("Bind", systemImage: "link")
            }
            Button { menuDestination = .reporting } label: {
                Label("Reporting", systemImage: "waveform")
            }
            Divider()
            Button { pendingDeviceAlert = .interview(device) } label: {
                Label("Interview", systemImage: "questionmark.circle")
            }
            Button { pendingDeviceAlert = .reconfigure(device) } label: {
                Label("Reconfigure", systemImage: "gearshape.fill")
            }
            Divider()
            Button(role: .destructive) { showRemoveSheet = true } label: {
                Label("Remove Device", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }

}

#Preview {
    NavigationStack {
        DeviceDetailView(device: .preview)
            .environment(AppEnvironment())
    }
}
