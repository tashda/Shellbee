import SwiftUI

/// Uptime, resident memory and the MQTT counters for one bridge.
///
/// Home already asks every bridge for a health check each time it appears
/// and then shows none of the answer. These are the numbers that say
/// whether the machine under the stairs is happy — and a memory figure
/// climbing all week is the earliest warning this app can give.
///
/// The detailed card for a single saved bridge.
struct HomeBridgeHealthCard: View {
    let entry: HomeBridgeCardEntry
    let onTap: () -> Void

    private var health: BridgeHealth? { entry.health }

    private var statusTitle: String? {
        guard let health else { return nil }
        if health.mqtt?.connected == false { return "MQTT disconnected" }
        if let healthy = health.healthy { return healthy ? "Healthy" : "Unhealthy" }
        return "Healthy"
    }

    private var statusColor: Color {
        guard let health else { return .secondary }
        if health.mqtt?.connected == false || health.healthy == false { return .orange }
        return .secondary
    }

    private var items: [StatStripItem] {
        var items: [StatStripItem] = []
        if let uptime = health?.process?.uptimeFormatted {
            items.append(StatStripItem(value: uptime, caption: "Uptime"))
        }
        if let memory = health?.process?.rssMB {
            items.append(StatStripItem(
                value: memory,
                caption: "Memory",
                valueColor: (health?.process?.memoryPercent ?? 0) > DesignTokens.Threshold.highProcessMemory ? .orange : nil
            ))
        }
        if let published = health?.mqtt?.published {
            items.append(StatStripItem(value: Self.compact(published), caption: "Messages"))
        }
        return items
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CardHeader(
                    instrument: .init(kind: .health,
                                      severity: statusColor == .orange ? .warning : .routine),
                    title: "Bridge health",
                    value: statusTitle,
                    valueColor: statusColor
                ) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                if items.isEmpty {
                    Text("Waiting for a health check")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    StatStrip(items: items)
                }
            }
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// 1 204 → "1.2 K", so the strip never wraps.
    static func compact(_ n: Int) -> String {
        switch n {
        case 0..<1_000:         return "\(n)"
        case 1_000..<1_000_000: return String(format: "%.1f K", Double(n) / 1_000)
        default:                return String(format: "%.1f M", Double(n) / 1_000_000)
        }
    }
}

#Preview {
    HomeBridgeHealthCard(entry: .preview(name: "Home Bridge"), onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
