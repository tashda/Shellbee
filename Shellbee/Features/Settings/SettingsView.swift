import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled: Bool = false
    @State private var showingDisconnectConfirmation = false
    @State private var showingRestartAlert = false
    /// Connection editor state for the toolbar `+` button. Used in multi-bridge
    /// mode to add a new saved bridge without leaving Settings.
    @State private var editorViewModel: ConnectionViewModel?
    @State private var renameTarget: ConnectionConfig?
    @State private var renameDraft: String = ""
    @State private var removeConfirmation: ConnectionConfig?

    /// Phase 2 multi-bridge: when the user has more than one saved bridge, the
    /// top-level Settings page swaps to the merged layout — every per-bridge
    /// section moves into a per-bridge sub-page (`BridgeSettingsView`).
    private var isMultiBridge: Bool {
        environment.history.connections.count >= 2
    }

    var body: some View {
        NavigationStack {
            Form {
                if isMultiBridge {
                    multiBridgeLayout
                } else {
                    singleBridgeLayout
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                if isMultiBridge {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { presentNewBridgeEditor() } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Bridge")
                    }
                }
            }
            .sheet(item: editorBinding) { vm in
                NavigationStack {
                    ConnectionEditorView(viewModel: vm, mode: .save)
                }
            }
            .alert("Rename Bridge", isPresented: renameAlertBinding, presenting: renameTarget) { config in
                TextField("Name", text: $renameDraft)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    let trimmed = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    environment.history.rename(config, to: trimmed.isEmpty ? nil : trimmed)
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Choose a friendly name. Leave blank to use the host.")
            }
            .alert("Remove Bridge?", isPresented: removeAlertBinding, presenting: removeConfirmation) { config in
                Button("Remove", role: .destructive) {
                    Task {
                        await environment.disconnect(bridgeID: config.id)
                        environment.history.remove(config)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { config in
                Text("\(config.displayName) will be disconnected and removed from your saved bridges. Its auth token is deleted from the keychain.")
            }
            .alert("Restart Zigbee2MQTT?", isPresented: $showingRestartAlert) {
                Button("Restart", role: .destructive) { environment.restartBridge() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Zigbee2MQTT will restart. The app will reconnect automatically.")
            }
            .alert("Disconnect from Server?", isPresented: $showingDisconnectConfirmation) {
                Button("Disconnect", role: .destructive) {
                    Task { await environment.disconnect() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The app returns to the setup screen. Your server address is remembered.")
            }
        }
    }

    // MARK: - Multi-bridge layout

    @ViewBuilder
    private var multiBridgeLayout: some View {
        bridgesSection

        Section {
            NavigationLink { DocBrowserView() } label: {
                settingsLabel(title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
            }
        } header: {
            Text("Tools")
        }

        applicationSection

        if developerModeEnabled {
            developerSection
        }
    }

    @ViewBuilder
    private var bridgesSection: some View {
        Section {
            ForEach(sortedConnections) { config in
                BridgeSettingsRow(
                    config: config,
                    onEdit: { presentEditor(for: config) },
                    onRename: {
                        renameDraft = config.name ?? ""
                        renameTarget = config
                    },
                    onRemove: { removeConfirmation = config }
                )
            }
        } header: {
            Text("Bridges")
        } footer: {
            Text("Each Zigbee2MQTT instance has its own configuration. Tap a bridge to manage its settings, or toggle Connect to bring it online.")
        }
    }

    /// Default bridge sorts to the top, then alphabetical by name. Mirrors the
    /// expectation that the user's primary bridge is the easiest to reach.
    private var sortedConnections: [ConnectionConfig] {
        let connections = environment.history.connections
        guard let defaultID = environment.history.defaultBridgeID,
              let idx = connections.firstIndex(where: { $0.id == defaultID }),
              idx != 0 else {
            return connections
        }
        var copy = connections
        let entry = copy.remove(at: idx)
        copy.insert(entry, at: 0)
        return copy
    }

    // MARK: - Bridge editor flow

    private func presentNewBridgeEditor() {
        let vm = ConnectionViewModel(environment: environment)
        vm.presentNewServer()
        editorViewModel = vm
    }

    private func presentEditor(for config: ConnectionConfig) {
        let vm = ConnectionViewModel(environment: environment)
        vm.presentEditor(for: config)
        editorViewModel = vm
    }

    private var editorBinding: Binding<ConnectionViewModel?> {
        Binding(
            get: { editorViewModel?.isEditorPresented == true ? editorViewModel : nil },
            set: { if $0 == nil { editorViewModel = nil } }
        )
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private var removeAlertBinding: Binding<Bool> {
        Binding(
            get: { removeConfirmation != nil },
            set: { if !$0 { removeConfirmation = nil } }
        )
    }

    // MARK: - Single-bridge layout (legacy)

    @ViewBuilder
    private var singleBridgeLayout: some View {
        if environment.store.bridgeInfo?.restartRequired == true {
            restartRequiredNotice
        }

        connectionSection
        bridgeConfigSection
        loggingSection
        integrationsSection
        networkSection
        toolsSection
        applicationSection

        if developerModeEnabled {
            developerSection
        }

        if environment.connectionState.isConnected || environment.hasBeenConnected {
            dangerSection
        }
    }

    private var connectionSection: some View {
        Section {
            NavigationLink { ServerDetailView() } label: {
                settingsLabel(title: "Server", systemImage: "wifi", color: serverIconColor)
                    .badge(environment.connectionConfig?.displayName ?? "Not configured")
            }
            NavigationLink { SavedBridgesView() } label: {
                settingsLabel(title: "Saved Bridges", systemImage: "list.bullet", color: .blue)
                    .badge(savedBridgesBadge)
            }
        } header: {
            Text("Connection")
        }
    }

    private var savedBridgesBadge: String {
        let count = environment.history.connections.count
        return count == 0 ? "" : "\(count)"
    }

    private var serverIconColor: Color {
        switch environment.connectionState {
        case .connected: .green
        case .connecting, .reconnecting: .orange
        default: Color(.systemGray3)
        }
    }

    private var bridgeConfigSection: some View {
        Section {
            NavigationLink { MainSettingsView() } label: {
                settingsLabel(title: "General", systemImage: "slider.horizontal.3", color: .purple)
            }
            NavigationLink { MQTTSettingsView() } label: {
                settingsLabel(title: "MQTT", systemImage: "point.3.connected.trianglepath.dotted", color: .blue)
            }
            NavigationLink { SerialSettingsView() } label: {
                settingsLabel(title: "Adapter", systemImage: "cable.connector", color: .brown)
            }
        } header: {
            Text("Bridge Configuration")
        }
    }

    private var loggingSection: some View {
        Section {
            Picker(selection: logLevelBinding) {
                ForEach(BridgeSettings.LogLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            } label: {
                settingsLabel(title: "Logging Level", systemImage: "slider.horizontal.below.square.filled.and.square", color: .gray)
            }
            NavigationLink { LogsView() } label: {
                settingsLabel(title: "Logs", systemImage: "list.bullet.rectangle.portrait", color: .indigo)
            }
            NavigationLink { LogOutputView() } label: {
                settingsLabel(title: "Log Output", systemImage: "doc.text.magnifyingglass", color: Color(.systemGray2))
            }
        } header: {
            Text("Logging")
        }
    }

    private var logLevelBinding: Binding<BridgeSettings.LogLevel> {
        Binding(
            get: {
                BridgeSettings.LogLevel(rawValue: environment.store.bridgeInfo?.logLevel ?? "info") ?? .info
            },
            set: { newValue in
                guard newValue.rawValue != environment.store.bridgeInfo?.logLevel else { return }
                environment.sendBridgeOptions(["advanced": .object(["log_level": .string(newValue.rawValue)])])
            }
        )
    }

    private var toolsSection: some View {
        Section {
            NavigationLink { DocBrowserView() } label: {
                settingsLabel(title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
            }
            NavigationLink { TouchlinkView() } label: {
                settingsLabel(title: "Touchlink", systemImage: "dot.radiowaves.left.and.right", color: .teal)
            }
            NavigationLink { BackupView() } label: {
                settingsLabel(title: "Backup", systemImage: "arrow.down.doc.fill", color: .indigo)
            }
        } header: {
            Text("Tools")
        }
    }

    private var integrationsSection: some View {
        Section {
            NavigationLink { HomeAssistantSettingsView() } label: {
                settingsLabel(title: "Home Assistant", systemImage: "house.fill", color: .orange)
            }
            NavigationLink { AvailabilitySettingsView() } label: {
                settingsLabel(title: "Availability", systemImage: "antenna.radiowaves.left.and.right", color: .green)
            }
            NavigationLink { OTASettingsView() } label: {
                settingsLabel(title: "OTA Updates", systemImage: "arrow.down.circle.fill", color: .indigo)
            }
            NavigationLink { HealthSettingsView() } label: {
                settingsLabel(title: "Health Checks", systemImage: "waveform.path.ecg", color: .pink)
            }
        } header: {
            Text("Integrations & Features")
        }
    }

    private var networkSection: some View {
        Section {
            NavigationLink { NetworkSettingsView() } label: {
                settingsLabel(title: "Network & Hardware", systemImage: "network", color: .red)
            }
            NavigationLink { NetworkAccessSettingsView() } label: {
                settingsLabel(title: "Device Filtering", systemImage: "lock.shield.fill", color: .cyan)
            }
        } header: {
            Text("Network")
        }
    }

    // MARK: - App-global sections (shared between layouts)

    private var applicationSection: some View {
        Section {
            NavigationLink { AppGeneralView() } label: {
                settingsLabel(title: "General", systemImage: "gearshape.fill", color: .gray)
            }
            NavigationLink { AppLiveActivitiesView() } label: {
                settingsLabel(title: "Live Activities", systemImage: "rectangle.inset.filled.and.person.filled", color: .pink)
            }
            NavigationLink { AppNotificationSettingsView() } label: {
                settingsLabel(title: "Notifications", systemImage: "bell.badge.fill", color: .red)
            }
            NavigationLink { AboutView() } label: {
                settingsLabel(title: "About", systemImage: "info.circle.fill", color: Color(.systemGray2))
            }
        } header: {
            Text("Application")
        }
    }

    private var developerSection: some View {
        Section {
            NavigationLink { DeveloperSettingsView() } label: {
                settingsLabel(title: "Developer", systemImage: "hammer.fill", color: .purple)
            }
        } header: {
            Text("Developer")
        }
    }

    private var dangerSection: some View {
        Section {
            Button("Disconnect", role: .destructive) {
                showingDisconnectConfirmation = true
            }
        }
    }

    private func settingsLabel(title: String, systemImage: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: DesignTokens.Size.settingsIconFrame, height: DesignTokens.Size.settingsIconFrame)
                .background(color, in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous))
        }
    }

    private var restartRequiredNotice: some View {
        Section {
            Button { showingRestartAlert = true } label: {
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: DesignTokens.Size.restartIconFrame, height: DesignTokens.Size.restartIconFrame)
                        .background(.red, in: Circle())
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Restart Required")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("New configuration is ready to be applied.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, DesignTokens.Spacing.xs)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Bridge row (multi-bridge Settings root)

/// Rich row for the Bridges section: color dot, name, URL, live status
/// subtitle, default star, restart-required indicator, and a Connect /
/// Disconnect toggle. The whole row is a NavigationLink to that bridge's
/// settings page; the Toggle is its own hit-target inside the link, so
/// tapping the toggle never accidentally drills in.
private struct BridgeSettingsRow: View {
    let config: ConnectionConfig
    let onEdit: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    @Environment(AppEnvironment.self) private var environment

    private var session: BridgeSession? {
        environment.registry.session(for: config.id)
    }

    private var isConnected: Bool { session?.isConnected ?? false }
    private var isConnecting: Bool {
        switch session?.connectionState {
        case .connecting, .reconnecting: true
        default: false
        }
    }
    private var isDefault: Bool { environment.history.defaultBridgeID == config.id }
    private var isAutoConnect: Bool { environment.history.isAutoConnect(config) }
    private var restartRequired: Bool { session?.store.bridgeInfo?.restartRequired == true }

    var body: some View {
        NavigationLink {
            BridgeSettingsView(bridgeID: config.id)
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                statusDot
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignTokens.Spacing.xs) {
                        Text(config.displayName)
                            .font(.body)
                            .foregroundStyle(.primary)
                        if isDefault {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .accessibilityLabel("Default bridge")
                        }
                        if restartRequired {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .accessibilityLabel("Restart required")
                        }
                    }
                    Text(config.displayURL)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(stateLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                connectToggle
            }
        }
        .contextMenu {
            Button {
                environment.history.setDefault(isDefault ? nil : config)
            } label: {
                Label(isDefault ? "Unset Default" : "Set Default", systemImage: isDefault ? "star.slash" : "star")
            }
            Button {
                environment.history.setAutoConnect(config, !isAutoConnect)
            } label: {
                Label(isAutoConnect ? "Disable Auto-Connect" : "Enable Auto-Connect",
                      systemImage: isAutoConnect ? "bolt.slash" : "bolt")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(action: onRename) {
                Label("Rename", systemImage: "character.cursor.ibeam")
            }
            Divider()
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                environment.history.setDefault(isDefault ? nil : config)
            } label: {
                Label(isDefault ? "Unpin" : "Default",
                      systemImage: isDefault ? "star.slash" : "star")
            }
            .tint(.yellow)
        }
    }

    @ViewBuilder
    private var statusDot: some View {
        let color: Color = {
            if isConnected { return .green }
            if isConnecting { return .orange }
            switch session?.connectionState {
            case .failed, .lost: return .red
            default: return Color(.systemGray3)
            }
        }()
        Circle()
            .fill(color)
            .frame(width: DesignTokens.Size.statusDot, height: DesignTokens.Size.statusDot)
    }

    private var connectToggle: some View {
        let isOn = Binding(
            get: { isConnected || isConnecting },
            set: { newValue in
                if newValue {
                    environment.connect(config: config)
                } else {
                    Task { await environment.disconnect(bridgeID: config.id) }
                }
            }
        )
        return Toggle("", isOn: isOn)
            .labelsHidden()
            .accessibilityLabel(isConnected ? "Disconnect \(config.displayName)" : "Connect \(config.displayName)")
    }

    private var stateLabel: String {
        switch session?.connectionState {
        case .connected: return "Connected"
        case .connecting: return "Connecting"
        case .reconnecting(let n): return "Reconnecting (attempt \(n))"
        case .failed(let msg): return msg
        case .lost(let msg): return "Lost: \(msg)"
        case .idle, .none:
            return isAutoConnect ? "Auto-connect on launch" : "Disconnected"
        }
    }
}

#Preview {
    SettingsView().environment(AppEnvironment())
}
