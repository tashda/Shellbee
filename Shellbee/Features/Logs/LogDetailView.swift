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

    private static let stateMetadataKeys: Set<String> = [
        "linkquality", "last_seen", "update", "update_available", "device"
    ]

    private var logTimeState: [String: JSONValue]? {
        if case .mqttPublish(_, _, let payload) = entry.parsedMessageKind {
            return payload.isEmpty ? nil : payload
        }
        if entry.category == .stateChange, let changes = entry.context?.stateChanges {
            var state: [String: JSONValue] = [:]
            for change in changes where !Self.stateMetadataKeys.contains(change.property) {
                state[change.property] = change.to
            }
            return state.isEmpty ? nil : state
        }
        return nil
    }

    var body: some View {
        List {
            metadataSection

            if displayDevices.count == 1, let (_, device) = displayDevices.first {
                singleDeviceSection(device)
            } else if displayDevices.count > 1 {
                LogDetailDevicesSection(devices: displayDevices)
            }

            if viewMode == .beautiful {
                let changes = entry.context?.stateChanges ?? []
                if !changes.isEmpty {
                    LogDetailChangesSection(changes: changes)
                }
                if case .mqttPublish(_, _, let payload) = entry.parsedMessageKind {
                    BeautifulPayloadView(payload: payload, device: displayDevices.first?.device)
                }
            } else {
                jsonSection
            }
        }
        .contentMargins(.top, DesignTokens.Spacing.sm, for: .scrollContent)
        .navigationTitle(entry.category.label)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if entry.category != .stateChange {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewMode = viewMode == .json ? .beautiful : .json
                    } label: {
                        Image(systemName: "curlybraces")
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
                    state: environment.store.state(for: device.friendlyName),
                    isAvailable: environment.store.isAvailable(device.friendlyName),
                    otaStatus: environment.store.otaStatus(for: device.friendlyName)
                )
                NavigationLink(destination: DeviceDetailView(device: device)) { EmptyView() }
                    .opacity(0)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        if let state = logTimeState {
            Section {
                ExposeCardView(device: device, state: state, mode: .snapshot)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var metadataSection: some View {
        Section {
            Label {
                Text(entry.timestamp, format: .dateTime.month(.abbreviated).day().hour().minute().second())
                    .monospacedDigit()
            } icon: {
                Image(systemName: entry.level.systemImage)
                    .foregroundStyle(entry.level.color)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listSectionSeparator(.hidden)
        .listSectionSpacing(.compact)
    }

    private var jsonSection: some View {
        Section("Raw Message") {
            Text(entry.message)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)
                .padding(.vertical, DesignTokens.Spacing.xs)
        }
    }
}

#Preview {
    NavigationStack {
        LogDetailView(entry: LogEntry.previewEntries[3])
            .environment(AppEnvironment())
    }
}
