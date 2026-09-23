import SwiftUI

/// Which batteries are going flat, emptiest first. The Needs attention row
/// says how many are low; this says which ones, how low, and what's next in
/// line — the difference between knowing there's a problem and knowing what
/// to put in the shopping basket.
struct HomeBatteriesCard: View {
    let snapshot: HomeSnapshot
    let onTap: () -> Void
    @State private var isExpanded = false

    private static let minimumVisibleCount = 5

    private var readings: [HomeSnapshot.BatteryReading] {
        if isExpanded { return snapshot.batteryReadings }
        return Array(snapshot.batteryReadings.prefix(visibleCount))
    }

    private var visibleCount: Int { max(Self.minimumVisibleCount, snapshot.lowBatteryDevices) }
    private var remainingCount: Int { max(snapshot.batteryReadings.count - visibleCount, 0) }

    private var headerValue: String? {
        guard snapshot.lowBatteryDevices > 0 else { return nil }
        return "\(snapshot.lowBatteryDevices) low"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            CardHeader(
                instrument: .init(
                    kind: .battery,
                    normalizedValue: Double(snapshot.batteryReadings.first?.percent ?? 50) / 100
                ),
                title: "Batteries",
                value: headerValue,
                valueColor: snapshot.lowBatteryDevices > 0 ? .red : .secondary
            )

            VStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(readings) { reading in
                    row(reading)
                }
            }
            .overlay(alignment: .bottom) {
                if !isExpanded && remainingCount > 0 { ExpandableCardFade() }
            }

            if remainingCount > 0 {
                ExpandableCardFooter(
                    isExpanded: $isExpanded,
                    remainingCount: remainingCount,
                    itemName: "batteries"
                )
            }

            if snapshot.lowBatteryDevices > 0 {
                Button("View low batteries in Devices", action: onTap)
                    .font(.footnote)
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
            }
        }
        .cardSurface()
    }

    /// The discrete battery symbols read correctly at every level; the
    /// variable-value one draws a full battery at 0 %.
    private static func symbol(for percent: Int) -> String {
        switch percent {
        case ..<13:  "battery.0percent"
        case ..<38:  "battery.25percent"
        case ..<63:  "battery.50percent"
        case ..<88:  "battery.75percent"
        default:     "battery.100percent"
        }
    }

    private func row(_ reading: HomeSnapshot.BatteryReading) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(reading.name)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: DesignTokens.Spacing.sm)

            Image(systemName: Self.symbol(for: reading.percent))
                .font(.subheadline)
                .foregroundStyle(reading.isLow ? .red : .secondary)

            Text("\(reading.percent) %")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(reading.isLow ? .red : .primary)
                .frame(width: DesignTokens.Size.batteryPercentColumn, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeBatteriesCard(snapshot: .preview, onTap: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
