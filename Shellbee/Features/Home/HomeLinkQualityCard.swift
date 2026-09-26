import SwiftUI

/// How well the mesh is connected, as a distribution rather than an
/// average. 126 average is a healthy network or a bimodal one with a
/// corner of the house barely hanging on, and the average alone can't
/// tell you which. The weakest band is the only coloured thing.
struct HomeLinkQualityCard: View {
    let snapshot: HomeSnapshot
    /// Opens Devices filtered to weak signal — the band worth acting on.
    let onTapWeak: () -> Void

    private var bands: [HomeSnapshot.LinkQualityBand] { snapshot.linkQualityBands }
    private var peak: Int { max(bands.map(\.count).max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            CardHeader(
                instrument: .init(kind: .signal, normalizedValue: Double(snapshot.averageLinkQuality ?? 0) / 255),
                title: "Link quality",
                value: snapshot.averageLinkQuality.map { "\($0) average" }
            )

            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xs) {
                ForEach(bands) { band in
                    bar(for: band)
                }
            }
            .frame(height: DesignTokens.Size.linkQualityChart)
        }
        .cardSurface()
    }

    private func bar(for band: HomeSnapshot.LinkQualityBand) -> some View {
        VStack(spacing: DesignTokens.Spacing.xs) {
            Text("\(band.count)")
                .font(.caption2)
                .foregroundStyle(band.needsAttention && band.count > 0 ? .red : .secondary)
                .monospacedDigit()
                .lineLimit(1)

            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.sm, style: .continuous)
                        .fill(fill(for: band))
                        .frame(height: max(proxy.size.height * CGFloat(band.count) / CGFloat(peak),
                                           DesignTokens.Size.linkQualityBarMinimum))
                }
            }

            Text(band.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { if band.needsAttention && band.count > 0 { onTapWeak() } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(band.count) devices between \(band.label)")
    }

    /// One hue in three weights, so the shape carries the meaning and only
    /// the band you'd act on takes a colour.
    private func fill(for band: HomeSnapshot.LinkQualityBand) -> Color {
        if band.needsAttention { return band.count > 0 ? .red : Color(.tertiarySystemFill) }
        let share = Double(band.count) / Double(peak)
        return Color.primary.opacity(DesignTokens.Opacity.chartBarFloor
            + share * DesignTokens.Opacity.chartBarRange)
    }
}

#Preview {
    HomeLinkQualityCard(snapshot: .preview, onTapWeak: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
