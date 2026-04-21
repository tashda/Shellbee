import SwiftUI

struct LogDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewMode: ViewMode = .beautiful
    let entry: LogEntry

    enum ViewMode { case beautiful, json }

    private var displayDevices: [(ref: LogContext.DeviceRef, device: Device)] {
        let refs: [LogContext.DeviceRef]
        if let ctx = entry.context, !ctx.devices.isEmpty {
            refs = ctx.devices
        } else {
            let name = entry.deviceName ?? {
                if case .mqttPublish(let d, _, _) = entry.parsedMessageKind { return d }
                return nil
            }()
            refs = name.map { [LogContext.DeviceRef(friendlyName: $0, role: nil)] } ?? []
        }
        return refs.compactMap { ref in
            environment.store.device(named: ref.friendlyName).map { (ref, $0) }
        }
    }

    private var payloadLinkQuality: Int? {
        guard case .mqttPublish(_, _, let payload) = entry.parsedMessageKind else { return nil }
        return payload.linkQuality
    }

    var body: some View {
        List {
            Section {
                LogDetailSummaryBarView(entry: entry, linkQuality: payloadLinkQuality)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            if displayDevices.count == 1, let (_, device) = displayDevices.first {
                singleDeviceSection(device)
            } else if displayDevices.count > 1 {
                LogDetailDevicesSection(devices: displayDevices)
            }

            let changes = entry.context?.stateChanges ?? []
            if !changes.isEmpty {
                LogDetailChangesSection(changes: changes)
            }

            if entry.category != .stateChange {
                if viewMode == .beautiful, case .mqttPublish(_, _, let payload) = entry.parsedMessageKind {
                    BeautifulPayloadView(payload: payload, device: displayDevices.first?.device)
                } else {
                    jsonSection
                }
            }
        }
        .contentMargins(.top, DesignTokens.Spacing.sm, for: .scrollContent)
        .navigationTitle("Log Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if entry.category != .stateChange {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewMode = viewMode == .json ? .beautiful : .json
                    } label: {
                        Image(systemName: viewMode == .json ? "curlybraces.square.fill" : "curlybraces")
                    }
                    .tint(viewMode == .json ? .accentColor : .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func singleDeviceSection(_ device: Device) -> some View {
        Section {
            ZStack {
                DeviceCard(
                    device: device,
                    state: deviceState(for: device),
                    isAvailable: environment.store.isAvailable(device.friendlyName),
                    otaStatus: environment.store.otaStatus(for: device.friendlyName)
                )
                NavigationLink(destination: DeviceDetailView(device: device)) { EmptyView() }
                    .opacity(0)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        Section {
            ExposeCardView(device: device, state: deviceState(for: device), mode: .snapshot)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
    }

    private var jsonSection: some View {
        Section("Raw Message") {
            Text(entry.message)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }

    private func deviceState(for device: Device) -> [String: JSONValue] {
        if case .mqttPublish(_, _, let payload) = entry.parsedMessageKind { return payload }
        return environment.store.state(for: device.friendlyName)
    }
}

#Preview {
    NavigationStack {
        LogDetailView(entry: LogEntry.previewEntries[3])
            .environment(AppEnvironment())
    }
}
