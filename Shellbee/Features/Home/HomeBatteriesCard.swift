import SwiftUI

/// Which batteries are going flat, emptiest first. The Needs attention row
/// says how many are low; this says which ones, how low, and what's next in
/// line — the difference between knowing there's a problem and knowing what
/// to put in the shopping basket.
struct HomeBatteriesCard: View {
    let snapshot: HomeSnapshot
    let onTap: () -> Void

    /// Four fits without turning the card into a list. The rest are one tap
    /// away in Devices.
    private static let visibleCount = 4

    private var readings: [HomeSnapshot.BatteryReading] {
        Array(snapshot.batteryReadings.prefix(Self.visibleCount))
    }

    private var headerValue: String? {
        guard snapshot.lowBatteryDevices > 0 else { return nil }
        return "\(snapshot.lowBatteryDevices) low"
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                CardHeader(
                    systemImage: "battery.50",
                    title: "Batteries",
                    value: headerValue,
                    valueColor: snapshot.lowBatteryDevices > 0 ? .red : .secondary
                ) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(readings) { reading in
                        row(reading)
                    }
                }

                if snapshot.batteryReadings.count > readings.count {
                    Text("\(snapshot.batteryReadings.count) devices on batteries")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .cardSurface()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func row(_ reading: HomeSnapshot.BatteryReading) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Text(reading.name)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: DesignTokens.Spacing.sm)

            Image(systemName: "battery.100", variableValue: Double(reading.percent) / 100)
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
