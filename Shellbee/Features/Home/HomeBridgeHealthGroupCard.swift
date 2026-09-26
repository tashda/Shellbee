import SwiftUI

/// One quiet summary for homes with several bridges. Each row opens its own
/// bridge details while keeping the Home dashboard to a single health card.
struct HomeBridgeHealthGroupCard: View {
    let entries: [HomeBridgeCardEntry]
    let onTap: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            CardHeader(
                instrument: .init(kind: .health),
                title: "Bridge health",
                value: "\(entries.count) bridges"
            )

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Button { onTap(entry.id) } label: {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(displayName(for: entry, index: index))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(metrics(for: entry))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: DesignTokens.Spacing.sm)
                        Text(status(for: entry))
                            .font(.footnote)
                            .foregroundStyle(needsAttention(entry) ? .orange : .secondary)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
        }
        .cardSurface()
    }

    private func needsAttention(_ entry: HomeBridgeCardEntry) -> Bool {
        !entry.isWebSocketConnected || entry.health?.healthy == false
            || entry.health?.mqtt?.connected == false
    }

    private func status(for entry: HomeBridgeCardEntry) -> String {
        if !entry.isWebSocketConnected { return "Offline" }
        if entry.health?.mqtt?.connected == false { return "MQTT disconnected" }
        if entry.health?.healthy == false { return "Unhealthy" }
        if entry.health == nil { return "Waiting" }
        return "Healthy"
    }

    private func metrics(for entry: HomeBridgeCardEntry) -> String {
        let health = entry.health
        let values = [
            health?.process?.uptimeFormatted.map { "\($0) uptime" },
            health?.process?.rssMB.map { "\($0) memory" },
            health?.mqtt?.published.map { "\(HomeBridgeHealthCard.compact($0)) messages" },
        ]
        .compactMap { $0 }
        return values.isEmpty ? "Waiting for a health check" : values.joined(separator: " · ")
    }

    private func displayName(for entry: HomeBridgeCardEntry, index: Int) -> String {
        guard entries.filter({ $0.name == entry.name }).count > 1 else { return entry.name }
        return "\(entry.name) · Bridge \(index + 1)"
    }
}
