import SwiftUI

struct ServerDetailView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var showingRestartAlert = false
    @State private var showingDisconnectConfirmation = false

    private var config: ConnectionConfig? { environment.connectionConfig }
    private var bridgeInfo: BridgeInfo? { environment.store.bridgeInfo }

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

            if let version = bridgeInfo?.version {
                Section("Bridge") {
                    CopyableRow(label: "Zigbee2MQTT", value: version)
                }
            }
        }
        .navigationTitle("Server")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if environment.connectionState.isConnected {
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
        .alert("Restart?", isPresented: $showingRestartAlert) {
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

    @ViewBuilder
    private var statusLabel: some View {
        switch environment.connectionState {
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
        ServerDetailView().environment(AppEnvironment())
    }
}
