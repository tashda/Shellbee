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

    @ViewBuilder
    var body: some View {
        if mode == .snapshot {
            snapshotContent
        } else {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xl) {
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
    }

    // MARK: - Snapshot

    /// Compact log-row rendering. Command glyph + "Remote" + last action
    /// (and voltage when present).
    private var snapshotContent: some View {
        CompactSnapshotCard {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                Image(systemName: "command")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Remote")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let secondary = snapshotSecondaryText {
                        Text(secondary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("Waiting")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: DesignTokens.Spacing.sm)
            }
        }
    }

    private var snapshotSecondaryText: String? {
        var parts: [String] = []
        if let action = lastAction { parts.append(prettyAction(action)) }
        if let v = voltage { parts.append("\(Int(v)) \(voltageUnit)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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
                    .font(DesignTokens.Typography.eyebrowIcon)
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(DesignTokens.Typography.eyebrowLabel)
                    .tracking(DesignTokens.Typography.eyebrowTracking)
                    .textCase(.uppercase)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.xxs) {
                Text(value)
                    .font(DesignTokens.Typography.featureTileValue)
                    .monospacedDigit()
                    .foregroundStyle(valueColor)
                    .lineLimit(2)
                    .minimumScaleFactor(DesignTokens.Typography.scaleFactorTight)
                if let unit {
                    Text(unit)
                        .font(DesignTokens.Typography.featureTileUnit)
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
