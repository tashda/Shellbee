import SwiftUI

struct SettingsWorkspaceList: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled = false
    @AppStorage(BridgeColorObserver.revisionKey) private var bridgeColorRevision: Int = 0
    @Binding var selection: SettingsWorkspaceRoute?
    @State private var editorViewModel: ConnectionViewModel?

    var body: some View {
        // Keep visible bridge tiles in sync after the color picker saves a
        // change, including when this list stays mounted in a split view.
        let _ = bridgeColorRevision

        List(selection: $selection) {
            bridgesSection
            applicationSection
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
            .configuredTopScrollEdgeEffect()
        }
        .onChange(of: availableBridgeIDs) { _, ids in
            selection = SettingsWorkspaceRoute.reconciled(selection, availableBridgeIDs: ids)
        }
    }

    private var applicationSection: some View {
        SwiftUI.Group {
            Section("Application") {
                routeRow(.appGeneral, title: "General", systemImage: "gearshape.fill", color: .gray)
                routeRow(.appearance, title: "Appearance", systemImage: "paintbrush.fill", color: .blue)
                routeRow(.activityCenter, title: "Activity Center", systemImage: "bell.badge.fill", color: .red)
                routeRow(.liveActivities, title: "Live Activities", systemImage: "rectangle.inset.filled.and.person.filled", color: .pink)
                routeRow(.about, title: "About", systemImage: "info.circle.fill", color: Color(.systemGray2))
            }
            Section("Tools") {
                routeRow(.deviceLibrary, title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
                if developerModeEnabled {
                    routeRow(.developer, title: "Developer", systemImage: "hammer.fill", color: .purple)
                }
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
                            tint: BridgeColor.color(for: config.id),
                            size: DesignTokens.Size.settingsIconFrame
                        )
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                            Text(config.displayName)
                            Text(statusLabel(for: session, config: config))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if session?.store.bridgeInfo?.restartRequired == true {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                                .accessibilityLabel("Restart required")
                        }
                        BridgeConnectToggle(config: config)
                    }
                }
                .accessibilityValue(selection?.bridgeID == config.id ? "Selected" : "")
            }
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
