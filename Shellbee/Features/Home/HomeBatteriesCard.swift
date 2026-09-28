import SwiftUI

/// Which batteries are going flat, emptiest first. The Needs attention row
/// says how many are low; this says which ones and how low. The five lowest
/// show here, the rest on the Batteries page.
struct HomeBatteriesCard: View {
    let snapshot: HomeSnapshot
    let readings: [HomeDeviceReading]
    /// Opens the battery sheet for one device.
    let onSelect: (HomeDeviceReading) -> Void
    /// Opens the Batteries page.
    let onOpenPage: () -> Void

    private static let visibleCount = 5

    private var batteries: [HomeDeviceReading] {
        readings.filter { $0.battery != nil }
            .sorted { ($0.battery ?? 0, $0.name) < ($1.battery ?? 0, $1.name) }
    }

    private var headerValue: String? {
        guard snapshot.lowBatteryDevices > 0 else { return nil }
        return "\(snapshot.lowBatteryDevices) low"
    }

    var body: some View {
        let all = batteries
        let visible = all.prefix(Self.visibleCount)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                CardHeader(
                    instrument: .init(
                        kind: .battery,
                        normalizedValue: snapshot.lowBatteryDevices == 0
                            ? 1
                            : Double(all.first?.battery ?? 0) / 100
                    ),
                    title: "Batteries",
                    value: headerValue,
                    valueColor: snapshot.lowBatteryDevices > 0 ? .red : .secondary
                )
                CardAccessoryButton(systemImage: "arrow.up.right", accessibilityLabel: "Open Batteries", action: onOpenPage)
            }

            if !visible.isEmpty {
                VStack(spacing: 0) {
                    ForEach(visible) { reading in
                        Button { onSelect(reading) } label: {
                            HomeDeviceReadingRow(
                                reading: reading,
                                value: "\(reading.battery ?? 0) %",
                                valueStyle: AnyShapeStyle(.status(reading.battery?.batteryTone ?? .poor))
                            )
                            .padding(.vertical, DesignTokens.Spacing.xs)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                    Button(action: onOpenPage) {
                        HStack {
                            Text("See all \(all.count) batteries")
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.top, DesignTokens.Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .cardSurface()
    }
}

#Preview {
    HomeBatteriesCard(snapshot: .preview, readings: [], onSelect: { _ in }, onOpenPage: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
