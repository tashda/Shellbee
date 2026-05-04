import SwiftUI

/// Manage every saved bridge in one place. Each row shows the bridge's live
/// connection state, lets the user toggle Connect/Disconnect independently
/// (multiple bridges can run concurrently), and exposes per-bridge metadata
/// like default + auto-connect.
struct SavedBridgesView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: ConnectionViewModel?
    @State private var renameTarget: ConnectionConfig?
    @State private var renameDraft: String = ""
    @State private var showRemoveConfirmation: ConnectionConfig?

    var body: some View {
        Form {
            if environment.history.connections.isEmpty {
                emptyStateSection
            } else {
                bridgesSection
            }
        }
        .navigationTitle("Saved Bridges")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    presentEditor()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Bridge")
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
        .alert("Remove Bridge?", isPresented: removeAlertBinding, presenting: showRemoveConfirmation) { config in
            Button("Remove", role: .destructive) {
                Task {
                    await environment.disconnect(bridgeID: config.id)
                    environment.history.remove(config)
                    environment.notificationPreferences.forgetBridge(config.id)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { config in
            Text("\(config.displayName) will be removed and disconnected. Its auth token is deleted from the keychain.")
        }
    }

    private var emptyStateSection: some View {
        Section {
            VStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No saved bridges yet")
                    .font(.headline)
                Text("Add a bridge to manage one or more Zigbee2MQTT instances. Each bridge maintains its own live connection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    presentEditor()
                } label: {
                    Label("Add Bridge", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, DesignTokens.Spacing.xs)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.lg)
        }
    }

    private var bridgesSection: some View {
        Section {
            ForEach(sortedBridges) { config in
                BridgeRow(
                    config: config,
                    onRename: {
                        renameDraft = config.name ?? ""
                        renameTarget = config
                    },
                    onRemove: { showRemoveConfirmation = config }
                )
            }
        } footer: {
            Text("Each bridge has its own live connection. Toggle Connect to bring a bridge online or take it offline. The default bridge auto-connects on app launch.")
        }
    }

    private var sortedBridges: [ConnectionConfig] {
        let connections = environment.history.connections
        guard let defaultID = environment.history.defaultBridgeID else { return connections }
        var copy = connections
        if let idx = copy.firstIndex(where: { $0.id == defaultID }) {
            let entry = copy.remove(at: idx)
            copy.insert(entry, at: 0)
        }
        return copy
    }

    private func presentEditor() {
        let vm = ConnectionViewModel(environment: environment)
        vm.presentNewServer()
        viewModel = vm
    }

    private var editorBinding: Binding<ConnectionViewModel?> {
        Binding(
            get: { viewModel?.isEditorPresented == true ? viewModel : nil },
            set: { if $0 == nil { viewModel = nil } }
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
            get: { showRemoveConfirmation != nil },
            set: { if !$0 { showRemoveConfirmation = nil } }
        )
    }
}

// MARK: - BridgeRow

private struct BridgeRow: View {
    let config: ConnectionConfig
    let onRename: () -> Void
    let onRemove: () -> Void

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Text(config.displayName)
                        .font(.body)
                    if isDefault {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Default bridge")
                    }
                    if isMuted {
                        Image(systemName: "bell.slash.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Notifications muted")
                    }
                    if isFocused && hasMultipleConnected {
                        Text("Focused")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, DesignTokens.Spacing.xs)
                            .padding(.vertical, 1)
                            .background(Color.blue.opacity(0.15), in: Capsule())
                            .foregroundStyle(.blue)
                    }
                }
                Text(config.displayURL)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let stateLabel {
                    Text(stateLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            connectToggle
        }
        .contextMenu {
            menuItems
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
            }
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button {
                environment.notificationPreferences.setMuted(!isMuted, bridgeID: config.id)
            } label: {
                Label(isMuted ? "Unmute" : "Mute", systemImage: isMuted ? "bell" : "bell.slash")
            }
            .tint(isMuted ? .blue : .gray)
        }
    }

    @ViewBuilder
    private var menuItems: some View {
        Button {
            environment.history.setDefault(isDefault ? nil : config)
        } label: {
            Label(isDefault ? "Unset Default" : "Set Default", systemImage: isDefault ? "star.slash" : "star")
        }
        Button {
            environment.history.setAutoConnect(config, !isAutoConnect)
        } label: {
            Label(isAutoConnect ? "Disable Auto-Connect" : "Enable Auto-Connect", systemImage: isAutoConnect ? "bolt.slash" : "bolt")
        }
        Button {
            environment.notificationPreferences.setMuted(!isMuted, bridgeID: config.id)
        } label: {
            Label(isMuted ? "Unmute Notifications" : "Mute Notifications", systemImage: isMuted ? "bell" : "bell.slash")
        }
        if isConnected && !isFocused {
            Button {
                environment.registry.setPrimary(config.id)
            } label: {
                Label("Focus This Bridge", systemImage: "scope")
            }
        }
        Button(action: onRename) {
            Label("Rename", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive, action: onRemove) {
            Label("Remove", systemImage: "trash")
        }
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

    @ViewBuilder
    private var statusDot: some View {
        let color: Color = {
            if isConnected { return .green }
            if isConnecting { return .orange }
            if hasError { return .red }
            return Color(.systemGray3)
        }()
        Circle()
            .fill(color)
            .frame(width: DesignTokens.Size.statusDot, height: DesignTokens.Size.statusDot)
            .overlay {
                if isConnecting {
                    Circle()
                        .stroke(color.opacity(0.4), lineWidth: 2)
                        .scaleEffect(1.6)
                }
            }
    }

    private var session: BridgeSession? { environment.registry.session(for: config.id) }
    private var isConnected: Bool { session?.isConnected ?? false }
    private var isFocused: Bool { environment.registry.primaryBridgeID == config.id }
    private var isDefault: Bool { environment.history.defaultBridgeID == config.id }
    private var isAutoConnect: Bool { environment.history.isAutoConnect(config) }
    private var isMuted: Bool { environment.notificationPreferences.isMuted(bridgeID: config.id) }
    private var hasMultipleConnected: Bool {
        environment.registry.sessions.values.filter(\.isConnected).count >= 2
    }
    private var hasError: Bool {
        if case .failed = session?.connectionState { return true }
        if case .lost = session?.connectionState { return true }
        return false
    }
    private var isConnecting: Bool {
        switch session?.connectionState {
        case .connecting, .reconnecting: true
        default: false
        }
    }
    private var stateLabel: String? {
        switch session?.connectionState {
        case .connecting: "Connecting"
        case .connected: nil
        case .reconnecting(let n): "Reconnecting (attempt \(n))"
        case .failed(let msg): msg
        case .lost(let msg): "Lost: \(msg)"
        case .idle, .none: isAutoConnect ? "Auto-connect on launch" : "Disconnected"
        }
    }
}

extension ConnectionViewModel: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

#Preview {
    NavigationStack {
        SavedBridgesView()
            .environment(AppEnvironment())
    }
}
