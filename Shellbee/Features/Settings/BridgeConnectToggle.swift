import SwiftUI

/// Inline connect/disconnect switch for a saved bridge row. Reads as "on"
/// while connected or mid-connect so the switch doesn't flicker back off
/// during the handshake.
struct BridgeConnectToggle: View {
    let config: ConnectionConfig

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

    var body: some View {
        Toggle("", isOn: Binding(
            get: { isConnected || isConnecting },
            set: { newValue in
                if newValue {
                    environment.connect(config: config)
                } else {
                    Task { await environment.disconnect(bridgeID: config.id) }
                }
            }
        ))
        .labelsHidden()
        .accessibilityLabel(isConnected ? "Disconnect \(config.displayName)" : "Connect \(config.displayName)")
    }
}
