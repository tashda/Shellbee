import SwiftUI

struct RemoteCard: View {
    let device: Device
    let state: [String: JSONValue]
    let mode: CardDisplayMode

    private var lastAction: String? {
        guard let s = state["action"]?.stringValue, !s.isEmpty else { return nil }
        return s
    }

    private var voltage: Double? { state["voltage"]?.numberValue }

    private var voltageUnit: String {
        let flat = (device.definition?.exposes ?? []).flatMap { [$0] + ($0.features ?? []) }
        return flat.first(where: { $0.name == "voltage" || $0.property == "voltage" })?.unit ?? "mV"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
            if mode == .snapshot {
                header
            }
            actionTile
            if let voltage {
                voltageTile(voltage)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.xl)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: DesignTokens.CornerRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(DesignTokens.Shadow.badgeOpacity),
                radius: DesignTokens.Spacing.sm, y: DesignTokens.Spacing.xs)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "command")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.tint)
            Text("Remote")
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var actionTile: some View {
        ReadingTile(
            icon: "hand.tap.fill",
            label: "Last Action",
            value: lastAction.map(prettyAction) ?? "Waiting",
            unit: nil,
            valueColor: lastAction == nil ? .secondary : .primary
        )
    }

    private func voltageTile(_ value: Double) -> some View {
        ReadingTile(
            icon: "bolt.fill",
            label: "Voltage",
            value: "\(Int(value))",
            unit: voltageUnit,
            valueColor: .primary
        )
    }

    private func prettyAction(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct ReadingTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String?
    let valueColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                Text(value)
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                if let unit {
                    Text(unit)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignTokens.Spacing.lg) {
            RemoteCard(device: .preview, state: [
                "action": .string("1_short_release"),
                "voltage": .double(1500)
            ], mode: .interactive)
            RemoteCard(device: .preview, state: [
                "action": .string("brightness_up_click"),
                "voltage": .double(1200)
            ], mode: .snapshot)
            RemoteCard(device: .preview, state: [:], mode: .interactive)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
