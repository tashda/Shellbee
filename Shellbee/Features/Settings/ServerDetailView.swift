import SwiftUI

struct ServerDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let bridgeID: UUID

    @State private var showingRestartAlert = false
    @State private var showingDisconnectConfirmation = false
    @State private var editorViewModel: ConnectionViewModel?

    private var scope: BridgeScope { environment.scope(for: bridgeID) }
    private var session: BridgeSession? { environment.registry.session(for: bridgeID) }
    /// The saved configuration for this bridge id. Reads `history.connections`
    /// rather than the live session so the page still renders identifying
    /// info while the bridge is disconnected.
    private var config: ConnectionConfig? {
        session?.config ?? environment.history.connections.first(where: { $0.id == bridgeID })
    }
    private var bridgeInfo: BridgeInfo? { scope.bridgeInfo }
    private var connectionState: ConnectionSessionController.State { scope.connectionState }

    var body: some View {
        Form {
            if let config {
                Section {
                    if let name = config.name, !name.isEmpty {
                        CopyableRow(label: "Name", value: name)
                    }
                    CopyableRow(label: "Host", value: config.host)
                    CopyableRow(label: "Port", value: String(config.port))
                    CopyableRow(label: "URL", value: config.displayURL)
                    CopyableRow(label: "Protocol", value: config.useTLS ? "WSS (TLS)" : "WS (Plain)")
                    if config.useTLS && config.allowInvalidCertificates {
                        LabeledContent("Certificate") {
                            Text("Self-signed allowed").foregroundStyle(.orange)
                        }
                    }
                    LabeledContent("Authentication") {
                        if let token = config.authToken, !token.isEmpty {
                            Text(String(repeating: "•", count: min(token.count, 12)))
                                .monospaced()
                        } else {
                            Text("None").foregroundStyle(.secondary)
                        }
                    }
                    LabeledContent("Status") { statusLabel }
                }
            } else {
                Section {
                    Text("No server configured").foregroundStyle(.secondary)
                }
            }

            if bridgeInfo != nil {
                Section("Bridge") {
                    if let version = bridgeInfo?.version {
                        CopyableRow(label: "Zigbee2MQTT", value: version)
                    }
                    if let commit = bridgeInfo?.commit {
                        CopyableRow(label: "Commit", value: String(commit.prefix(12)))
                    }
                    if let coordinator = bridgeInfo?.coordinator.type {
                        CopyableRow(label: "Coordinator", value: coordinator)
                    }
                    if let ieee = bridgeInfo?.coordinator.ieeeAddress {
                        CopyableRow(label: "IEEE Address", value: ieee)
                    }
                    if let logLevel = bridgeInfo?.logLevel {
                        LabeledContent("Log Level", value: logLevel.capitalized)
                    }
                }
            }

            if let network = bridgeInfo?.network {
                Section("Zigbee Network") {
                    CopyableRow(label: "Channel", value: "\(network.channel)")
                    CopyableRow(label: "PAN ID", value: String(format: "0x%04X", network.panID))
                    if case .string(let ext) = network.extendedPanID {
                        CopyableRow(label: "Extended PAN ID", value: ext)
                    }
                }
            }

            if scope.isConnected {
                Section {
                    NavigationLink {
                        DeviceStatisticsView(bridgeID: bridgeID)
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Image(systemName: "chart.bar.fill")
                                .foregroundStyle(.secondary)
                            Text("Device Statistics")
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Server")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        presentEditor()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    if connectionState.isConnected {
                        Divider()
                        Button(role: .destructive) {
                            showingRestartAlert = true
                        } label: {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                    }
                    Button(role: .destructive) {
                        showingDisconnectConfirmation = true
                    } label: {
                        Label("Disconnect", systemImage: "wifi.slash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .sheet(item: editorBinding) { vm in
            NavigationStack {
                ConnectionEditorView(viewModel: vm, mode: .save)
            }
        }
        .alert("Restart Zigbee2MQTT?", isPresented: $showingRestartAlert) {
            Button("Restart", role: .destructive) {
                scope.restart()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Zigbee2MQTT will restart. The app will reconnect automatically.")
        }
        .alert("Disconnect from Server?", isPresented: $showingDisconnectConfirmation) {
            Button("Disconnect", role: .destructive) {
                Task { await environment.disconnect(bridgeID: bridgeID) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Other bridges remain connected. The bridge stays in your saved list.")
        }
    }

    private func presentEditor() {
        guard let config else { return }
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

    @ViewBuilder
    private var statusLabel: some View {
        switch connectionState {
        case .idle:
            Text("Not connected").foregroundStyle(.secondary)
        case .connecting:
            HStack(spacing: DesignTokens.Spacing.xs) {
                ProgressView().controlSize(.small)
                Text("Connecting")
            }
        case .connected:
            Text("Connected").foregroundStyle(.green)
        case .reconnecting(let n):
            HStack(spacing: DesignTokens.Spacing.xs) {
                ProgressView().controlSize(.small)
                Text("Reconnecting (\(n))")
            }
        case .failed(let msg), .lost(let msg):
            Text(msg).foregroundStyle(.red).lineLimit(2)
        }
    }
}

#Preview {
    NavigationStack {
        ServerDetailView(bridgeID: UUID()).environment(AppEnvironment())
    }
}
