import SwiftUI

/// Who made your network, heaviest first. A leaderboard rather than a
/// chart: every row stays legible however close two makers are, and the
/// bar weights fall off with rank so the order reads without the numbers.
///
/// Vendors only. Device type and power source already have a home on the
/// statistics screen, which is what this card opens.
struct HomeVendorsCard: View {
    let devices: [Device]
    let onTap: () -> Void

    /// Five makers and a remainder fit without the card turning into a
    /// list. The rest are one tap away on the statistics screen.
    private static let visibleCount = 5

    private var breakdown: (named: [HomeStatsCount], others: Int) {
        HomeStatsSnapshot.vendorBreakdown(for: devices, limit: Self.visibleCount)
    }

    private var makerCount: Int {
        HomeStatsSnapshot.distinctVendorCount(for: devices)
    }

    /// The biggest *named* maker sets the scale. The remainder is not a
    /// maker, so it never does.
    private func peak(_ named: [HomeStatsCount]) -> Int {
        max(named.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CardHeader(
                    systemImage: "building.2",
                    title: "Vendors",
                    value: makerCount > 0 ? "\(makerCount) maker\(makerCount == 1 ? "" : "s")" : nil
                ) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                let breakdown = breakdown
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(Array(breakdown.named.enumerated()), id: \.element.id) { index, item in
                        row(item, rank: index, peak: peak(breakdown.named))
                    }
                    if breakdown.others > 0 {
                        othersRow(breakdown.others)
                    }
                }
            }
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The remainder, written as what it is: no bar, because it isn't
    /// competing with the makers above it.
    private func othersRow(_ count: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text("\(count) more, across \(max(makerCount - Self.visibleCount, 1)) makers")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
            Spacer(minLength: 0)
        }
        .padding(.top, DesignTokens.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }

    private func row(_ item: HomeStatsCount, rank: Int, peak: Int) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: DesignTokens.Spacing.sm)

            Capsule()
                .fill(Color(.tertiarySystemFill))
                .frame(width: DesignTokens.Size.vendorBar, height: DesignTokens.Size.vendorBarHeight)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(weight(rank: rank)))
                        .frame(
                            width: DesignTokens.Size.vendorBar * CGFloat(item.count) / CGFloat(peak),
                            height: DesignTokens.Size.vendorBarHeight
                        )
                }

            Text("\(item.count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: DesignTokens.Size.vendorCountColumn, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(item.count) devices")
    }

    /// One hue, lighter as the rank falls, so the order is visible before
    /// any number is read.
    private func weight(rank: Int) -> Double {
        max(DesignTokens.Opacity.chartBarFloor + DesignTokens.Opacity.chartBarRange
            - Double(rank) * DesignTokens.Opacity.chartBarStep,
            DesignTokens.Opacity.chartBarFloor)
    }
}

#Preview {
    HomeVendorsCard(devices: [], onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
