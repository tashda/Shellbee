import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(DeveloperSettings.modeEnabledKey) private var developerModeEnabled: Bool = false
    @State private var showingDisconnectConfirmation = false
    @State private var showingRestartAlert = false

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
            NavigationLink { SavedBridgesView() } label: {
                settingsLabel(title: "Saved Bridges", systemImage: "list.bullet", color: .blue)
                    .badge("\(environment.history.connections.count)")
            }
        } header: {
            Text("Connection")
        }

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
            ForEach(environment.history.connections) { config in
                NavigationLink { BridgeSettingsView(bridgeID: config.id) } label: {
                    bridgeRowLabel(for: config)
                }
            }
        } header: {
            Text("Bridges")
        } footer: {
            Text("Each connected Zigbee2MQTT instance has its own configuration. Tap a bridge to manage its settings.")
        }
    }

    private func bridgeRowLabel(for config: ConnectionConfig) -> some View {
        let session = environment.registry.session(for: config.id)
        return HStack(spacing: DesignTokens.Spacing.sm) {
            BridgeColorDot(bridgeID: config.id, bridgeName: config.displayName, size: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.displayName)
                    .foregroundStyle(.primary)
                Text(stateSubtitle(for: session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if session?.store.bridgeInfo?.restartRequired == true {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Restart required")
            }
        }
    }

    private func stateSubtitle(for session: BridgeSession?) -> String {
        switch session?.connectionState {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .reconnecting(let n): "Reconnecting (attempt \(n))"
        case .failed(let msg): msg
        case .lost(let msg): "Lost: \(msg)"
        default: "Disconnected"
        }
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

#Preview {
    SettingsView().environment(AppEnvironment())
}
