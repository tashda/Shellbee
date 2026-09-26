import SwiftUI

/// One value-over-caption cell in a `StatStrip`.
struct StatStripItem: Identifiable {
    let value: String
    let caption: String
    /// Colour for the value. Leave `nil` for the primary label colour;
    /// set it only when the value needs attention (low battery, offline).
    var valueColor: Color? = nil
    /// A small status dot before the value.
    var dotColor: Color? = nil
    /// An SF Symbol before the value (e.g. signal bars).
    var systemImage: String? = nil
    var symbolVariableValue: Double? = nil

    var id: String { caption }
}

/// A row of 2–4 equal-width stats: value in the label colour above a
/// sentence-case caption. Used by the identity header, Switch metering,
/// Fan air quality and anywhere else a card summarises a few figures.
struct StatStrip: View {
    let items: [StatStripItem]

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.xs) {
            ForEach(items) { item in
                cell(item)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func cell(_ item: StatStripItem) -> some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                if let dotColor = item.dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: DesignTokens.Size.statusDotHero,
                               height: DesignTokens.Size.statusDotHero)
                }
                if let systemImage = item.systemImage {
                    Image(systemName: systemImage, variableValue: item.symbolVariableValue)
                        .font(DesignTokens.Typography.statCaption.weight(.semibold))
                        .foregroundStyle(item.valueColor ?? .primary)
                }
                Text(item.value)
                    .font(DesignTokens.Typography.statValue)
                    .monospacedDigit()
                    .foregroundStyle(item.valueColor ?? .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorMild)
                    .contentTransition(.numericText())
            }
            Text(item.caption)
                .font(DesignTokens.Typography.statCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    StatStrip(items: [
        StatStripItem(value: "Online", caption: "4 min ago", dotColor: .green),
        StatStripItem(value: "Router", caption: "Type"),
        StatStripItem(value: "128", caption: "Signal", systemImage: "cellularbars", symbolVariableValue: 0.8),
        StatStripItem(value: "12 %", caption: "Battery", valueColor: .red),
    ])
    .cardSurface()
    .padding()
    .background(Color(.systemGroupedBackground))
}
