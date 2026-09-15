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
        // The settings content column is a Settings-style surface in its own
        // right-hand pane. A plain list makes it read like an old table view:
        // full-bleed white rows, no grouping, and no visual relationship to
        // the grouped controls in the detail column.
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
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
            .forceSoftTopScrollEdgeEffect()
        }
        .onChange(of: availableBridgeIDs) { _, ids in
            selection = SettingsWorkspaceRoute.reconciled(selection, availableBridgeIDs: ids)
        }
    }

    private var applicationSection: some View {
        Section("Application") {
            routeRow(.appGeneral, title: "General", systemImage: "gearshape.fill", color: .gray)
            routeRow(.liveActivities, title: "Live Activities", systemImage: "rectangle.inset.filled.and.person.filled", color: .pink)
            routeRow(.notifications, title: "Notifications", systemImage: "bell.badge.fill", color: .red)
            routeRow(.deviceLibrary, title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
            routeRow(.about, title: "About", systemImage: "info.circle.fill", color: Color(.systemGray2))
            if developerModeEnabled {
                routeRow(.developer, title: "Developer", systemImage: "hammer.fill", color: .purple)
            }
        }
    }

    private var bridgesSection: some View {
        Section("Bridges") {
            ForEach(environment.history.connections) { config in
                let session = environment.registry.session(for: config.id)
                NavigationLink(value: SettingsWorkspaceRoute.bridgeOverview(config.id)) {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        FeatureIconTile(
                            symbol: "antenna.radiowaves.left.and.right",
                            tint: .blue,
                            size: DesignTokens.Size.settingsIconFrame
                        )
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            HStack {
                                Text(config.displayName)
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
                }
                .accessibilityValue(selection?.bridgeID == config.id ? "Selected" : "")
            }
        }
    }

    @ViewBuilder
    private func bridgeCategorySections(bridgeID: UUID) -> some View {
        Section("Bridge Configuration") {
            routeRow(.bridgeConnection(bridgeID), title: "Connection", systemImage: "server.rack", color: .blue)
            routeRow(.bridgeGeneral(bridgeID), title: "General", systemImage: "slider.horizontal.3", color: .purple)
            routeRow(.mqtt(bridgeID), title: "MQTT", systemImage: "point.3.connected.trianglepath.dotted", color: .blue)
            routeRow(.adapter(bridgeID), title: "Adapter", systemImage: "cable.connector", color: .brown)
            routeRow(.logOutput(bridgeID), title: "Log Output", systemImage: "doc.text.magnifyingglass", color: Color(.systemGray2))
        }
        Section("Integrations & Features") {
            routeRow(.homeAssistant(bridgeID), title: "Home Assistant", systemImage: "house.fill", color: .orange)
            routeRow(.availability(bridgeID), title: "Availability", systemImage: "antenna.radiowaves.left.and.right", color: .green)
            routeRow(.ota(bridgeID), title: "OTA Updates", systemImage: "arrow.down.circle.fill", color: .indigo)
            routeRow(.health(bridgeID), title: "Health Checks", systemImage: "waveform.path.ecg", color: .pink)
        }
        Section("Network") {
            routeRow(.network(bridgeID), title: "Network & Hardware", systemImage: "network", color: .red)
            routeRow(.deviceFiltering(bridgeID), title: "Device Filtering", systemImage: "lock.shield.fill", color: .cyan)
        }
        Section("Tools") {
            routeRow(.touchlink(bridgeID), title: "Touchlink", systemImage: "dot.radiowaves.left.and.right", color: .teal)
            routeRow(.backup(bridgeID), title: "Backup", systemImage: "arrow.down.doc.fill", color: .indigo)
        }
    }

    private func routeRow(
        _ route: SettingsWorkspaceRoute,
        title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        NavigationLink(value: route) {
            settingsLabel(title: title, systemImage: systemImage, color: color)
        }
        .accessibilityValue(selection == route ? "Selected" : "")
    }

    private func settingsLabel(title: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            FeatureIconTile(
                symbol: systemImage,
                tint: color,
                size: DesignTokens.Size.settingsIconFrame
            )
        }
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
