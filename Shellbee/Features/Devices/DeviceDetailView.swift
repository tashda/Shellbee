import SwiftUI

private enum DeviceMenuDestination: Hashable {
    case settings, bind, reporting
}

struct DeviceDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let device: Device
    @State private var showPairingSheet = false
    @State private var menuDestination: DeviceMenuDestination?

    var body: some View {
        let state = environment.store.state(for: device.friendlyName)
        let isAvailable = environment.store.isAvailable(device.friendlyName)
        let otaStatus = environment.store.otaStatus(for: device.friendlyName)

        List {
            Section {
                DeviceCard(device: device, state: state, isAvailable: isAvailable, otaStatus: otaStatus)
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
                LabeledContent("Zigbee Model", value: device.modelId ?? "Unknown")
                LabeledContent("IEEE Address", value: device.ieeeAddress)
                LabeledContent("Network Address", value: "\(device.networkAddress)")
                LabeledContent("MQTT Topic", value: "zigbee2mqtt/\(device.friendlyName)")
                if let fw = device.softwareBuildId {
                    LabeledContent("Firmware", value: fw)
                }
            }

            Section("Activity") {
                Button {
                    environment.selectedTab = .settings
                } label: {
                    Label("View Recent Activity", systemImage: "clock.arrow.circlepath")
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
