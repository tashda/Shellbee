import SwiftUI

struct SettingsWorkspaceList: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled = false
    @Binding var selection: SettingsWorkspaceRoute?
    @State private var editorViewModel: ConnectionViewModel?

    private var activeBridgeID: UUID? {
        selection?.bridgeID
            ?? environment.registry.primaryBridgeID
            ?? environment.history.connections.first?.id
    }

    var body: some View {
        List(selection: $selection) {
            applicationSection
            bridgesSection
            if let activeBridgeID {
                bridgeCategorySections(bridgeID: activeBridgeID)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let viewModel = ConnectionViewModel(environment: environment)
                    viewModel.presentNewServer()
                    editorViewModel = viewModel
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Bridge")
            }
        }
        .sheet(item: editorBinding) { viewModel in
            NavigationStack {
                ConnectionEditorView(viewModel: viewModel, mode: .save)
            }
        }
        .onChange(of: availableBridgeIDs) { _, ids in
            selection = SettingsWorkspaceRoute.reconciled(selection, availableBridgeIDs: ids)
        }
    }

    private var applicationSection: some View {
        Section("Application") {
            routeRow(.appGeneral, title: "General", systemImage: "gearshape.fill")
            routeRow(.liveActivities, title: "Live Activities", systemImage: "rectangle.inset.filled.and.person.filled")
            routeRow(.notifications, title: "Notifications", systemImage: "bell.badge.fill")
            routeRow(.deviceLibrary, title: "Device Library", systemImage: "books.vertical.fill")
            routeRow(.about, title: "About", systemImage: "info.circle.fill")
            if developerModeEnabled {
                routeRow(.developer, title: "Developer", systemImage: "hammer.fill")
            }
        }
    }

    private var bridgesSection: some View {
        Section("Bridges") {
            ForEach(environment.history.connections) { config in
                let session = environment.registry.session(for: config.id)
                NavigationLink(value: SettingsWorkspaceRoute.bridgeOverview(config.id)) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                        HStack {
                            Label(config.displayName, systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if session?.store.bridgeInfo?.restartRequired == true {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Restart required")
                            }
                        }
                        Text(statusLabel(for: session, config: config))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityValue(selection?.bridgeID == config.id ? "Selected" : "")
            }
        }
    }

    @ViewBuilder
    private func bridgeCategorySections(bridgeID: UUID) -> some View {
        Section("Bridge Configuration") {
            routeRow(.bridgeConnection(bridgeID), title: "Connection", systemImage: "server.rack")
            routeRow(.bridgeGeneral(bridgeID), title: "General", systemImage: "slider.horizontal.3")
            routeRow(.mqtt(bridgeID), title: "MQTT", systemImage: "point.3.connected.trianglepath.dotted")
            routeRow(.adapter(bridgeID), title: "Adapter", systemImage: "cable.connector")
            routeRow(.logOutput(bridgeID), title: "Log Output", systemImage: "doc.text.magnifyingglass")
        }
        Section("Integrations & Features") {
            routeRow(.homeAssistant(bridgeID), title: "Home Assistant", systemImage: "house.fill")
            routeRow(.availability(bridgeID), title: "Availability", systemImage: "antenna.radiowaves.left.and.right")
            routeRow(.ota(bridgeID), title: "OTA Updates", systemImage: "arrow.down.circle.fill")
            routeRow(.health(bridgeID), title: "Health Checks", systemImage: "waveform.path.ecg")
        }
        Section("Network") {
            routeRow(.network(bridgeID), title: "Network & Hardware", systemImage: "network")
            routeRow(.deviceFiltering(bridgeID), title: "Device Filtering", systemImage: "lock.shield.fill")
        }
        Section("Tools") {
            routeRow(.touchlink(bridgeID), title: "Touchlink", systemImage: "dot.radiowaves.left.and.right")
            routeRow(.backup(bridgeID), title: "Backup", systemImage: "arrow.down.doc.fill")
        }
    }

    private func routeRow(
        _ route: SettingsWorkspaceRoute,
        title: String,
        systemImage: String
    ) -> some View {
        NavigationLink(value: route) {
            Label(title, systemImage: systemImage)
        }
        .accessibilityValue(selection == route ? "Selected" : "")
    }

    private var availableBridgeIDs: Set<UUID> {
        Set(environment.history.connections.map(\.id))
    }

    private func statusLabel(for session: BridgeSession?, config: ConnectionConfig) -> String {
        switch session?.connectionState {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .reconnecting(let attempt): "Reconnecting (attempt \(attempt))"
        case .failed(let message): message
        case .lost(let message): "Lost: \(message)"
        default: config.displayURL
        }
    }

    private var editorBinding: Binding<ConnectionViewModel?> {
        Binding(
            get: { editorViewModel?.isEditorPresented == true ? editorViewModel : nil },
            set: { if $0 == nil { editorViewModel = nil } }
        )
    }
}
