import SwiftUI

/// One bridge's row inside the multi-bridge `HomeBridgeCard`. Compact: status
/// dot, name, version/uptime line, and inline alert chips. Tapping the row
/// (when `onSelect` is non-nil) sets focus to this bridge.
struct HomeBridgeCardRow: View {
    let entry: HomeBridgeCardEntry
    let onRestart: () -> Void
    let onSelect: (() -> Void)?

    private var dotColor: Color {
        if entry.isReconnecting { return .orange }
        if !entry.isWebSocketConnected { return .red }
        return entry.isBridgeOnline ? .green : .red
    }

    private var statusText: String? {
        if !entry.isWebSocketConnected { return "Disconnected" }
        if entry.isReconnecting { return "Reconnecting (\(entry.reconnectAttempt))" }
        if let mqtt = entry.health?.mqtt?.connected, !mqtt { return "MQTT down" }
        return nil
    }

    private var hasMemoryAlert: Bool {
        let z2mHigh = (entry.health?.process?.memoryPercent ?? 0) > 30
        let osHigh  = (entry.health?.os?.memoryPercent ?? 0) > 85
        return z2mHigh || osHigh
    }

    var body: some View {
        let row = VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                Text(entry.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if entry.isFocused {
                    Text("Focused")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.teal)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.teal.opacity(0.12)))
                }
                Spacer()
                if let status = statusText {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            metaLine
            if !chips.isEmpty {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    ForEach(chips) { chip in
                        chip.view
                    }
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())

        if let onSelect {
            Button(action: onSelect) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    @ViewBuilder
    private var metaLine: some View {
        let parts = metaParts
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var metaParts: [String] {
        var parts: [String] = []
        if let v = entry.version { parts.append("v\(v)") }
        if let uptime = entry.health?.process?.uptimeFormatted { parts.append(uptime) }
        if let pub = entry.health?.mqtt?.published {
            parts.append("\(formatCount(pub)) pub")
        }
        return parts
    }

    private func formatCount(_ n: Int) -> String {
        switch n {
        case 0..<1_000:           return "\(n)"
        case 1_000..<1_000_000:   return String(format: "%.0fK", Double(n) / 1_000)
        default:                  return String(format: "%.1fM", Double(n) / 1_000_000)
        }
    }

    private struct Chip: Identifiable {
        let id = UUID()
        let view: AnyView
    }

    private var chips: [Chip] {
        var result: [Chip] = []
        if entry.restartRequired {
            result.append(Chip(view: AnyView(
                Button(action: onRestart) {
                    chipLabel(symbol: "arrow.triangle.2.circlepath", text: "Restart", tint: .orange)
                }
                .buttonStyle(.plain)
            )))
        }
        if entry.isPermitJoinActive {
            result.append(Chip(view: AnyView(
                chipLabel(symbol: "person.crop.circle.badge.plus", text: "Permit Join", tint: .orange)
            )))
        }
        if hasMemoryAlert {
            result.append(Chip(view: AnyView(
                chipLabel(symbol: "memorychip", text: "High memory", tint: .orange)
            )))
        }
        return result
    }

    private func chipLabel(symbol: String, text: String, tint: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.caption2.weight(.semibold))
            Text(text).font(.caption2.weight(.medium))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, DesignTokens.Spacing.xs)
        .padding(.vertical, 2)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}
