import SwiftUI

struct ServerDetailView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Form {
            Section {
                if let config = environment.connectionConfig {
                    LabeledContent("Host") { Text(config.host) }
                    LabeledContent("Port") { Text("\(config.port)") }
                    LabeledContent("Security") { Text(config.useTLS ? "WSS (TLS)" : "WS (Plain)") }
                    if let token = config.authToken, !token.isEmpty {
                        LabeledContent("Auth Token") {
                            Text(String(repeating: "•", count: min(token.count, 12)))
                                .monospaced()
                        }
                    }
                    LabeledContent("Status") { statusLabel }
                } else {
                    Text("No server configured").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Server")
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
