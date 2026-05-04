import SwiftUI

/// Per-bridge Settings hub. Phase 2 multi-bridge: when the user has more than
/// one saved bridge, the top-level Settings page lists each bridge and tapping
/// one drills into this view, which mirrors the legacy single-bridge layout
/// but every nested screen routes its reads/writes to the bridge identified
/// by `bridgeID`.
struct BridgeSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let bridgeID: UUID

    @State private var showingRestartAlert = false
    @State private var showingDisconnectConfirmation = false
    @State private var editorViewModel: ConnectionViewModel?
    @State private var removeConfirmation: ConnectionConfig?

    private var scope: BridgeScope { environment.scope(for: bridgeID) }
    private var session: BridgeSession? { environment.registry.session(for: bridgeID) }
    private var config: ConnectionConfig? { session?.config }
    private var displayName: String { session?.displayName ?? "Bridge" }

    var body: some View {
        Form {
            if scope.bridgeInfo?.restartRequired == true {
                restartRequiredNotice
            }

            statusHeader
            bridgeConfigSection
            loggingSection
            integrationsSection
            networkSection
            toolsSection

            if session?.isConnected == true || (session?.controller.hasBeenConnected ?? false) {
                dangerSection
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        // Match SettingsView — Logs is reachable from per-bridge settings via
        // the Tools section and the device/group hero card inside log detail
        // pushes a DeviceRoute / GroupRoute that needs a handler on the
        // enclosing stack.
        .navigationDestination(for: DeviceRoute.self) { route in
            DeviceDetailView(bridgeID: route.bridgeID, device: route.device)
        }
        .navigationDestination(for: GroupRoute.self) { route in
            GroupDetailView(bridgeID: route.bridgeID, group: route.group)
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
                scope.restart()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Zigbee2MQTT on \(displayName) will restart. The app will reconnect automatically.")
        }
        .alert("Disconnect from \(displayName)?", isPresented: $showingDisconnectConfirmation) {
            Button("Disconnect", role: .destructive) {
                Task { await environment.disconnect(bridgeID: bridgeID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Other bridges remain connected. The bridge stays in your saved list.")
        }
    }

    // MARK: - Sections

    private var statusHeader: some View {
        Section {
            if let config {
                NavigationLink { ServerDetailView(bridgeID: bridgeID) } label: {
                    BridgeConnectionCardLabel(
                        bridgeID: bridgeID,
                        displayName: displayName,
                        statusSubtitle: statusSubtitle
                    )
                }
                .connectionCardActions(
                    config: config,
                    onEdit: { presentEditor(for: config) },
                    onRemove: { removeConfirmation = config }
                )
            } else {
                NavigationLink { ServerDetailView(bridgeID: bridgeID) } label: {
                    BridgeConnectionCardLabel(
                        bridgeID: bridgeID,
                        displayName: displayName,
                        statusSubtitle: statusSubtitle
                    )
                }
            }
        } header: {
            Text("Connection")
        }
    }

    private var statusSubtitle: String {
        switch session?.connectionState {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .reconnecting(let n): "Reconnecting (attempt \(n))"
        case .failed(let msg): msg
        case .lost(let msg): "Lost: \(msg)"
        default: config?.displayURL ?? "Disconnected"
        }
    }

    private var bridgeConfigSection: some View {
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

    private var loggingSection: some View {
        Section {
            Picker(selection: logLevelBinding) {
                ForEach(BridgeSettings.LogLevel.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            } label: {
                settingsLabel(title: "Logging Level", systemImage: "slider.horizontal.below.square.filled.and.square", color: .gray)
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
                BridgeSettings.LogLevel(rawValue: scope.bridgeInfo?.logLevel ?? "info") ?? .info
            },
            set: { newValue in
                guard newValue.rawValue != scope.bridgeInfo?.logLevel else { return }
                scope.sendOptions(["advanced": .object(["log_level": .string(newValue.rawValue)])])
            }
        )
    }

    private var integrationsSection: some View {
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

    private var networkSection: some View {
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

    private var toolsSection: some View {
        Section {
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

    private var dangerSection: some View {
        Section {
            Button("Disconnect", role: .destructive) {
                showingDisconnectConfirmation = true
            }
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
                        Text("New configuration is ready to be applied to \(displayName).")
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
}
