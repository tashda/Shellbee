import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled: Bool = false
    @State private var showingDisconnectConfirmation = false
    @State private var showingRestartAlert = false
    /// Connection editor state for the toolbar `+` button. Used in multi-bridge
    /// mode to add a new saved bridge without leaving Settings.
    @State private var editorViewModel: ConnectionViewModel?
    @State private var removeConfirmation: ConnectionConfig?

    /// Phase 2 multi-bridge: when the user has more than one saved bridge, the
    /// top-level Settings page swaps to the merged layout — every per-bridge
    /// section moves into a per-bridge sub-page (`BridgeSettingsView`).
    private var isMultiBridge: Bool {
        environment.history.connections.count >= 2
    }

    /// The bridge whose data the single-bridge layout operates on. There's
    /// exactly one saved bridge in this layout — resolve to its session if
    /// connected, else fall back to the saved config's id so configuration
    /// reads (logLevel, restartRequired) still work while disconnected.
    private var singleBridgeID: UUID? {
        environment.registry.primaryBridgeID
            ?? environment.registry.orderedSessions.first?.bridgeID
            ?? environment.history.connections.first?.id
    }

    private var singleBridgeScope: BridgeScope? {
        singleBridgeID.flatMap { environment.scope(for: $0) }
    }

    private var canDisconnectSingleBridge: Bool {
        guard let scope = singleBridgeScope else { return false }
        return scope.connectionState.isConnected
            || (scope.session?.controller.hasBeenConnected ?? false)
    }

    private var singleBridgeConfig: ConnectionConfig? {
        if let id = singleBridgeID {
            return environment.history.connections.first(where: { $0.id == id })
                ?? environment.registry.session(for: id)?.config
        }
        return environment.history.connections.first
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
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { presentNewBridgeEditor() } label: {
                            Label("Add Bridge", systemImage: "plus")
                        }
                        if !isMultiBridge, canDisconnectSingleBridge {
                            Button(role: .destructive) {
                                showingDisconnectConfirmation = true
                            } label: {
                                Label("Disconnect", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More")
                }
            }
            .sheet(item: editorBinding) { vm in
                NavigationStack {
                    ConnectionEditorView(viewModel: vm, mode: .save)
                }
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
                Button("Restart", role: .destructive) {
                    if let id = singleBridgeID { environment.restartBridge(id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Zigbee2MQTT will restart. The app will reconnect automatically.")
            }
            .alert("Disconnect from Server?", isPresented: $showingDisconnectConfirmation) {
                Button("Disconnect", role: .destructive) {
                    Task {
                        if let id = singleBridgeID {
                            await environment.disconnect(bridgeID: id)
                        }
                    }
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
            NavigationLink { LogsView() } label: {
                settingsLabel(title: "Logs", systemImage: "list.bullet.rectangle.portrait", color: .indigo)
            }
            NavigationLink { DocBrowserView() } label: {
                settingsLabel(title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
            }
        } header: {
            Text("Tools")
        } footer: {
            Text("Logs from every connected bridge are merged in one place.")
        }

        applicationSection

        if developerModeEnabled {
            developerSection
        }
    }

    @ViewBuilder
    private var bridgesSection: some View {
        Section {
            ForEach(environment.history.connections) { config in
                BridgeSettingsRow(
                    config: config,
                    onEdit: { presentEditor(for: config) },
                    onRemove: { removeConfirmation = config }
                )
            }
        } header: {
            Text("Bridges")
        }
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

    private var removeAlertBinding: Binding<Bool> {
        Binding(
            get: { removeConfirmation != nil },
            set: { if !$0 { removeConfirmation = nil } }
        )
    }

    // MARK: - Single-bridge layout (legacy)

    @ViewBuilder
    private var singleBridgeLayout: some View {
        if singleBridgeScope?.bridgeInfo?.restartRequired == true {
            restartRequiredNotice
        }

        connectionSection
        if let id = singleBridgeID {
            bridgeConfigSection(bridgeID: id)
            loggingSection(bridgeID: id)
            integrationsSection(bridgeID: id)
            networkSection(bridgeID: id)
            toolsSection(bridgeID: id)
        }
        applicationSection

        if developerModeEnabled {
            developerSection
        }
    }

    @ViewBuilder
    private var connectionSection: some View {
        Section {
            if let id = singleBridgeID, let config = singleBridgeConfig {
                NavigationLink { ServerDetailView(bridgeID: id) } label: {
                    singleBridgeConnectionCard(bridgeID: id)
                }
                .connectionCardActions(
                    config: config,
                    onEdit: { presentEditor(for: config) },
                    onRemove: { removeConfirmation = config }
                )
            }
        } header: {
            Text("Connection")
        }
    }

    private func singleBridgeConnectionCard(bridgeID: UUID) -> some View {
        let session = environment.registry.session(for: bridgeID)
        let displayName = session?.displayName ?? "Bridge"
        let statusSubtitle: String = {
            switch session?.connectionState {
            case .connected: "Connected"
            case .connecting: "Connecting"
            case .reconnecting(let n): "Reconnecting (attempt \(n))"
            case .failed(let msg): msg
            case .lost(let msg): "Lost: \(msg)"
            default: session?.config.displayURL ?? "Disconnected"
            }
        }()

        return BridgeConnectionCardLabel(
            bridgeID: bridgeID,
            displayName: displayName,
            statusSubtitle: statusSubtitle
        )
    }

    private func bridgeConfigSection(bridgeID: UUID) -> some View {
        Section {
            NavigationLink { MainSettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "General", systemImage: "slider.horizontal.3", color: .purple)
            }
            NavigationLink { MQTTSettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "MQTT", systemImage: "point.3.connected.trianglepath.dotted", color: .blue)
            }
            NavigationLink { SerialSettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Adapter", systemImage: "cable.connector", color: .brown)
            }
        } header: {
            Text("Bridge Configuration")
        }
    }

    private func loggingSection(bridgeID: UUID) -> some View {
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
            NavigationLink { LogOutputView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Log Output", systemImage: "doc.text.magnifyingglass", color: Color(.systemGray2))
            }
        } header: {
            Text("Logging")
        }
    }

    private var logLevelBinding: Binding<BridgeSettings.LogLevel> {
        Binding(
            get: {
                BridgeSettings.LogLevel(rawValue: singleBridgeScope?.bridgeInfo?.logLevel ?? "info") ?? .info
            },
            set: { newValue in
                guard let scope = singleBridgeScope,
                      newValue.rawValue != scope.bridgeInfo?.logLevel else { return }
                scope.sendOptions(["advanced": .object(["log_level": .string(newValue.rawValue)])])
            }
        )
    }

    private func toolsSection(bridgeID: UUID) -> some View {
        Section {
            NavigationLink { DocBrowserView() } label: {
                settingsLabel(title: "Device Library", systemImage: "books.vertical.fill", color: .orange)
            }
            NavigationLink { TouchlinkView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Touchlink", systemImage: "dot.radiowaves.left.and.right", color: .teal)
            }
            NavigationLink { BackupView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Backup", systemImage: "arrow.down.doc.fill", color: .indigo)
            }
        } header: {
            Text("Tools")
        }
    }

    private func integrationsSection(bridgeID: UUID) -> some View {
        Section {
            NavigationLink { HomeAssistantSettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Home Assistant", systemImage: "house.fill", color: .orange)
            }
            NavigationLink { AvailabilitySettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Availability", systemImage: "antenna.radiowaves.left.and.right", color: .green)
            }
            NavigationLink { OTASettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "OTA Updates", systemImage: "arrow.down.circle.fill", color: .indigo)
            }
            NavigationLink { HealthSettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Health Checks", systemImage: "waveform.path.ecg", color: .pink)
            }
        } header: {
            Text("Integrations & Features")
        }
    }

    private func networkSection(bridgeID: UUID) -> some View {
        Section {
            NavigationLink { NetworkSettingsView(bridgeID: bridgeID) } label: {
                settingsLabel(title: "Network & Hardware", systemImage: "network", color: .red)
            }
            NavigationLink { NetworkAccessSettingsView(bridgeID: bridgeID) } label: {
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
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
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
