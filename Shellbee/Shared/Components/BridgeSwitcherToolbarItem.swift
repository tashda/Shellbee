import SwiftUI

/// Drop-in toolbar content that renders a bridge picker in the navigation bar's
/// principal slot when the user has multiple saved bridges. Single-bridge users
/// see nothing — the screen's regular `navigationTitle` shows through.
///
/// Selecting a different saved bridge calls `environment.connect(config:)`,
/// which tears down the prior session and resets the store before connecting.
/// Reconnects in flight surface as an inline progress indicator next to the
/// bridge name.
struct BridgeSwitcherToolbarItem: ToolbarContent {
    @Environment(AppEnvironment.self) private var environment

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if environment.history.connections.count >= 2 {
                BridgeSwitcherMenu()
            } else {
                EmptyView()
            }
        }
    }
}

private struct BridgeSwitcherMenu: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Menu {
            ForEach(environment.history.connections) { config in
                Button {
                    select(config)
                } label: {
                    HStack {
                        Text(config.displayName)
                        if isActive(config) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            NavigationLink {
                SavedBridgesView()
            } label: {
                Label("Manage Saved Bridges", systemImage: "list.bullet")
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.xxs) {
                if isReconnecting {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(activeName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
        .accessibilityLabel("Switch bridge")
    }

    private var activeName: String {
        environment.connectionConfig?.displayName ?? "Select Bridge"
    }

    private var isReconnecting: Bool {
        switch environment.connectionState {
        case .connecting, .reconnecting: true
        default: false
        }
    }

    private func isActive(_ config: ConnectionConfig) -> Bool {
        environment.connectionConfig?.id == config.id
    }

    private func select(_ config: ConnectionConfig) {
        guard !isActive(config) else { return }
        environment.connect(config: config)
    }
}
