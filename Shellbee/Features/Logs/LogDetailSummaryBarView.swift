import SwiftUI

struct LogDetailSummaryBarView: View {
    let entry: LogEntry
    let linkQuality: Int?

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            levelIconBox

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(entry.level.label)
                        .font(.headline)
                        .foregroundStyle(entry.level.color)
                    Spacer()
                    Text(entry.timestamp, format: .dateTime.hour().minute().second())
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary)
                }

                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: entry.category.systemImage)
                        .font(.caption)
                    Text(entry.category.label)
                        .font(.caption.weight(.medium))

                    if let ns = entry.namespace {
                        Text("·").font(.caption).foregroundStyle(.quaternary)
                        Text(ns).font(.caption.weight(.medium)).lineLimit(1)
                    }

                    Spacer()

                    if let lqi = linkQuality { lqiView(lqi) }
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(
            color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
            radius: DesignTokens.Spacing.sm,
            y: DesignTokens.Spacing.xs
        )
    }

    private var levelIconBox: some View {
        Image(systemName: entry.level.systemImage)
            .font(.system(size: DesignTokens.Size.cardSymbol, weight: .semibold))
            .foregroundStyle(entry.level.color)
            .frame(width: DesignTokens.Size.lightHeroPreview, height: DesignTokens.Size.lightHeroPreview)
            .background(
                entry.level.color.opacity(DesignTokens.Opacity.chipFill),
                in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
            )
    }

    @ViewBuilder
    private func lqiView(_ lqi: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: lqi > DesignTokens.Threshold.weakSignal ? "wifi" : "wifi.exclamationmark",
                  variableValue: Double(lqi) / 255.0)
                .font(.caption)
            Text(verbatim: "\(lqi)")
                .font(.caption.monospacedDigit().weight(.medium))
        }
        .foregroundStyle(lqi > 100 ? Color.green : (lqi > DesignTokens.Threshold.weakSignal ? Color.orange : Color.red))
    }
}

#Preview {
    VStack(spacing: DesignTokens.Spacing.md) {
        LogDetailSummaryBarView(entry: LogEntry.previewEntries[0], linkQuality: nil)
        LogDetailSummaryBarView(entry: LogEntry.previewEntries[3], linkQuality: 116)
        LogDetailSummaryBarView(entry: LogEntry.previewEntries[1], linkQuality: 28)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
