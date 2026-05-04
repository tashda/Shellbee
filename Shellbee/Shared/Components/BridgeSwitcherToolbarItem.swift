import SwiftUI

/// Drop-in toolbar content that shows a focus picker when more than one
/// bridge is currently connected. Each bridge maintains its own live
/// WebSocket; switching focus is instantaneous (no reconnect, no data
/// loss) because we're just rebinding which bridge's data the legacy
/// single-bridge UI surfaces.
///
/// Hides itself when only one bridge (or none) is connected — single-bridge
/// users see no extra chrome.
struct BridgeSwitcherToolbarItem: ToolbarContent {
    @Environment(AppEnvironment.self) private var environment

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if environment.registry.sessions.values.filter(\.isConnected).count >= 2 {
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
            Section("Focus on") {
                ForEach(environment.registry.orderedSessions, id: \.bridgeID) { session in
                    Button {
                        environment.registry.setPrimary(session.bridgeID)
                    } label: {
                        HStack {
                            Text(session.displayName)
                            if isFocused(session) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .disabled(!session.isConnected)
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
                Circle()
                    .fill(focusColor)
                    .frame(width: 8, height: 8)
                Text(activeName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
        }
        .accessibilityLabel("Switch focused bridge")
    }

    private var activeName: String {
        environment.registry.primary?.displayName ?? "No Bridge"
    }

    private var focusColor: Color {
        guard let primary = environment.registry.primary else { return .gray }
        if primary.isConnected { return .green }
        return .orange
    }

    private func isFocused(_ session: BridgeSession) -> Bool {
        environment.registry.primaryBridgeID == session.bridgeID
    }
}
