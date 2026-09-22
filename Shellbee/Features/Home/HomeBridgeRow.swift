import SwiftUI

/// One bridge on Home, read like an account row in Settings: a status dot,
/// the name, and one line of detail. Tapping it opens `BridgeInfoSheet`,
/// where the bridge's own figures — version, coordinator, channel, MQTT,
/// memory — already live.
///
/// Nothing else rides along. Routers, end devices and link quality are the
/// Network Map's subject, and how many devices answered is something you
/// can act on, so it belongs in Needs attention.
struct HomeBridgeRow: View {
    let entry: HomeBridgeCardEntry
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.md) {
                Circle()
                    .fill(statusColor)
                    .frame(width: DesignTokens.Size.statusDotHero,
                           height: DesignTokens.Size.statusDotHero)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
                    Text(entry.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: DesignTokens.Spacing.sm)

                if entry.isReconnecting {
                    ProgressView().controlSize(.small)
                }

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, DesignTokens.Spacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.name), \(detail)")
        .accessibilityHint("Shows this bridge's connection and network details")
    }

    /// Colour is state and nothing else: green while it works, red when the
    /// socket is down, orange while it's on its way back.
    private var statusColor: Color {
        if entry.isReconnecting { return .orange }
        if !entry.isWebSocketConnected { return .red }
        if !entry.isBridgeOnline { return .orange }
        return .green
    }

    private var statusTitle: String {
        if entry.isReconnecting { return "Reconnecting (\(entry.reconnectAttempt))" }
        if !entry.isWebSocketConnected { return "Disconnected" }
        if !entry.isBridgeOnline { return "Bridge offline" }
        return "Connected"
    }

    private var detail: String {
        var parts = [statusTitle]
        if let version = entry.version, !version.isEmpty {
            parts.append("Zigbee2MQTT \(version)")
        }
        return parts.joined(separator: " · ")
    }
}

#Preview {
    List {
        Section {
            HomeBridgeRow(entry: .preview(name: "Home Bridge"), action: {})
            HomeBridgeRow(entry: .preview(name: "Lab", connected: false), action: {})
        }
    }
}

extension HomeBridgeCardEntry {
    /// Preview-only entry. Kept next to the row so previews don't reach into
    /// the card that used to own this shape.
    static func preview(name: String, connected: Bool = true) -> HomeBridgeCardEntry {
        HomeBridgeCardEntry(
            id: UUID(),
            name: name,
            isFocused: true,
            connectionState: connected ? .connected : .reconnecting(attempt: 2),
            isWebSocketConnected: connected,
            isBridgeOnline: connected,
            info: nil,
            health: nil
        )
    }
}
