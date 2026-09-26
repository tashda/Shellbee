import SwiftUI

/// Compact ranking row shared by Home and Device Statistics.
struct RankedBarRow: View {
    let title: String
    let count: Int
    let rank: Int
    let peak: Int

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(title)
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
                        .fill(Color.primary.opacity(weight))
                        .frame(
                            width: DesignTokens.Size.vendorBar * CGFloat(count) / CGFloat(max(peak, 1)),
                            height: DesignTokens.Size.vendorBarHeight
                        )
                }

            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .frame(width: DesignTokens.Size.vendorCountColumn, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) devices")
    }

    private var weight: Double {
        max(
            DesignTokens.Opacity.chartBarFloor + DesignTokens.Opacity.chartBarRange
                - Double(rank) * DesignTokens.Opacity.chartBarStep,
            DesignTokens.Opacity.chartBarFloor
        )
    }
}
