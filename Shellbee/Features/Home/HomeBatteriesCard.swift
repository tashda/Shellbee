import SwiftUI

/// Which batteries are going flat, emptiest first. The Needs attention row
/// says how many are low; this says which ones, how low, and what's next in
/// line — the difference between knowing there's a problem and knowing what
/// to put in the shopping basket.
struct HomeBatteriesCard: View {
    let snapshot: HomeSnapshot
    @State private var isExpanded = false

    private static let visibleCount = 5

    private var headerValue: String? {
        guard snapshot.lowBatteryDevices > 0 else { return nil }
        return "\(snapshot.lowBatteryDevices) low"
    }

    var body: some View {
        ExpandableCardSurface(
            isExpanded: $isExpanded,
            hasMore: snapshot.batteryReadings.count > Self.visibleCount,
            itemName: "batteries"
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ExpandableCardHeader(
                    isExpanded: $isExpanded,
                    hasMore: snapshot.batteryReadings.count > Self.visibleCount,
                    itemName: "batteries"
                ) {
                    CardHeader(
                        instrument: .init(
                            kind: .battery,
                            normalizedValue: snapshot.lowBatteryDevices == 0
                                ? 1
                                : Double(snapshot.batteryReadings.first?.percent ?? 0) / 100
                        ),
                        title: "Batteries",
                        value: headerValue,
                        valueColor: snapshot.lowBatteryDevices > 0 ? .red : .secondary
                    )
                }

                ExpandableCardRows(
                    isExpanded: $isExpanded,
                    items: snapshot.batteryReadings,
                    previewCount: Self.visibleCount,
                    rowHeight: DesignTokens.Size.dashboardCompactRow,
                    spacing: DesignTokens.Spacing.xs
                ) { reading, _ in
                    row(reading)
                }
            }
        }
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
    HomeBatteriesCard(snapshot: .preview)
        .padding()
        .background(Color(.systemGroupedBackground))
}
